# CreatorForge — Native Messaging Host registration (called by the Inno Setup installer)
# This is NOT the same as native-host/scripts/install_windows.ps1 (which is for
# developer/source installs). This script is called post-install and assumes that
# creator_forge_host.py is already copied to %APPDATA%\CreatorForge\NativeHost\.
#
# When called by Inno Setup [Run] with no arguments:
#   - Finds Python and writes a bat wrapper so the host is executable.
#   - Does NOT write a manifest or touch the registry (no extension ID is known yet).
#   - The user must run this script again (or native-host\scripts\install_windows.ps1)
#     with their extension ID once the browser extension is loaded.
#
# When called manually with an extension ID:
#   install_native_host.ps1 abcdefghijklmnopabcdefghijklmnop
#   - Validates the ID, writes the manifest, and registers Chrome + Edge.
#
# Security: never writes allowed_origins with an empty or wildcard value.

param(
    [string]$ExtensionId = ""
)

$ErrorActionPreference = "Stop"
$HostName = "com.creatorforge.native_host"
$InstallDir = Join-Path $env:APPDATA "CreatorForge\NativeHost"
$HostScriptDst = Join-Path $InstallDir "creator_forge_host.py"
$WrapperBat = Join-Path $InstallDir "creator_forge_host.bat"
$ManifestDst = Join-Path $InstallDir "com.creatorforge.native_host.json"

function Assert-ExtensionId {
    param([string]$Id)
    if ($Id.Length -ne 32) {
        Write-Error "Extension ID must be exactly 32 characters (got $($Id.Length))."
        exit 1
    }
    if ($Id -notmatch '^[a-z]{32}$') {
        Write-Error "Extension ID must contain only lowercase letters a-z (got '$Id')."
        exit 1
    }
}

# ── Phase 1: create bat wrapper ───────────────────────────────────────────────
# This runs at install time (no ID known yet). It only creates the wrapper bat
# so the host is executable; it does NOT register Chrome or Edge.

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
    Write-Host "Python 3 not found. Browser extension integration will be unavailable."
    Write-Host "After installing Python, run:"
    Write-Host "  `"$PSCommandPath`" <ExtensionId>"
    exit 0
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
@"
@echo off
"$python" "$HostScriptDst" %*
"@ | Set-Content -Path $WrapperBat -Encoding ASCII

Write-Host "Native host wrapper created: $WrapperBat"

# ── Phase 2: register with extension ID ──────────────────────────────────────
# Only runs when an extension ID is provided (either directly by the user,
# or by the full install script in native-host/scripts/install_windows.ps1).

if ($ExtensionId -eq "") {
    Write-Host ""
    Write-Host "No extension ID provided — skipping manifest and registry registration."
    Write-Host "After loading the Chrome extension, run:"
    Write-Host "  `"$PSCommandPath`" <ExtensionId>"
    Write-Host ""
    Write-Host "Or use the full registration script:"
    Write-Host "  native-host\scripts\install_windows.ps1 <ExtensionId>"
    exit 0
}

Assert-ExtensionId -Id $ExtensionId

$origin = "chrome-extension://$ExtensionId/"

$manifest = @{
    name            = $HostName
    description     = "CreatorForge Native Messaging Host"
    path            = $WrapperBat
    type            = "stdio"
    allowed_origins = @($origin)
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestDst -Encoding UTF8

foreach ($browser in @("Google\Chrome", "Microsoft\Edge")) {
    $key = "HKCU:\Software\$browser\NativeMessagingHosts\$HostName"
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name "(Default)" -Value $ManifestDst
}

Write-Host "Registered native host for extension ID: $ExtensionId"
Write-Host "Manifest: $ManifestDst"
