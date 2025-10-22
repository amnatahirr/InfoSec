import express from "express"
import { verifyToken } from "./auth.js"
import { scheduleBackup, stopSchedule, getActiveSchedules } from "../services/scheduler.js"
import { runQuery, getQuery } from "../database/db.js"

const router = express.Router()

router.put("/update/:configId", verifyToken, async (req, res) => {
  try {
    const { scheduleType, scheduleTime, isActive } = req.body

    // Verify config belongs to user
    const config = await getQuery("SELECT * FROM backup_configs WHERE id = ? AND user_id = ?", [
      req.params.configId,
      req.userId,
    ])

    if (!config) {
      return res.status(404).json({ error: "Configuration not found" })
    }

    // Validate schedule type
    const validTypes = ["manual", "daily", "weekly", "hourly"]
    if (!validTypes.includes(scheduleType)) {
      return res.status(400).json({ error: "Invalid schedule type" })
    }

    if (scheduleType !== "manual" && !scheduleTime) {
      return res.status(400).json({ error: "Schedule time required for automated backups" })
    }

    await runQuery("UPDATE backup_configs SET schedule_type = ?, schedule_time = ?, is_active = ? WHERE id = ?", [
      scheduleType,
      scheduleTime,
      isActive ? 1 : 0,
      req.params.configId,
    ])

    const updatedConfig = await getQuery("SELECT * FROM backup_configs WHERE id = ?", [req.params.configId])

    if (isActive && scheduleType !== "manual") {
      scheduleBackup(updatedConfig)
    } else {
      stopSchedule(req.params.configId)
    }

    res.json({ success: true })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

router.get("/active", verifyToken, async (req, res) => {
  try {
    const activeSchedules = getActiveSchedules()
    res.json({ success: true, activeSchedules })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

export default router
