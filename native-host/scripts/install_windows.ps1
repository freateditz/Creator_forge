# CreatorForge — Native Messaging Host Installer (Windows)
#
# USAGE
#   .\install_windows.ps1 <ExtensionId>          # full install + register
#   .\install_windows.ps1 -HostOnly               # install host files, skip manifest
#   .\install_windows.ps1 -Validate               # print installed manifest and exit
#
# EXTENSION_ID
#   The 32-character ID shown in chrome://extensions/ after loading the
#   extension in Developer mode.  Example:
#     .\install_windows.ps1 nkbihfbeogaeaoehlefnkodbefgpgknn
#
# TWO-PHASE DEVELOPMENT WORKFLOW
#   Phase 1:  .\install_windows.ps1 -HostOnly
#             (installs Python script + bat wrapper; no manifest written)
#   Phase 2:  .\install_windows.ps1 <ExtensionId>
#             (writes manifest with the correct allowed_origins)
#
# NOTES
#   - Registers in HKCU — no administrator rights required.
#   - Registers for Chrome and Edge.
#   - The manifest NEVER uses wildcard or empty allowed_origins.
#   - Running this script a second time with the same ID is safe (idempotent).

param(
    [Parameter(Position = 0)]
    [string]$ExtensionId = "",

    [switch]$HostOnly,
    [switch]$Validate
)

$ErrorActionPreference = "Stop"

$HostName    = "com.creatorforge.native_host"
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot    = (Resolve-Path (Join-Path $ScriptDir "../..")).Path
$HostSrc     = Join-Path $RepoRoot "native-host\creator_forge_host.py"
$Template    = Join-Path $RepoRoot "native-host\manifests\com.creatorforge.native_host.json"
$InstallDir  = Join-Path $env:APPDATA "CreatorForge\NativeHost"
$HostDst     = Join-Path $InstallDir "creator_forge_host.py"
$WrapperBat  = Join-Path $InstallDir "creator_forge_host.bat"
$ManifestDst = Join-Path $InstallDir "com.creatorforge.native_host.json"

# ── Validate mode ──────────────────────────────────────────────────────────────

if ($Validate) {
    foreach ($browser in @("Google\Chrome", "Microsoft\Edge")) {
        $key = "HKCU:\Software\$browser\NativeMessagingHosts\$HostName"
        if (Test-Path $key) {
            $path = (Get-ItemProperty -Path $key)."(Default)"
            Write-Host "=== $browser : $path ==="
            if (Test-Path $path) {
                Get-Content $path | ConvertFrom-Json | ConvertTo-Json -Depth 5
            } else {
                Write-Host "  Manifest file not found at: $path"
            }
        } else {
            Write-Host "Not registered: $browser"
        }
    }
    exit 0
}

# ── Validate extension ID format ───────────────────────────────────────────────

function Assert-ExtensionId {
    param([string]$Id)
    if ($Id.Length -ne 32) {
        Write-Error "Extension ID must be exactly 32 characters (got $($Id.Length))."
        exit 1
    }
    if ($Id -notmatch '^[a-z]+$') {
        Write-Error "Extension ID must contain only lowercase letters (got '$Id')."
        exit 1
    }
}

if (-not $ExtensionId -and -not $HostOnly) {
    Write-Host "ERROR: Extension ID required." -ForegroundColor Red
    Write-Host ""
    Write-Host "  .\install_windows.ps1 <ExtensionId>"
    Write-Host ""
    Write-Host "To install host files without registering a manifest (phase 1 of a"
    Write-Host "two-phase development setup), use -HostOnly:"
    Write-Host ""
    Write-Host "  .\install_windows.ps1 -HostOnly"
    exit 1
}

if ($ExtensionId) {
    Assert-ExtensionId -Id $ExtensionId
}

# ── Find Python 3 ─────────────────────────────────────────────────────────────

Write-Host "CreatorForge Native Messaging Host Installer (Windows)"
Write-Host "======================================================="

$python = $null
foreach ($candidate in @("python", "python3", "py")) {
    try {
        $ver = & $candidate --version 2>&1
        if ($ver -match "Python 3") {
            $python = (Get-Command $candidate).Source
            break
        }
    } catch {}
}
if (-not $python) {
    Write-Error "Python 3 not found.  Install from https://python.org and add it to PATH."
    exit 1
}
Write-Host "  Python: $python"

# ── Verify source files ───────────────────────────────────────────────────────

if (-not (Test-Path $HostSrc)) {
    Write-Error "Host script not found: $HostSrc"
    exit 1
}

# ── Install host files ────────────────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Copy-Item $HostSrc $HostDst -Force
Write-Host "  Installed: $HostDst"

# The .bat wrapper passes arguments through.  Python 3 uses sys.stdin.buffer /
# sys.stdout.buffer for binary I/O so no additional /B flag is needed.
@"
@echo off
"$python" "$HostDst" %*
"@ | Set-Content -Path $WrapperBat -Encoding ASCII
Write-Host "  Wrapper:   $WrapperBat"

# ── Host-only mode: stop here ─────────────────────────────────────────────────

if ($HostOnly) {
    Write-Host ""
    Write-Host "Host files installed.  No manifest has been written yet."
    Write-Host "NEXT: Load the extension in Chrome, copy the extension ID from"
    Write-Host "  chrome://extensions/, then re-run:"
    Write-Host ""
    Write-Host "  .\install_windows.ps1 <ExtensionId>"
    exit 0
}

# ── Build and register the NM manifest ───────────────────────────────────────

$origin = "chrome-extension://$ExtensionId/"
Write-Host "  Extension: $origin"

$manifest = Get-Content $Template -Raw | ConvertFrom-Json
$manifest.path = $WrapperBat
$manifest.allowed_origins = @($origin)

$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestDst -Encoding UTF8
Write-Host "  Manifest:  $ManifestDst"

foreach ($browser in @("Google\Chrome", "Microsoft\Edge")) {
    $key = "HKCU:\Software\$browser\NativeMessagingHosts\$HostName"
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name "(Default)" -Value $ManifestDst
    Write-Host "  Registry:  $key"
}

Write-Host ""
Write-Host "Installation complete."
Write-Host "NEXT: Reload the extension in chrome://extensions/ and test the connection."
Write-Host "  To verify: .\install_windows.ps1 -Validate"
