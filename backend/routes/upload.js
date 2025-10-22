import express from "express";
import multer from "multer";
import path from "path";
import fs from "fs";

const router = express.Router();

// Create uploads directory if not exists
const UPLOAD_DIR = path.join(process.cwd(), "uploads");
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  console.log("✅ Created uploads folder at:", UPLOAD_DIR);
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOAD_DIR);
  },
  filename: (req, file, cb) => {
    const uniqueName = Date.now() + "_" + file.originalname;
    cb(null, uniqueName);
  },
});

const upload = multer({ storage });

router.post("/", upload.single("file"), (req, res) => {
  const savedPath = path.join(UPLOAD_DIR, req.file.filename);
  console.log("✅ File uploaded:", savedPath);
  res.json({ path: savedPath });
});

export default router;
