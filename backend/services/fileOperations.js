import fs from "fs/promises"
import path from "path"
import { generateFileHash } from "./encryption.js"
import { allQuery, runQuery, getQuery } from "../database/db.js"

// Get all files from source paths
export async function getFilesFromPaths(sourcePaths) {
  const files = []

  for (const sourcePath of sourcePaths) {
    try {
      const stat = await fs.stat(sourcePath)

      if (stat.isDirectory()) {
        const dirFiles = await getAllFilesInDirectory(sourcePath)
        files.push(...dirFiles)
      } else {
        files.push(sourcePath)
      }
    } catch (error) {
      console.error(`Error reading path ${sourcePath}:`, error.message)
    }
  }

  return files
}

// Recursively get all files in directory
async function getAllFilesInDirectory(dirPath) {
  const files = []

  try {
    const entries = await fs.readdir(dirPath, { withFileTypes: true })

    for (const entry of entries) {
      const fullPath = path.join(dirPath, entry.name)

      if (entry.isDirectory()) {
        const subFiles = await getAllFilesInDirectory(fullPath)
        files.push(...subFiles)
      } else {
        files.push(fullPath)
      }
    }
  } catch (error) {
    console.error(`Error reading directory ${dirPath}:`, error.message)
  }

  return files
}

// Check if file has been modified
export async function isFileModified(configId, filePath) {
  try {
    const metadata = await getQuery(
      "SELECT file_hash, last_modified FROM file_metadata WHERE config_id = ? AND file_path = ?",
      [configId, filePath],
    )

    if (!metadata) return true // New file

    const stat = await fs.stat(filePath)
    const currentHash = await generateFileHash(filePath)

    return currentHash !== metadata.file_hash
  } catch (error) {
    console.error(`Error checking file modification:`, error.message)
    return true
  }
}

// Update file metadata
export async function updateFileMetadata(configId, filePath, fileHash) {
  try {
    const stat = await fs.stat(filePath)

    const existing = await getQuery("SELECT id FROM file_metadata WHERE config_id = ? AND file_path = ?", [
      configId,
      filePath,
    ])

    if (existing) {
      await runQuery(
        "UPDATE file_metadata SET file_hash = ?, last_modified = ?, file_size = ?, updated_at = CURRENT_TIMESTAMP WHERE config_id = ? AND file_path = ?",
        [fileHash, new Date().toISOString(), stat.size, configId, filePath],
      )
    } else {
      await runQuery(
        "INSERT INTO file_metadata (config_id, file_path, file_hash, last_modified, file_size) VALUES (?, ?, ?, ?, ?)",
        [configId, filePath, fileHash, new Date().toISOString(), stat.size],
      )
    }
  } catch (error) {
    console.error(`Error updating file metadata:`, error.message)
  }
}

// Copy file to backup location
export async function copyFileToBackup(sourcePath, backupPath) {
  try {
    const backupDir = path.dirname(backupPath)
    await fs.mkdir(backupDir, { recursive: true })
    await fs.copyFile(sourcePath, backupPath)
    return true
  } catch (error) {
    console.error(`Error copying file:`, error.message)
    return false
  }
}

// Clean old backups based on retention policy
export async function cleanOldBackups(configId, retentionDays) {
  try {
    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - retentionDays)

    const oldBackups = await allQuery(
      "SELECT id, backup_path FROM backup_history WHERE config_id = ? AND created_at < ?",
      [configId, cutoffDate.toISOString()],
    )

    for (const backup of oldBackups) {
      try {
        await fs.rm(backup.backup_path, { recursive: true, force: true })
        await runQuery("DELETE FROM backup_history WHERE id = ?", [backup.id])
      } catch (error) {
        console.error(`Error deleting backup ${backup.backup_path}:`, error.message)
      }
    }

    return oldBackups.length
  } catch (error) {
    console.error(`Error cleaning old backups:`, error.message)
    return 0
  }
}
