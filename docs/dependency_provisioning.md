# Dependency Provisioning

CreatorForge relies on several external tools and Python packages that are
**not bundled in the installer**. This document describes what each dependency
does, how the app locates it, and how to install it.

---

## Required by the native messaging host

### Python 3.10+

Used to run the native host (`creator_forge_host.py`) that relays messages
between the browser extension and the app over a local IPC socket.

**Install:** `python.org` MSI installer (Windows) or your system package manager.

The installer checks for Python at setup time. If absent, browser integration
is disabled until Python is installed and the native host re-registered:
```powershell
"$Env:ProgramFiles\CreatorForge\scripts\install_native_host.ps1" -ExtensionId "<id>"
```

---

## Required for video downloading

### yt-dlp

Used by the Downloads feature to download video/audio from supported sites.

**Install (Windows):**
```powershell
winget install yt-dlp.yt-dlp
# or
scoop install yt-dlp
# or
pip install yt-dlp
```

**Discovery order (Windows):** CreatorForge checks the following locations in
order and uses the first one that responds to `yt-dlp --version`:

1. `yt-dlp` (system PATH)
2. `C:\Program Files\CreatorForge\bin\yt-dlp.exe` (future bundled option)
3. `C:\Program Files\yt-dlp\yt-dlp.exe`
4. WinGet package directory (`%LOCALAPPDATA%\Microsoft\WinGet\Packages\...`)
5. Python Scripts for Python 3.10–3.13 (`%LOCALAPPDATA%\Programs\Python\...`)
6. pip user install (`%APPDATA%\Python\...`)
7. Scoop shims (`%USERPROFILE%\scoop\shims\yt-dlp.exe`)
8. Chocolatey (`C:\ProgramData\chocolatey\bin\yt-dlp.exe`)
9. `yt-dlp.exe` (PATH fallback)

---

## Required for audio processing

### FFmpeg + ffprobe

Used for audio extraction, format conversion, and media probing.
`ffprobe` is expected alongside `ffmpeg` (same directory).

**Install (Windows):**
```powershell
winget install Gyan.FFmpeg
# or
scoop install ffmpeg
# or
choco install ffmpeg
```

**Discovery order (Windows):** Similar to yt-dlp — checks known WinGet, Scoop,
and Chocolatey paths before falling back to `ffmpeg.exe` in PATH.

---

## Required for AI features

### Python packages (managed in app-owned venvs)

AI features (vocal separation, background removal) use Python workers that run
in **isolated virtual environments** created and managed by CreatorForge under
`%APPDATA%\creator_forge\venvs\`. These are separate from the user's global
Python environment and are never modified by the app.

**On first use of each AI feature**, the app:
1. Creates a venv at `%APPDATA%\creator_forge\venvs\<feature>\`
2. Installs the required packages (`demucs`, `rembg`, etc.) into that venv
3. Prompts the user and shows download progress (model weights can be several GB)

**Security constraint:** CreatorForge never installs or upgrades packages in the
user's global Python environment. All installs are scoped to the app-managed venv.

### AI model weights

Downloaded on first use from their respective upstream sources (Hugging Face,
etc.) and cached under `%APPDATA%\creator_forge\models\`. Subsequent uses are
fully offline.

---

## macOS paths

On macOS, discovery checks `/opt/homebrew/bin/`, `/usr/local/bin/`, and standard
`/usr/bin/` paths before the PATH fallback. Python framework paths
(`/Library/Frameworks/Python.framework/...`) are checked for yt-dlp only.

---

## Checking dependency status

Open **Settings → Dependencies** in the app to see which tools were found,
their versions, and what features each enables.
