import express from "express"
import cors from "cors"
import dotenv from "dotenv"
import path from "path"
import { fileURLToPath } from "url"
import fs from "fs"
import multer from "multer"

import authRoutes from "./routes/auth.js"
import backupRoutes from "./routes/backup.js"
import fileRoutes from "./routes/files.js"
import schedulerRoutes from "./routes/scheduler.js"
import decryptRoutes from "./routes/decrypt.js"
import { initializeDatabase } from "./database/db.js"
import { startScheduler } from "./services/scheduler.js"

dotenv.config()

// Get __dirname in ES modules
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()
const PORT = process.env.PORT || 5000

// ✅ Middleware
app.use(cors())
app.use(express.json({ limit: "50mb" }))
app.use(express.urlencoded({ limit: "50mb", extended: true }))

// ✅ Create required directories
const UPLOAD_DIR = path.join(__dirname, "uploads")
const BACKUP_DIR = path.join(__dirname, "backups")

for (const dir of [UPLOAD_DIR, BACKUP_DIR]) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true })
    console.log(`Created folder: ${dir}`)
  }
}

// ✅ Configure file uploads using multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOAD_DIR)
  },
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${file.originalname}`
    cb(null, uniqueName)
  },
})

const upload = multer({ storage })

// ✅ File upload route for Flutter frontend
app.post("/upload", upload.single("file"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" })
  }

  const savedPath = path.join(UPLOAD_DIR, req.file.filename)
  console.log("File uploaded:", savedPath)

  // Send back the file’s server path (used by Flutter to store config)
  res.json({
    message: "File uploaded successfully",
    path: savedPath,
  })
})

// ✅ Initialize SQLite database
await initializeDatabase()
import uploadRoutes from "./routes/upload.js";
app.use("/upload", uploadRoutes);


// ✅ Routes
app.use("/api/auth", authRoutes)
app.use("/api/backup", backupRoutes)
app.use("/api/files", fileRoutes)
app.use("/api/scheduler", schedulerRoutes)
app.use("/api/decrypt", decryptRoutes)

// ✅ Health check route
app.get("/api/health", (req, res) => {
  res.json({
    status: "Server is running",
    upload_folder: UPLOAD_DIR,
    backup_folder: BACKUP_DIR,
  })
})

// ✅ Start server + scheduler
app.listen(PORT, () => {
  console.log(`✅ Server running on port ${PORT}`)
  startScheduler()
})
