# Windows Smoke-Test Checklist

Run this checklist on a **physical or virtual Windows 10/11 machine** before
each public release. CI verifies the build compiles; this checklist verifies
it runs correctly.

Mark each item ✅ (pass), ❌ (fail — file a bug), or ⚠ (degraded — document).

---

## 1. Installation

- [ ] Run `CreatorForge-<version>-Setup.exe` as a standard (non-admin) user
- [ ] Installer completes without error dialogs
- [ ] Start Menu shortcut created: **CreatorForge**
- [ ] Optional desktop shortcut appears (if selected)
- [ ] Add/Remove Programs lists "CreatorForge" with correct version

**If Python 3 is NOT installed before running the setup:**
- [ ] Installer shows a warning dialog mentioning AI features
- [ ] "Continue without Python" proceeds to successful install
- [ ] App launches and shows "Python not found" in Settings → Dependencies

---

## 2. App launch & basic navigation

- [ ] App window opens (no crash, no blank screen)
- [ ] Title bar shows "CreatorForge"
- [ ] Left nav shows all main sections: Downloads, Audio, AI Tools, Image Tools
- [ ] Settings screen opens; all dependency status rows are visible
- [ ] Window can be resized, minimized, maximized, and closed

---

## 3. Dependency detection

In **Settings → Dependencies**, verify the status of each:

- [ ] yt-dlp: shows installed path or clear "Not found" message
- [ ] FFmpeg: shows installed path or clear "Not found" message
- [ ] Python: shows version or clear "Not found" message

Test with and without each dependency installed. The app must not crash when
any dependency is absent — it must display an actionable error when a feature
is attempted.

---

## 4. Video download (requires yt-dlp)

- [ ] Paste a public YouTube URL into the Downloads input
- [ ] Download starts; progress bar updates
- [ ] Completed download appears in the Downloads list
- [ ] File saved to the configured output folder
- [ ] Cancelling an in-progress download stops the yt-dlp subprocess

---

## 5. Audio extraction (requires FFmpeg)

- [ ] Import a video file via Audio Tools → Extract
- [ ] Select MP3 output; extraction completes without error
- [ ] Output .mp3 file is playable

---

## 6. Browser extension integration

These steps require Chrome and the CreatorForge extension installed.

- [ ] Open Chrome → `chrome://extensions` → enable Developer mode
- [ ] Note the extension ID (32 lowercase letters)
- [ ] Run in PowerShell:
  ```
  "$Env:ProgramFiles\CreatorForge\scripts\install_native_host.ps1" -ExtensionId "<id>"
  ```
- [ ] Script exits without errors
- [ ] Registry key exists:
  ```
  HKCU\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.creatorforge.native_host
  ```
- [ ] Manifest JSON at `%APPDATA%\CreatorForge\NativeHost\` contains the extension ID
- [ ] Click the extension icon on a YouTube page → CreatorForge receives the request
- [ ] Download initiated from the browser appears in the app's Downloads list

---

## 7. Placeholder screens

The following screens are intentionally deferred and show "Coming Soon":

- [ ] Instagram (deferred — no public API)
- [ ] Pinterest (deferred — no public API)
- [ ] Media Converter (deferred — planned for Phase 3)

Verify each shows the placeholder message and does not crash.

---

## 8. Uninstall

- [ ] Open Add/Remove Programs → uninstall CreatorForge
- [ ] NM host registry keys removed from HKCU Chrome + Edge
- [ ] `%APPDATA%\CreatorForge\NativeHost\` folder removed
- [ ] App folder (`%ProgramFiles%\CreatorForge\`) removed
- [ ] User data folder (`%APPDATA%\creator_forge\`) **preserved** (downloads, DB)
- [ ] Start Menu shortcut removed

---

## Notes

Record the Windows version, whether it was a VM, and any failures:

```
Tester:
Date:
Windows version:
VM / physical:
Results:
```
