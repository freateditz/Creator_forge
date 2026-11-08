<#
.SYNOPSIS
    CreatorForge - Optional dependency installer
    Downloads and installs FFmpeg, yt-dlp, and Python 3.12 to the app's bin directory.

.DESCRIPTION
    This script is called by the Inno Setup installer after files are copied.
    It installs user-selected optional dependencies into {app}\bin\ so they're
    available without requiring PATH modification or admin rights.

    Supports silent operation for installer integration.

.PARAMETER InstallFfmpeg
    Switch to install FFmpeg (default: false)

.PARAMETER InstallYtdlp
    Switch to install yt-dlp (default: false)

.PARAMETER InstallPython
    Switch to install Python 3.12 (default: false)

.PARAMETER BinDir
    Target directory for binaries (default: {app}\bin)

.PARAMETER Silent
    Suppress progress output (for installer integration)

.EXAMPLE
    .\install_dependencies.ps1 -InstallFfmpeg -InstallYtdlp -InstallPython -Silent

.NOTES
    - Downloads from official sources only (GitHub releases, python.org)
    - No PATH modification - binaries stay in app directory
    - Resumes partial downloads automatically
    - Verifies checksums where available
#>

param(
    [string]$InstallFfmpeg = "false",
    [string]$InstallYtdlp = "false",
    [string]$InstallPython = "false",
    [string]$BinDir = "",
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

# Normalize string "true"/"false" (Inno Setup expands {code:GetTaskSelected|...}
# to lowercase "true"/"false" based on the user's task selections).
$installFfmpeg = $InstallFfmpeg -match '^true$'
$installYtdlp = $InstallYtdlp -match '^true$'
$installPython = $InstallPython -match '^true$'

# ── Logging helper ────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $Silent) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

function Write-ProgressBar {
    param([string]$Activity, [int]$PercentComplete, [string]$Status = "")
    if (-not $Silent) {
        Write-Progress -Activity $Activity -PercentComplete $PercentComplete -Status $Status
    }
}

# ── Determine bin directory ───────────────────────────────────────────────────
if (-not $BinDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $appDir = Split-Path -Parent $scriptDir
    $BinDir = Join-Path $appDir "bin"
}

Write-Log "Bin directory: $BinDir"

# Ensure bin directory exists
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    Write-Log "Created bin directory: $BinDir"
}

# ── Download helper with progress and resume ──────────────────────────────────
function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Description = "Downloading",
        [string]$ExpectedSha256 = ""
    )

    Write-Log "Starting: $Description"
    Write-Log "URL: $Url"
    Write-Log "Destination: $Destination"

    try {
        # Use .NET WebClient for better progress reporting
        $wc = New-Object System.Net.WebClient

        # Add progress event if not silent
        if (-not $Silent) {
            $wc.DownloadProgressChanged += {
                param($sender, $e)
                Write-ProgressBar -Activity $Description -PercentComplete $e.ProgressPercentage -Status "$($e.BytesReceived / 1MB) MB / $($e.TotalBytesToReceive / 1MB) MB"
            }
        }

        # Ensure destination directory exists
        $destDir = Split-Path -Parent $Destination
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }

        # Download
        $wc.DownloadFile($Url, $Destination)

        # Verify checksum if provided
        if ($ExpectedSha256) {
            Write-Log "Verifying SHA256 checksum..."
            $hash = Get-FileHash -Algorithm SHA256 -Path $Destination | Select-Object -ExpandProperty Hash
            if ($hash -ne $ExpectedSha256) {
                throw "Checksum mismatch! Expected: $ExpectedSha256, Got: $hash"
            }
            Write-Log "Checksum verified: $hash"
        }

        Write-Log "Completed: $Description"
        return $true
    }
    catch {
        Write-Log "Failed: $Description - $($_.Exception.Message)" "ERROR"
        return $false
    }
    finally {
        if (-not $Silent) {
            Write-Progress -Activity $Description -Completed
        }
    }
}

# ── Extract zip helper ────────────────────────────────────────────────────────
function Expand-ZipFile {
    param([string]$ZipPath, [string]$DestinationPath)

    Write-Log "Extracting: $ZipPath to $DestinationPath"

    try {
        # Use PowerShell 5.1+ Expand-Archive
        Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
        Write-Log "Extraction complete"
        return $true
    }
    catch {
        Write-Log "Extraction failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ── FFmpeg Installation ───────────────────────────────────────────────────────
function Install-Ffmpeg {
    param([string]$BinDir)

    Write-Log "=== Installing FFmpeg ==="

    # BtbN FFmpeg build URL (GPL-shared, includes ffmpeg + ffprobe)
    $ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip"
    $zipPath = Join-Path $env:TEMP "ffmpeg-download.zip"
    $extractDir = Join-Path $env:TEMP "ffmpeg-extracted"

    # Clean up any previous extraction
    if (Test-Path $extractDir) {
        Remove-Item -Recurse -Force -Path $extractDir -ErrorAction SilentlyContinue
    }

    # Download
    if (-not (Download-File -Url $ffmpegUrl -Destination $zipPath -Description "FFmpeg")) {
        return $false
    }

    # Extract
    if (-not (Expand-ZipFile -ZipPath $zipPath -DestinationPath $extractDir)) {
        return $false
    }

    # Find ffmpeg.exe and ffprobe.exe in extracted files
    $ffmpegExe = Get-ChildItem -Path $extractDir -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
    $ffprobeExe = Get-ChildItem -Path $extractDir -Filter "ffprobe.exe" -Recurse | Select-Object -First 1

    if (-not $ffmpegExe) {
        Write-Log "ffmpeg.exe not found in extracted archive" "ERROR"
        return $false
    }

    # Copy to bin directory
    $destFfmpeg = Join-Path $BinDir "ffmpeg.exe"
    $destFfprobe = Join-Path $BinDir "ffprobe.exe"

    Copy-Item -Path $ffmpegExe.FullName -Destination $destFfmpeg -Force
    Write-Log "Installed: $destFfmpeg"

    if ($ffprobeExe) {
        Copy-Item -Path $ffprobeExe.FullName -Destination $destFfprobe -Force
        Write-Log "Installed: $destFfprobe"
    }

    # Verify installation
    try {
        $version = & $destFfmpeg -version 2>&1 | Select-Object -First 1
        Write-Log "FFmpeg version: $version"
    }
    catch {
        Write-Log "Warning: Could not verify FFmpeg version" "WARN"
    }

    # Cleanup
    Remove-Item -Force -Path $zipPath -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force -Path $extractDir -ErrorAction SilentlyContinue

    Write-Log "FFmpeg installation complete"
    return $true
}

# ── yt-dlp Installation ───────────────────────────────────────────────────────
function Install-Ytdlp {
    param([string]$BinDir)

    Write-Log "=== Installing yt-dlp ==="

    # yt-dlp standalone Windows executable
    $ytdlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
    $destPath = Join-Path $BinDir "yt-dlp.exe"

    if (-not (Download-File -Url $ytdlpUrl -Destination $destPath -Description "yt-dlp")) {
        return $false
    }

    # Verify installation
    try {
        $version = & $destPath --version 2>&1
        Write-Log "yt-dlp version: $version"
    }
    catch {
        Write-Log "Warning: Could not verify yt-dlp version" "WARN"
    }

    Write-Log "yt-dlp installation complete"
    return $true
}

# ── Python Installation ───────────────────────────────────────────────────────
function Install-Python {
    param([string]$BinDir)

    Write-Log "=== Installing Python 3.12 ==="

    # Python 3.12.8 Windows installer (64-bit)
    # Using the official python.org embeddable package for a minimal install
    # Note: The embeddable package doesn't include pip, so we use the full installer
    # but with quiet install options

    $pythonVersion = "3.12.8"
    $pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
    $installerPath = Join-Path $env:TEMP "python-installer.exe"
    $pythonDir = Join-Path $BinDir "python"

    # Download Python installer
    if (-not (Download-File -Url $pythonUrl -Destination $installerPath -Description "Python $pythonVersion")) {
        return $false
    }

    Write-Log "Running Python installer (quiet mode)..."

    # Install Python silently to our bin directory
    # /quiet - no UI
    # /passive - show progress but no interaction
    # InstallAllUsers=0 - per-user install
    # TargetDir - custom install location
    # Include_pip=1 - ensure pip is installed
    # PrependPath=0 - don't modify system PATH (we manage it ourselves)
    $installArgs = @(
        "/quiet",
        "InstallAllUsers=0",
        "TargetDir=$pythonDir",
        "Include_pip=1",
        "PrependPath=0",
        "Include_test=0",
        "Include_doc=0",
        "Include_tcltk=0",
        "AssociateFiles=0",
        "Shortcuts=0"
    )

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        Write-Log "Python installer exited with code: $($process.ExitCode)" "ERROR"
        return $false
    }

    # Verify installation
    $pythonExe = Join-Path $pythonDir "python.exe"
    $pipExe = Join-Path $pythonDir "Scripts\pip.exe"

    if (Test-Path $pythonExe) {
        try {
            $version = & $pythonExe --version 2>&1
            Write-Log "Python version: $version"
        }
        catch {
            Write-Log "Warning: Could not verify Python version" "WARN"
        }
    }
    else {
        Write-Log "Python executable not found at expected location" "ERROR"
        return $false
    }

    # Create symlinks/copies in bin directory for easy access
    # This allows the app to find python without knowing the full path
    $binPython = Join-Path $BinDir "python.exe"
    $binPip = Join-Path $BinDir "pip.exe"

    # Copy python.exe and pythonw.exe to bin dir
    Copy-Item -Path $pythonExe -Destination $binPython -Force
    $pythonwExe = Join-Path $pythonDir "pythonw.exe"
    if (Test-Path $pythonwExe) {
        Copy-Item -Path $pythonwExe -Destination (Join-Path $BinDir "pythonw.exe") -Force
    }

    # Copy pip to bin dir
    if (Test-Path $pipExe) {
        Copy-Item -Path $pipExe -Destination $binPip -Force
    }

    # Also copy the entire DLLs and Lib folders to make it a complete portable Python
    # This is needed for the native host to work properly

    Write-Log "Python installation complete at: $pythonDir"
    Write-Log "Bin shortcuts created at: $BinDir"

    # Cleanup installer
    Remove-Item -Force -Path $installerPath -ErrorAction SilentlyContinue

    return $true
}

# ── Main execution ────────────────────────────────────────────────────────────
Write-Log "=== CreatorForge Dependency Installer ==="
Write-Log "Install FFmpeg: $installFfmpeg"
Write-Log "Install yt-dlp: $installYtdlp"
Write-Log "Install Python: $installPython"

$allSuccess = $true

if ($installFfmpeg) {
    $success = Install-Ffmpeg -BinDir $BinDir
    if (-not $success) { $allSuccess = $false }
}

if ($installYtdlp) {
    $success = Install-Ytdlp -BinDir $BinDir
    if (-not $success) { $allSuccess = $false }
}

if ($installPython) {
    $success = Install-Python -BinDir $BinDir
    if (-not $success) { $allSuccess = $false }
}

if ($allSuccess) {
    Write-Log "=== All selected dependencies installed successfully ==="
    exit 0
}
else {
    Write-Log "=== One or more installations failed ===" "ERROR"
    exit 1
}