import sqlite3 from "sqlite3"
import path from "path"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const DB_PATH = path.join(__dirname, "../data/backup.db")

let db

export function getDatabase() {
  if (!db) {
    db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) console.error("Database connection error:", err)
      else console.log("Connected to SQLite database")
    })
  }
  return db
}

export async function initializeDatabase() {
  return new Promise((resolve, reject) => {
    const database = getDatabase()

    database.serialize(() => {
      // Users table
      database.run(`
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `)

      // Backup configurations table
      database.run(`
        CREATE TABLE IF NOT EXISTS backup_configs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          source_paths TEXT NOT NULL,
          backup_folder TEXT NOT NULL,
          schedule_type TEXT DEFAULT 'manual',
          schedule_time TEXT,
          retention_days INTEGER DEFAULT 7,
          is_active BOOLEAN DEFAULT 1,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      `)

      // Backup history table
      database.run(`
        CREATE TABLE IF NOT EXISTS backup_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          config_id INTEGER NOT NULL,
          backup_path TEXT NOT NULL,
          file_count INTEGER,
          total_size INTEGER,
          status TEXT DEFAULT 'success',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (config_id) REFERENCES backup_configs(id)
        )
      `)

      // File metadata table (for change detection)
      database.run(
        `
        CREATE TABLE IF NOT EXISTS file_metadata (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          config_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          file_hash TEXT,
          last_modified DATETIME,
          file_size INTEGER,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (config_id) REFERENCES backup_configs(id)
        )
      `,
        (err) => {
          if (err) reject(err)
          else resolve()
        },
      )
    })
  })
}

export function runQuery(query, params = []) {
  return new Promise((resolve, reject) => {
    getDatabase().run(query, params, function (err) {
      if (err) reject(err)
      else resolve({ id: this.lastID, changes: this.changes })
    })
  })
}

export function getQuery(query, params = []) {
  return new Promise((resolve, reject) => {
    getDatabase().get(query, params, (err, row) => {
      if (err) reject(err)
      else resolve(row)
    })
  })
}

export function allQuery(query, params = []) {
  return new Promise((resolve, reject) => {
    getDatabase().all(query, params, (err, rows) => {
      if (err) reject(err)
      else resolve(rows || [])
    })
  })
}
