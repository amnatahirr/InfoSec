import path from "path"
import fs from "fs/promises"
import crypto from "crypto"

import { deriveKey, encryptFile, decryptFile, generateFileHash, ensureDir } from "./encryption.js"
import { runQuery, getQuery } from "../database/db.js"

/**
 * Load or create per-config salt file (.config_<id>.json)
 */
async function loadOrCreateSaltFile(backupFolder, configId) {
  const saltFilePath = path.join(backupFolder, `.config_${configId}.json`)
  try {
    const txt = await fs.readFile(saltFilePath, "utf8")
    const data = JSON.parse(txt)
    return Buffer.from(data.salt, "base64")
  } catch {
    const salt = crypto.randomBytes(16)
    const data = { salt: salt.toString("base64") }
    await fs.writeFile(saltFilePath, JSON.stringify(data, null, 2))
    return salt
  }
}

/**
 * Recursively list all files from given source paths.
 */
async function getAllFiles(paths) {
  const result = []
  for (const p of paths) {
    try {
      const stat = await fs.stat(p)
      if (stat.isDirectory()) {
        const entries = await fs.readdir(p, { withFileTypes: true })
        for (const e of entries) {
          const full = path.join(p, e.name)
          if (e.isDirectory()) {
            const sub = await getAllFiles([full])
            result.push(...sub)
          } else result.push(full)
        }
      } else result.push(p)
    } catch (e) {
      console.warn(`[Backup] Skipped invalid path: ${p} (${e.message})`)
    }
  }
  return result
}

/**
 * Simple change-detection based on file hash.
 */
async function isFileModified(configId, filePath, newHash) {
  const row = await getQuery("SELECT file_hash FROM file_metadata WHERE config_id=? AND file_path=?", [
    configId,
    filePath,
  ])
  return !row || row.file_hash !== newHash
}

/**
 * Insert or update file metadata record.
 */
async function updateFileMetadata(configId, filePath, hash) {
  const row = await getQuery("SELECT id FROM file_metadata WHERE config_id=? AND file_path=?", [configId, filePath])
  if (row) {
    await runQuery("UPDATE file_metadata SET file_hash=?, updated_at=CURRENT_TIMESTAMP WHERE id=?", [hash, row.id])
  } else {
    await runQuery(
      "INSERT INTO file_metadata (config_id, file_path, file_hash, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
      [configId, filePath, hash],
    )
  }
}

/**
 * Delete backups older than the configured retention period.
 */
async function cleanOldBackups(backupFolder, retentionDays) {
  try {
    const entries = await fs.readdir(backupFolder, { withFileTypes: true })
    let deleted = 0
    for (const e of entries) {
      if (!e.isDirectory() || e.name.startsWith(".config_")) continue
      const full = path.join(backupFolder, e.name)
      const stat = await fs.stat(full)
      const ageDays = (Date.now() - stat.mtimeMs) / (1000 * 60 * 60 * 24)
      if (ageDays > retentionDays) {
        await fs.rm(full, { recursive: true, force: true })
        deleted++
      }
    }
    return deleted
  } catch (e) {
    console.warn(`[Backup] Retention cleanup warning: ${e.message}`)
    return 0
  }
}

/**
 * Perform encrypted backup
 */
export async function performBackup(configId, password) {
  try {
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ?", [configId])
    if (!config) throw new Error("Backup configuration not found")

    const sourcePaths = JSON.parse(config.source_paths)
    const backupFolder = config.backup_folder
    const retentionDays = Number(config.retention_days || 4)
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-")
    const backupSessionPath = path.join(backupFolder, `backup_${timestamp}`)

    await ensureDir(backupFolder)
    await ensureDir(backupSessionPath)

    console.log(`[Backup] Starting backup for config ${configId}`)
    console.log(`[Backup] Sources: ${sourcePaths.join(", ")}`)
    console.log(`[Backup] Backup session: ${backupSessionPath}`)

    // 1️⃣ Load / create salt, derive encryption key
    const salt = await loadOrCreateSaltFile(backupFolder, configId)
    const { key } = deriveKey(password, salt)

    // 2️⃣ Collect files
    const allFiles = await getAllFiles(sourcePaths)
    console.log(`[Backup] Found ${allFiles.length} total files`)

    let successCount = 0
    let totalSize = 0
    const failedFiles = []

    for (const file of allFiles) {
      try {
        const fileHash = await generateFileHash(file)
        const modified = await isFileModified(configId, file, fileHash)
        if (!modified) continue

        // ✅ FIXED PATH LOGIC
        let relativePath = path.relative(sourcePaths[0], file)
if (!relativePath || relativePath === "") {
  // If the source path itself is a file, use its filename directly
  relativePath = path.basename(file)
}
const destPath = path.join(backupSessionPath, relativePath + ".enc")


        // Ensure directories exist before writing
        await fs.mkdir(path.dirname(destPath), { recursive: true })

        await encryptFile(file, destPath, key, salt)
        await updateFileMetadata(configId, file, fileHash)

        const stat = await fs.stat(file)
        totalSize += stat.size
        successCount++

        console.log(`[Backup] Encrypted: ${file}`)
      } catch (err) {
        console.error(`[Backup] Failed ${file}: ${err.message}`)
        failedFiles.push({ file, error: err.message })
      }
    }

    // 4️⃣ Log history
    const status = failedFiles.length === 0 ? "success" : "partial"
    await runQuery(
      "INSERT INTO backup_history (config_id, backup_path, file_count, total_size, status) VALUES (?, ?, ?, ?, ?)",
      [configId, backupSessionPath, successCount, totalSize, status],
    )

    // 5️⃣ Retention cleanup
    const deletedCount = await cleanOldBackups(backupFolder, retentionDays)
    console.log(`[Backup] Deleted ${deletedCount} old backups`)

    return {
      success: failedFiles.length === 0,
      filesBackedUp: successCount,
      totalSize,
      backupPath: backupSessionPath,
      failedFiles,
      status,
      message:
        successCount === 0
          ? "No modified files found. Nothing new to backup."
          : `Backup completed: ${successCount} file(s) encrypted.`,
    }
  } catch (error) {
    console.error(`[Backup] Backup failed: ${error.message}`)
    throw new Error(`Backup failed: ${error.message}`)
  }
}

/**
 * Restore files from an encrypted backup folder
 */
export async function restoreBackup(backupId, password, restorePath) {
  try {
    const backup = await getQuery("SELECT * FROM backup_history WHERE id = ?", [backupId])
    if (!backup) throw new Error("Backup not found")

    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ?", [backup.config_id])
    if (!config) throw new Error("Config not found for this backup")

    const backupFolder = config.backup_folder
    const saltFile = path.join(backupFolder, `.config_${config.id}.json`)
    const { salt } = JSON.parse(await fs.readFile(saltFile, "utf8"))
    const { key } = deriveKey(password, Buffer.from(salt, "base64"))

    let restoredCount = 0
    const failedFiles = []

    async function walk(dir) {
      const items = await fs.readdir(dir, { withFileTypes: true })
      for (const e of items) {
        const full = path.join(dir, e.name)
        if (e.isDirectory()) {
          await walk(full)
        } else if (e.name.endsWith(".enc")) {
          try {
            const relativePath = path.relative(backup.backup_path, full)
            const destPath = path.join(restorePath, relativePath.replace(/\.enc$/, ""))

            await ensureDir(path.dirname(destPath))
            await decryptFile(full, destPath, password)
            restoredCount++
            console.log(`[Restore] Decrypted: ${full} -> ${destPath}`)
          } catch (err) {
            console.error(`[Restore] Failed ${e.name}: ${err.message}`)
            failedFiles.push({ file: e.name, error: err.message })
          }
        }
      }
    }

    await walk(backup.backup_path)

    return {
      success: failedFiles.length === 0,
      filesRestored: restoredCount,
      restorePath,
      failedFiles,
      message:
        failedFiles.length === 0
          ? "All files restored successfully."
          : `Restored ${restoredCount} files with some errors.`,
    }
  } catch (error) {
    console.error(`[Restore] Restore failed: ${error.message}`)
    throw new Error(`Restore failed: ${error.message}`)
  }
}
