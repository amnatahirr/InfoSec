import express from "express"
import bcrypt from "bcryptjs"
import jwt from "jsonwebtoken"
import { runQuery, getQuery } from "../database/db.js"

const router = express.Router()
const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key"

// Register
router.post("/register", async (req, res) => {
  try {
    const { username, password } = req.body

    if (!username || !password) {
      return res.status(400).json({ error: "Username and password required" })
    }

    const hashedPassword = await bcrypt.hash(password, 10)

    const result = await runQuery("INSERT INTO users (username, password_hash) VALUES (?, ?)", [
      username,
      hashedPassword,
    ])

    const token = jwt.sign({ userId: result.id, username }, JWT_SECRET)

    res.json({ success: true, token, userId: result.id })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

// Login
router.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body

    const user = await getQuery("SELECT * FROM users WHERE username = ?", [username])

    if (!user) {
      return res.status(401).json({ error: "Invalid credentials" })
    }

    const validPassword = await bcrypt.compare(password, user.password_hash)

    if (!validPassword) {
      return res.status(401).json({ error: "Invalid credentials" })
    }

    const token = jwt.sign({ userId: user.id, username: user.username }, JWT_SECRET)

    res.json({ success: true, token, userId: user.id })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})

// Middleware to verify token
export function verifyToken(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1]

  if (!token) {
    return res.status(401).json({ error: "No token provided" })
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET)
    req.userId = decoded.userId
    next()
  } catch (error) {
    res.status(401).json({ error: "Invalid token" })
  }
}

export default router
