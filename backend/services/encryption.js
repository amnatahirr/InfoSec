import crypto from "crypto"
import fs from "fs/promises"

const ALGORITHM = "aes-256-gcm"
const SALT_LENGTH = 64
const TAG_LENGTH = 16
const IV_LENGTH = 12
const PBKDF2_ITERATIONS = 100000

export function deriveKey(password, salt = null) {
  if (!salt) {
    salt = crypto.randomBytes(SALT_LENGTH)
  }

  // PBKDF2 with 100,000 iterations for 256-bit key
  const key = crypto.pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, 32, "sha256")
  return { key, salt }
}

export async function encryptFile(inputPath, outputPath, password) {
  try {
    const fileData = await fs.readFile(inputPath)
    const { key, salt } = deriveKey(password)

    const iv = crypto.randomBytes(IV_LENGTH)
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv)

    let encrypted = cipher.update(fileData)
    encrypted = Buffer.concat([encrypted, cipher.final()])

    const authTag = cipher.getAuthTag()

    // Format: salt (64) + iv (12) + authTag (16) + encrypted data
    const result = Buffer.concat([salt, iv, authTag, encrypted])

    await fs.writeFile(outputPath, result)

    return {
      success: true,
      size: result.length,
      originalSize: fileData.length,
      encryptedSize: encrypted.length,
    }
  } catch (error) {
    throw new Error(`Encryption failed: ${error.message}`)
  }
}

export async function decryptFile(inputPath, outputPath, password) {
  try {
    const encryptedData = await fs.readFile(inputPath)

    // Validate minimum size
    if (encryptedData.length < SALT_LENGTH + IV_LENGTH + TAG_LENGTH) {
      throw new Error("Invalid encrypted file format")
    }

    // Extract components
    const salt = encryptedData.slice(0, SALT_LENGTH)
    const iv = encryptedData.slice(SALT_LENGTH, SALT_LENGTH + IV_LENGTH)
    const authTag = encryptedData.slice(SALT_LENGTH + IV_LENGTH, SALT_LENGTH + IV_LENGTH + TAG_LENGTH)
    const encrypted = encryptedData.slice(SALT_LENGTH + IV_LENGTH + TAG_LENGTH)

    // Derive key from password and salt
    const { key } = deriveKey(password, salt)

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv)
    decipher.setAuthTag(authTag)

    let decrypted = decipher.update(encrypted)
    decrypted = Buffer.concat([decrypted, decipher.final()])

    await fs.writeFile(outputPath, decrypted)

    return {
      success: true,
      size: decrypted.length,
      encryptedSize: encrypted.length,
    }
  } catch (error) {
    throw new Error(`Decryption failed: ${error.message}`)
  }
}

export async function generateFileHash(filePath) {
  try {
    const fileData = await fs.readFile(filePath)
    return crypto.createHash("sha256").update(fileData).digest("hex")
  } catch (error) {
    throw new Error(`Hash generation failed: ${error.message}`)
  }
}

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
    strength.feedback.push(`Password must be at least ${minLength} characters`)
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
