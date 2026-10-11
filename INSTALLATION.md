# Installation Guide (Windows)

## Prerequisites

- Windows 10 version 1903 or later, 64-bit
- Internet connection for downloading dependencies

---

## Step 1 — Install CreatorForge

**Option A — Installer (recommended)**

Download `CreatorForge-1.0.0-Setup.exe` from the project's GitHub Releases page
and run it. The installer:

- Copies the application to `%LocalAppData%\Programs\CreatorForge\` (per-user,
  no admin rights required; you can choose a different path).
- Creates a Start Menu shortcut.
- Registers the native messaging host infrastructure (Python wrapper and
  registry keys for Chrome and Edge).

> **Note:** The installer is currently unsigned. Windows SmartScreen will show
> "Windows protected your PC". Click **More info → Run anyway** to proceed.
> See `WINDOWS_BUILD.md` for the code-signing roadmap.

**Option B — Manual / developer**

1. Download the `creator_forge_windows_release` artifact from a CI run.
2. Extract to a permanent directory (e.g., `C:\Program Files\CreatorForge\`).
3. Run `creator_forge.exe` from that directory.

Required files alongside `creator_forge.exe`:
- `flutter_windows.dll` (and other `*.dll` files)
- `data\` directory (Flutter assets, including Python workers)

---

## Step 2 — Install FFmpeg

FFmpeg is required for audio extraction, conversion, and vocal separation.

**Option A — winget (recommended)**
```powershell
winget install Gyan.FFmpeg
```

**Option B — manual**
1. Download a Windows build from https://www.gyan.dev/ffmpeg/builds/
2. Extract to `C:\Program Files\FFmpeg\`
3. Add `C:\Program Files\FFmpeg\bin` to your `PATH` environment variable

**Verify:**
```powershell
ffmpeg -version
```

CreatorForge also searches `C:\Program Files\CreatorForge\bin\ffmpeg.exe` (and
several other common locations including Scoop and Chocolatey paths).
Placing `ffmpeg.exe` and `ffprobe.exe` at one of those paths avoids the PATH
requirement. See `docs/dependency_provisioning.md` for the full search order.

---

## Step 3 — Install yt-dlp

yt-dlp is required for the download engine.

**Option A — winget**
```powershell
winget install yt-dlp.yt-dlp
```

**Option B — pip**
```powershell
pip install yt-dlp
```

**Option C — standalone binary**
Download `yt-dlp.exe` from https://github.com/yt-dlp/yt-dlp/releases and place
it in `C:\Program Files\CreatorForge\bin\` or anywhere on your PATH.

**Verify:**
```powershell
yt-dlp --version
```

---

## Step 4 — Install Python 3.10+ (for AI features)

Vocal separation and background removal require Python 3.10 or later.

**Option A — winget**
```powershell
winget install Python.Python.3.11
```

**Option B — installer**
Download from https://www.python.org/downloads/windows/. Select
"Add Python to PATH" during setup.

**Verify:**
```powershell
python --version
```

On first use, CreatorForge will automatically create isolated virtual
environments for demucs and rembg in its application data directory.
No manual `pip install` is required.

---

## Step 5 — Install the browser extension and native host

See [BROWSER_EXTENSION.md](BROWSER_EXTENSION.md) for the full setup flow.

Short version:
1. Build or download the extension package
2. Load it in Chrome/Edge (`chrome://extensions` → Developer mode → Load unpacked)
3. Note the extension ID (32 lowercase letters shown under the extension name)
4. Run the registration script with your extension ID:

```powershell
& "$Env:ProgramFiles\CreatorForge\scripts\install_native_host.ps1" -ExtensionId "abcdefghijklmnopabcdefghijklmnop"
```

If you used the installer, the native host infrastructure is already in place —
you only need to run the script above with your extension ID to activate it.

---

## Verifying the installation

Launch CreatorForge and open **Settings**. The status panel shows whether
FFmpeg, yt-dlp, and Python were found and their versions.

If a dependency is missing, its status is shown in red with a resolution hint.

---

## Optional — Install AI models

AI models are not bundled with the application to keep the download size small.

**Vocal separator (htdemucs, ~83 MB)**
Open the **Vocal Separator** tab in CreatorForge and click **Install model**.
The model is downloaded from HuggingFace and cached in the app data directory.

> **License:** htdemucs is licensed CC BY-NC 4.0. Non-commercial use only.

**Background remover (isnet-general-use, ~177 MB)**
Open the **Background Remover** tab and click **Install model**.
The model is downloaded via rembg and cached locally.

---

## Application data location

CreatorForge stores all data under:
```
%APPDATA%\creator_forge\
```

Subdirectories:
- `models\` — AI model weights and Python venvs
- `ipc\` — IPC connection descriptor (written at startup, removed at exit)
- `temp\` — Temporary download files
- `logs\` — Application logs

This directory is **preserved** when you uninstall CreatorForge. To fully
remove all data, delete this directory manually after uninstalling.
