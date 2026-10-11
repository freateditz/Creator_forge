# Troubleshooting

## Finding log files

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/creator_forge/logs/creator_forge.log` |
| Windows | `%APPDATA%\creator_forge\logs\creator_forge.log` |

---

## FFmpeg not found

**Symptom:** Downloads fail or audio conversion shows "FFmpeg not available."

**Fix:**
1. Verify FFmpeg is installed: `ffmpeg -version`
2. Ensure the `ffmpeg` executable is on your `PATH`, or place `ffmpeg.exe` (and
   `ffprobe.exe`) in `C:\Program Files\CreatorForge\bin\` (Windows) or
   `/opt/homebrew/bin/` (macOS via Homebrew)
3. Restart CreatorForge after adding FFmpeg to PATH

---

## yt-dlp not found

**Symptom:** Downloads fail with "yt-dlp not available" or no download starts.

**Fix:**
1. Verify: `yt-dlp --version`
2. Install or update yt-dlp (see INSTALLATION.md)
3. Restart CreatorForge. The locator re-checks on each app launch.

---

## AI runtime not found (vocal separation)

**Symptom:** Vocal Separator shows "Python runtime not available" or fails to
start the demucs worker.

**Fix:**
1. Verify Python 3.10+ is installed: `python3 --version` (macOS) or
   `python --version` (Windows)
2. On Windows, ensure Python was added to PATH during installation
3. Open CreatorForge → Vocal Separator → click **Set up runtime** to trigger
   venv creation

---

## AI model not installed

**Symptom:** "Model not installed" shown in Vocal Separator or Background Remover.

**Fix:**
Click **Install model** in the relevant screen. CreatorForge downloads and
caches the model. Requires ~83 MB (htdemucs) or ~177 MB (isnet).

---

## Browser extension not connecting

**Symptom:** Extension popup shows "Not connected" badge or "Native host not found."

**Checklist:**
1. Verify the native host is installed: run `install_macos.sh` or
   `install_windows.ps1` (see BROWSER_EXTENSION.md)
2. Verify the extension ID in the NM manifest matches the loaded extension:
   - Open `chrome://extensions/` and copy the ID
   - Re-run the install script with that ID
3. Verify Python 3 is in PATH (the native host is a Python script)
4. Try reloading the extension in `chrome://extensions/`

**macOS — check manifest location:**
```
~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.creatorforge.native_host.json
```

**Windows — check registry:**
```
HKCU\Software\Google\Chrome\NativeMessagingHosts\com.creatorforge.native_host
```

---

## "CreatorForge not running" from extension

**Symptom:** Extension popup shows "CreatorForge is not running."

**Fix:**
1. Launch CreatorForge before clicking the extension
2. If CreatorForge is open but the error persists, check the IPC conn file:
   - macOS: `~/Library/Application Support/creator_forge/ipc/creator_forge.conn`
   - Windows: `%APPDATA%\creator_forge\ipc\creator_forge.conn`
3. If the file is missing, restart CreatorForge
4. If the file exists but connection fails, it may be stale from a crashed session —
   restart CreatorForge to rewrite it

---

## Download fails with no visible error

**Fix:**
1. Check the log file for details
2. Try the URL directly in the YouTube screen to get a better error message
3. Update yt-dlp (`yt-dlp -U`) — many failures are caused by outdated extractors

---

## Audio conversion fails

**Fix:**
1. Verify FFmpeg: `ffmpeg -version`
2. Check that the input file exists and is readable
3. Check available disk space in the output directory
4. Look at the log for the specific FFmpeg error message

---

## Vocal separation fails

**Fix:**
1. Verify the demucs runtime is set up (Vocal Separator → runtime status)
2. Verify the htdemucs model is installed
3. Check available RAM — demucs requires ~2 GB for short clips, more for longer ones
4. On macOS, MPS acceleration requires macOS 12.3+; older systems fall back to CPU

---

## Background removal fails

**Fix:**
1. Verify the bg-removal runtime is set up
2. Verify the isnet model is installed
3. Input must be a supported image format (JPEG, PNG, WEBP, BMP)
4. Check log for the Python traceback

---

## Windows: PATH issues

**Symptom:** FFmpeg, yt-dlp, or Python not found despite being installed.

**Fix:**
1. Open **System Properties → Environment Variables**
2. Check both User and System `PATH` entries
3. Add the missing directory (e.g., `C:\Python311\Scripts` for yt-dlp via pip)
4. Restart CreatorForge (PATH changes don't propagate to running processes)

Alternatively, place executables directly in `C:\Program Files\CreatorForge\bin\`
which CreatorForge searches before checking PATH.

---

## macOS: Gatekeeper blocks the app

**Symptom:** "CreatorForge cannot be opened because the developer cannot be verified."

**Fix (developer build only — do not do this for unknown binaries):**
```bash
xattr -cr /path/to/creator_forge.app
```

Or right-click → Open the first time to bypass the warning.

The release build must be signed and notarized to avoid this prompt.
See BUILD.md for signing requirements.
