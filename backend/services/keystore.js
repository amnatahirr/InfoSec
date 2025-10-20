// backend/services/keystore.js
import fs from "fs/promises";
import path from "path";

export async function loadOrCreateKeyConfig(backupFolder, configId, saltBuf) {
  const p = path.join(backupFolder, `.config_${configId}.json`);
  try {
    const txt = await fs.readFile(p, "utf8");
    return JSON.parse(txt);
  } catch {
    const cfg = { kdf: "pbkdf2", salt_b64: saltBuf.toString("base64"), iters: 200000 };
    await fs.writeFile(p, JSON.stringify(cfg, null, 2));
    return cfg;
  }
}
