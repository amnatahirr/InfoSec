import express from "express"
import { verifyToken } from "./auth.js"
import { performBackup, restoreBackup } from "../services/backup.js"
import { validatePasswordStrength } from "../services/encryption.js"
import { runQuery, allQuery, getQuery } from "../database/db.js"

const router = express.Router()

router.post("/config", verifyToken, async (req, res) => {
  try {
    const { name, sourcePaths, backupFolder, scheduleType, scheduleTime, retentionDays } = req.body

    // Validate input
    if (!name || !sourcePaths || !backupFolder) {
      return res.status(400).json({ error: "Missing required fields" })
    }

    if (!Array.isArray(sourcePaths) || sourcePaths.length === 0) {
      return res.status(400).json({ error: "At least one source path is required" })
    }

    if (scheduleType !== "manual" && !scheduleTime) {
      return res.status(400).json({ error: "Schedule time required for automated backups" })
    }

    const result = await runQuery(
      "INSERT INTO backup_configs (user_id, name, source_paths, backup_folder, schedule_type, schedule_time, retention_days) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [req.userId, name, JSON.stringify(sourcePaths), backupFolder, scheduleType, scheduleTime, retentionDays || 7],
    )

    res.json({ success: true, configId: result.id })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.get("/configs", verifyToken, async (req, res) => {
  try {
    const configs = await allQuery("SELECT * FROM backup_configs WHERE user_id = ?", [req.userId])

    res.json({ success: true, configs })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.get("/config/:configId", verifyToken, async (req, res) => {
  try {
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ? AND user_id = ?", [
      req.params.configId,
      req.userId,
    ])

    if (!config) {
      return res.status(404).json({ error: "Configuration not found" })
    }

    res.json({ success: true, config })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.post("/validate-password", verifyToken, async (req, res) => {
  try {
    const { password } = req.body

    if (!password) {
      return res.status(400).json({ error: "Password required" })
    }

    const strength = validatePasswordStrength(password)

    res.json({
      success: true,
      isValid: strength.isValid,
      score: strength.score,
      feedback: strength.feedback,
    })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.post("/perform/:configId", verifyToken, async (req, res) => {
  try {
    const { password } = req.body

    if (!password) {
      return res.status(400).json({ error: "Password required" })
    }

    // Verify config belongs to user
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ? AND user_id = ?", [
      req.params.configId,
      req.userId,
    ])

    if (!config) {
      return res.status(404).json({ error: "Configuration not found" })
    }

    const result = await performBackup(req.params.configId, password)
    res.json(result)
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.get("/history/:configId", verifyToken, async (req, res) => {
  try {
    // Verify config belongs to user
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ? AND user_id = ?", [
      req.params.configId,
      req.userId,
    ])

    if (!config) {
      return res.status(404).json({ error: "Configuration not found" })
    }

    const history = await allQuery(
      "SELECT * FROM backup_history WHERE config_id = ? ORDER BY created_at DESC LIMIT 50",
      [req.params.configId],
    )

    res.json({ success: true, history })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.get("/stats/:configId", verifyToken, async (req, res) => {
  try {
    // Verify config belongs to user
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ? AND user_id = ?", [
      req.params.configId,
      req.userId,
    ])

    if (!config) {
      return res.status(404).json({ error: "Configuration not found" })
    }

    const stats = await getQuery(
      `SELECT 
        COUNT(*) as total_backups,
        SUM(file_count) as total_files,
        SUM(total_size) as total_size,
        MAX(created_at) as last_backup
      FROM backup_history WHERE config_id = ?`,
      [req.params.configId],
    )

    res.json({ success: true, stats })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.post("/restore/:backupId", verifyToken, async (req, res) => {
  try {
    const { password, restorePath } = req.body

    if (!password || !restorePath) {
      return res.status(400).json({ error: "Password and restore path required" })
    }

    const backup = await getQuery(
      `SELECT bh.* FROM backup_history bh 
       JOIN backup_configs bc ON bh.config_id = bc.id 
       WHERE bh.id = ? AND bc.user_id = ?`,
      [req.params.backupId, req.userId],
    )

    if (!backup) {
      return res.status(404).json({ error: "Backup not found" })
    }

    const result = await restoreBackup(req.params.backupId, password, restorePath)
    res.json(result)
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.delete("/config/:configId", verifyToken, async (req, res) => {
  try {
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ? AND user_id = ?", [
      req.params.configId,
      req.userId,
    ])

    if (!config) {
      return res.status(404).json({ error: "Configuration not found" })
    }

    await runQuery("DELETE FROM backup_configs WHERE id = ?", [req.params.configId])
    await runQuery("DELETE FROM backup_history WHERE config_id = ?", [req.params.configId])
    await runQuery("DELETE FROM file_metadata WHERE config_id = ?", [req.params.configId])

    res.json({ success: true })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

export default router
