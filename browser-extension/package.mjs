/**
 * CreatorForge Extension Packaging Script
 * Creates production ZIP archives for Chrome Web Store and Microsoft Edge Add-ons.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const distDir = path.join(__dirname, "dist");

console.log("Building extension for packaging...");
execSync("npm run build", { stdio: "inherit" });

const zipName = "creatorforge-extension-prod.zip";
const zipPath = path.join(__dirname, zipName);

if (fs.existsSync(zipPath)) {
  fs.unlinkSync(zipPath);
}

// Simple recursive file list collector
function getFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      getFiles(filePath, fileList);
    } else {
      fileList.push(filePath);
    }
  }
  return fileList;
}

console.log(`Packaging files from ${distDir}...`);
// We can use PowerShell on Windows or zip on Unix, or Node archiver if available.
// Alternatively, instruct user or use built-in node tools / tar / powershell.
try {
  if (process.platform === "win32") {
    execSync(`powershell Compress-Archive -Path "${distDir}\\*" -DestinationPath "${zipPath}" -Force`);
  } else {
    execSync(`cd "${distDir}" && zip -r "${zipPath}" ./*`);
  }
  console.log(`Successfully created production package: ${zipPath}`);
} catch (e) {
  console.error("Failed to create zip archive:", e.message);
  process.exit(1);
}
