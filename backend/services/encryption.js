import crypto from "crypto"
import fs from "fs/promises"
import path from "path"

const ALGORITHM = "aes-256-gcm"
const SALT_LENGTH = 16 // 128-bit salt (smaller & standard)
const TAG_LENGTH = 16
const IV_LENGTH = 12
const PBKDF2_ITERATIONS = 100000

/**
 * Derive a 256-bit encryption key from a password and salt using PBKDF2.
 */
export function deriveKey(password, salt = null) {
  if (!salt) salt = crypto.randomBytes(SALT_LENGTH)

  const key = crypto.pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, 32, "sha256")
  return { key, salt }
}

/**
 * Ensure that a directory exists before writing files to it.
 */
export async function ensureDir(dirPath) {
  await fs.mkdir(dirPath, { recursive: true })
}

/**
 * Encrypt a file using a pre-derived AES-256-GCM key.
 * Output format: [Salt(16)][IV(12)][AuthTag(16)][EncryptedData]
 */
export async function encryptFile(inputPath, outputPath, key, salt) {
  try {
    const fileData = await fs.readFile(inputPath)
    const iv = crypto.randomBytes(IV_LENGTH)

    const cipher = crypto.createCipheriv(ALGORITHM, key, iv)
    let encrypted = cipher.update(fileData)
    encrypted = Buffer.concat([encrypted, cipher.final()])

    const authTag = cipher.getAuthTag()

    const result = Buffer.concat([salt, iv, authTag, encrypted])

    await ensureDir(path.dirname(outputPath))
    await fs.writeFile(outputPath, result)

    return {
      success: true,
      size: result.length,
      originalSize: fileData.length,
      encryptedSize: encrypted.length,
      path: outputPath,
    }
  } catch (error) {
    throw new Error(`Encryption failed for ${inputPath}: ${error.message}`)
  }
}

/**
 * Decrypt a file using a password (derives key from stored salt).
 */
export async function decryptFile(inputPath, outputPath, password) {
  try {
    const encryptedData = await fs.readFile(inputPath)

    if (encryptedData.length < SALT_LENGTH + IV_LENGTH + TAG_LENGTH) {
      throw new Error("Invalid encrypted file format")
    }

    const salt = encryptedData.slice(0, SALT_LENGTH)
    const iv = encryptedData.slice(SALT_LENGTH, SALT_LENGTH + IV_LENGTH)
    const authTag = encryptedData.slice(SALT_LENGTH + IV_LENGTH, SALT_LENGTH + IV_LENGTH + TAG_LENGTH)
    const encrypted = encryptedData.slice(SALT_LENGTH + IV_LENGTH + TAG_LENGTH)

    const { key } = deriveKey(password, salt)

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv)
    decipher.setAuthTag(authTag)

    let decrypted = decipher.update(encrypted)
    decrypted = Buffer.concat([decrypted, decipher.final()])

    await ensureDir(path.dirname(outputPath))
    await fs.writeFile(outputPath, decrypted)

    return {
      success: true,
      size: decrypted.length,
      encryptedSize: encrypted.length,
      path: outputPath,
    }
  } catch (error) {
    throw new Error(`Decryption failed for ${inputPath}: ${error.message}`)
  }
}

/**
 * Generate a SHA-256 hash of a file's contents — used for change detection.
 */
export async function generateFileHash(filePath) {
  try {
    const fileData = await fs.readFile(filePath)
    return crypto.createHash("sha256").update(fileData).digest("hex")
  } catch (error) {
    throw new Error(`Hash generation failed for ${filePath}: ${error.message}`)
  }
}

/**
 * Validate password strength (used during password creation/validation step).
 */
export function validatePasswordStrength(password) {
  const minLength = 8
  const hasUpperCase = /[A-Z]/.test(password)
  const hasLowerCase = /[a-z]/.test(password)
  const hasNumbers = /\d/.test(password)
  const hasSpecialChar = /[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?]/.test(password)

  const strength = {
    isValid: password.length >= minLength,
    score: 0,
    feedback: [],
  }

  if (password.length < minLength) {
    strength.feedback.push(`Password must be at least ${minLength} characters long`)
  } else {
    strength.score += 1
  }

  if (hasUpperCase) strength.score += 1
  else strength.feedback.push("Add uppercase letters")

  if (hasLowerCase) strength.score += 1
  else strength.feedback.push("Add lowercase letters")

  if (hasNumbers) strength.score += 1
  else strength.feedback.push("Add numbers")

  if (hasSpecialChar) strength.score += 1
  else strength.feedback.push("Add special characters")

  return strength
}
