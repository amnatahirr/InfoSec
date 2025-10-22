import cron from "node-cron"
import { allQuery } from "../database/db.js"
import { performBackup } from "./backup.js"

const activeSchedules = new Map()

export function startScheduler() {
  console.log("[Scheduler] Scheduler started")
  loadSchedules()
}

async function loadSchedules() {
  try {
    const configs = await allQuery('SELECT * FROM backup_configs WHERE is_active = 1 AND schedule_type != "manual"')

    console.log(`[Scheduler] Loading ${configs.length} active schedules`)

    for (const config of configs) {
      scheduleBackup(config)
    }
  } catch (error) {
    console.error("[Scheduler] Error loading schedules:", error.message)
  }
}

export function scheduleBackup(config) {
  // Cancel existing schedule if any
  if (activeSchedules.has(config.id)) {
    activeSchedules.get(config.id).stop()
    console.log(`[Scheduler] Stopped existing schedule for config ${config.id}`)
  }

  let cronExpression

  if (config.schedule_type === "daily") {
    const [hours, minutes] = config.schedule_time.split(":")
    cronExpression = `${minutes} ${hours} * * *`
    console.log(`[Scheduler] Scheduling daily backup at ${config.schedule_time}`)
  } else if (config.schedule_type === "weekly") {
    const [hours, minutes] = config.schedule_time.split(":")
    cronExpression = `${minutes} ${hours} * * 0` // Sunday
    console.log(`[Scheduler] Scheduling weekly backup at ${config.schedule_time} on Sunday`)
  } else if (config.schedule_type === "hourly") {
    cronExpression = `0 * * * *` // Every hour
    console.log(`[Scheduler] Scheduling hourly backup`)
  } else {
    console.warn(`[Scheduler] Unknown schedule type: ${config.schedule_type}`)
    return
  }

  const task = cron.schedule(cronExpression, async () => {
    console.log(`[Scheduler] Running scheduled backup for config ${config.id}`)
    try {
      const password = process.env[`BACKUP_PASSWORD_${config.id}`] || process.env.BACKUP_PASSWORD

      if (!password) {
        throw new Error("Backup password not configured")
      }

      const result = await performBackup(config.id, password)
      console.log(`[Scheduler] Backup completed: ${result.filesBackedUp} files backed up`)
    } catch (error) {
      console.error(`[Scheduler] Scheduled backup failed for config ${config.id}:`, error.message)
    }
  })

  activeSchedules.set(config.id, task)
  console.log(`[Scheduler] Schedule activated for config ${config.id}`)
}

export function stopSchedule(configId) {
  if (activeSchedules.has(configId)) {
    activeSchedules.get(configId).stop()
    activeSchedules.delete(configId)
    console.log(`[Scheduler] Schedule stopped for config ${configId}`)
  }
}

export function getActiveSchedules() {
  return Array.from(activeSchedules.keys())
}
