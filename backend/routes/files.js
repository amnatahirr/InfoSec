import express from "express"
import { verifyToken } from "./auth.js"
import { getFilesFromPaths } from "../services/fileOperations.js"

const router = express.Router()

// Get files from paths
router.post("/list", verifyToken, async (req, res) => {
  try {
    const { paths } = req.body
    const files = await getFilesFromPaths(paths)
    res.json({ success: true, files })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

export default router
