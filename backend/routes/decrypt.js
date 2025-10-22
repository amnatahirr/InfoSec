import express from "express"
import { verifyToken } from "./auth.js"
import { decryptFile } from "../services/encryption.js"
import path from "path"
import fs from "fs/promises"

const router = express.Router()

router.post("/file", verifyToken, async (req, res) => {
  try {
    const { encryptedFilePath, password, outputPath } = req.body

    if (!encryptedFilePath || !password) {
      return res.status(400).json({ error: "Encrypted file path and password required" })
    }

    // Verify file exists
    try {
      await fs.access(encryptedFilePath)
    } catch {
      return res.status(404).json({ error: "Encrypted file not found" })
    }

    const result = await decryptFile(encryptedFilePath, outputPath || encryptedFilePath + ".decrypted", password)

    res.json({
      success: true,
      message: "File decrypted successfully",
      decryptedPath: outputPath || encryptedFilePath + ".decrypted",
      size: result.size,
    })
  } catch (error) {
    res.status(400).json({ error: error.message })
  }
})

router.post("/preview", verifyToken, async (req, res) => {
  try {
    const { encryptedFilePath, password } = req.body

    if (!encryptedFilePath || !password) {
      return res.status(400).json({ error: "Encrypted file path and password required" })
    }

    // Verify file exists
    try {
      await fs.access(encryptedFilePath)
    } catch {
      return res.status(404).json({ error: "Encrypted file not found" })
    }

    const tempPath = encryptedFilePath + ".temp"
    const result = await decryptFile(encryptedFilePath, tempPath, password)

    // Read file content
    const fileContent = await fs.readFile(tempPath, "utf-8").catch(() => null)

    // Get file info
    const fileName = path.basename(encryptedFilePath)
    const fileExt = path.extname(fileName).toLowerCase()

    // Clean up temp file
    await fs.unlink(tempPath).catch(() => {})

    res.json({
      success: true,
      fileName,
      fileExt,
      size: result.size,
      content: fileContent,
      isText: fileExt.match(/\.(txt|json|csv|log|md|xml|html|js|ts|jsx|tsx|py|java|cpp|c|h)$/i) ? true : false,
    })
  } catch (error) {
    res.status(400).json({ error: error.message })
  }
})

router.post("/list", verifyToken, async (req, res) => {
  try {
    const { directoryPath } = req.body

    if (!directoryPath) {
      return res.status(400).json({ error: "Directory path required" })
    }

    // Verify directory exists
    try {
      await fs.access(directoryPath)
    } catch {
      return res.status(404).json({ error: "Directory not found" })
    }

    // List files in directory
    const files = await fs.readdir(directoryPath, { withFileTypes: true })

    const encryptedFiles = await Promise.all(
      files
        .filter((file) => file.isFile())
        .map(async (file) => {
          const filePath = path.join(directoryPath, file.name)
          const stats = await fs.stat(filePath)
          return {
            name: file.name,
            path: filePath,
            size: stats.size,
            modified: stats.mtime,
          }
        }),
    )

    res.json({
      success: true,
      files: encryptedFiles,
    })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

export default router
