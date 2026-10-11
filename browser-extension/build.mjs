#!/usr/bin/env node
/**
 * CreatorForge Extension Build Script
 *
 * Bundles TypeScript source files with esbuild.
 * Copies static assets (manifest, popup.html, icons) into dist/.
 * Creates placeholder icon PNGs if the icons/ directory is empty.
 *
 * Usage:
 *   node build.mjs           # single build
 *   node build.mjs --watch   # incremental rebuild
 */

import * as esbuild from "esbuild";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const watch = process.argv.includes("--watch");

const distDir = path.join(__dirname, "dist");
fs.mkdirSync(distDir, { recursive: true });
fs.mkdirSync(path.join(distDir, "icons"), { recursive: true });

// ── Build TypeScript entry points ─────────────────────────────────────────────

const buildCtx = await esbuild.context({
  entryPoints: {
    background: "src/background.ts",
    content: "src/content.ts",
    popup: "src/popup.ts",
  },
  bundle: true,
  format: "esm",
  platform: "browser",
  target: "chrome120",
  outdir: "dist",
  logLevel: "info",
});

if (watch) {
  await buildCtx.watch();
  console.log("Watching for changes…");
} else {
  await buildCtx.rebuild();
  await buildCtx.dispose();
}

// ── Copy static assets ────────────────────────────────────────────────────────

const staticFiles = ["manifest.json", "popup.html"];
for (const f of staticFiles) {
  const src = path.join(__dirname, f);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(distDir, f));
    console.log(`Copied: ${f}`);
  }
}

// ── Generate placeholder icons if missing ─────────────────────────────────────
// In production, replace these with a proper designer-made icon set.

const iconSizes = [16, 32, 48, 128];

async function generateIcons() {
  for (const size of iconSizes) {
    const srcPath = path.join(__dirname, "icons", `icon${size}.png`);
    const dstPath = path.join(distDir, "icons", `icon${size}.png`);

    if (fs.existsSync(srcPath)) {
      fs.copyFileSync(srcPath, dstPath);
      continue;
    }

    // Write a minimal valid 1×1 PNG placeholder.
    // Replace with a real icon set before public distribution — see
    // browser-extension/icons/README.md for the required sizes.
    console.warn(`  WARNING: No icon found for ${size}×${size}. Using placeholder PNG.`);
    const minimalPng = Buffer.from(
      "89504e470d0a1a0a0000000d494844520000000100000001" +
      "08020000009001" +
      "2e000000000c4944415408d76360f8cf000000020001e221bc33000000004945" +
      "4e44ae426082",
      "hex"
    );
    fs.writeFileSync(dstPath, minimalPng);
    console.log(`Icon: ${size}×${size}`);
  }
}

await generateIcons();
console.log(`\nBuild complete → ${distDir}`);
