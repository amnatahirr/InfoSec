import path from "path"
import fs from "fs/promises"
import { encryptFile, generateFileHash } from "./encryption.js"
import {
  getFilesFromPaths,
  isFileModified,
  updateFileMetadata,
  copyFileToBackup,
  cleanOldBackups,
} from "./fileOperations.js"
import { runQuery, getQuery } from "../database/db.js"

export async function performBackup(configId, password) {
  try {
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ?", [configId])

    if (!config) throw new Error("Backup configuration not found")

    const sourcePaths = JSON.parse(config.source_paths)
    const backupFolder = config.backup_folder
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-")
    const backupSessionPath = path.join(backupFolder, `backup_${timestamp}`)

    console.log(`[Backup] Starting backup for config ${configId}`)
    console.log(`[Backup] Backup folder: ${backupFolder}`)
    console.log(`[Backup] Backup session path: ${backupSessionPath}`)
    console.log(`[Backup] Source paths: ${sourcePaths.join(", ")}`)

    try {
      await fs.mkdir(backupFolder, { recursive: true })
      console.log(`[Backup] Backup folder created/verified: ${backupFolder}`)
    } catch (error) {
      throw new Error(`Cannot create backup folder at ${backupFolder}: ${error.message}`)
    }

    // Get all files
    const allFiles = await getFilesFromPaths(sourcePaths)
    console.log(`[Backup] Found ${allFiles.length} total files`)
    console.log(allFiles.slice(0, 5));


    if (allFiles.length === 0) {
      console.log(`[Backup] No files found in source paths`)
      return {
        success: true,
        filesBackedUp: 0,
        totalSize: 0,
        backupPath: backupSessionPath,
        failedFiles: [],
        status: "success",
        message: "No files to backup",
      }
    }

    // Filter only modified files (incremental backup)
    const filesToBackup = []
    for (const file of allFiles) {
      const isModified = await isFileModified(configId, file)
      if (isModified) {
        filesToBackup.push(file)
      }
    }

    console.log(`[Backup] ${filesToBackup.length} files need backup`)

    let successCount = 0
    let totalSize = 0
    const failedFiles = []

    // Encrypt and backup files
    for (const file of filesToBackup) {
      try {
        const cleanRelative = path.relative(process.cwd(), file)
        .replace(/[:]/g, '')       // remove invalid drive letters like C:
        .replace(/\\/g, '/');     
        const backupFilePath = path.join(backupSessionPath, cleanRelative);
        await fs.mkdir(path.dirname(backupFilePath), { recursive: true })


        console.log(`[Backup] Processing file: ${file}`)
        console.log(`[Backup] Backup path: ${backupFilePath}`)

        // Copy file to backup location
        await copyFileToBackup(file, backupFilePath)
        console.log(`[Backup] File copied to: ${backupFilePath}`)

        // Encrypt the backup file
        const encryptedPath = backupFilePath + ".enc"
        const encryptResult = await encryptFile(backupFilePath, encryptedPath, password)
        console.log(`[Backup] Encrypted size: ${encryptResult.encryptedSize} bytes`);

        console.log(`[Backup] File encrypted to: ${encryptedPath}`)

        // Delete unencrypted backup
        await fs.unlink(backupFilePath)
        console.log(`[Backup] Unencrypted file deleted`)

        // Update metadata
        const fileHash = await generateFileHash(file)
        await updateFileMetadata(configId, file, fileHash)

        successCount++
        totalSize += encryptResult.originalSize

        console.log(`[Backup] Successfully encrypted: ${file}`)
      } catch (error) {
        console.error(`[Backup] Error backing up file ${file}:`, error.message)
        failedFiles.push({ file, error: error.message })
      }
    }

    // Record backup history
    const backupStatus = failedFiles.length === 0 ? "success" : "partial"
    await runQuery(
      "INSERT INTO backup_history (config_id, backup_path, file_count, total_size, status) VALUES (?, ?, ?, ?, ?)",
      [configId, backupSessionPath, successCount, totalSize, backupStatus],
    )

    // Clean old backups
    const deletedCount = await cleanOldBackups(configId, config.retention_days)
    console.log(`[Backup] Cleaned ${deletedCount} old backups`)

    return {
      success: failedFiles.length === 0,
      filesBackedUp: successCount,
      totalSize,
      backupPath: backupSessionPath,
      failedFiles,
      status: backupStatus,
      message: `Backup completed. ${successCount} files encrypted.`,
    }
  } catch (error) {
    console.error(`[Backup] Backup failed:`, error.message)
    throw new Error(`Backup failed: ${error.message}`)
  }
}

export async function restoreBackup(backupId, password, restorePath) {
  try {
    const backup = await getQuery("SELECT * FROM backup_history WHERE id = ?", [backupId])

    if (!backup) throw new Error("Backup not found")

    const fs = await import("fs/promises")
    const { decryptFile } = await import("./encryption.js")

    console.log(`[Restore] Starting restore from backup ${backupId}`)

    const encryptedFiles = await fs.readdir(backup.backup_path, { recursive: true })
    let restoredCount = 0
    const failedFiles = []

    for (const file of encryptedFiles) {
      if (file.endsWith(".enc")) {
        try {
          const encryptedPath = path.join(backup.backup_path, file)
          const decryptedPath = path.join(restorePath, file.replace(".enc", ""))

          // Create directory if needed
          const dir = path.dirname(decryptedPath)
          await fs.mkdir(dir, { recursive: true })

          await decryptFile(encryptedPath, decryptedPath, password)
          restoredCount++

          console.log(`[Restore] Restored: ${file}`)
        } catch (error) {
          console.error(`[Restore] Error restoring file ${file}:`, error.message)
          failedFiles.push({ file, error: error.message })
        }
      }
    }

    return {
      success: failedFiles.length === 0,
      filesRestored: restoredCount,
      restorePath,
      failedFiles,
    }
  } catch (error) {
    console.error(`[Restore] Restore failed:`, error.message)
    throw new Error(`Restore failed: ${error.message}`)
  }
}
