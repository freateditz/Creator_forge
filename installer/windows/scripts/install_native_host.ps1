# CreatorForge — Native Messaging Host installer (called by Inno Setup)
#
# This is called by the Inno Setup [Run] entry immediately after installation.
# It locates the native-host executable (prefer the compiled .exe; fall back to
# the bat wrapper if Python is found) and writes the NM manifest + Chrome/Edge
# registry keys so the browser can find the host.
#
# USAGE
#   install_native_host.ps1 [-ExtensionId <id>] [-Validate] [-Unregister]
#
#   (no args)         — Install host files and register with a PLACEHOLDER origin.
#                       The placeholder prevents Chrome from crashing the host
#                       lookup.  The in-app wizard replaces it with the real ID.
#   -ExtensionId <id> — Register with the specific 32-char extension ID.
#   -Validate         — Print the installed manifest + registry values and exit.
#   -Unregister       — Remove Chrome + Edge registry keys (used by uninstaller).
#
# SECURITY
#   - Writes to HKCU only — no administrator rights required.
#   - never_origins is never empty; a placeholder is used when no real ID is
#     known so the host is discoverable but cannot be misused.
#   - Uses reg.exe /ve to set the unnamed default registry value (what Chrome reads).
#   - Reads back and verifies the registry value after writing.

param(
    [string]$ExtensionId  = "",
    [switch]$Validate,
    [switch]$Unregister
)

$ErrorActionPreference = "Stop"

$HostName    = "com.creatorforge.native_host"
$AppDir      = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$NHDir       = Join-Path $env:APPDATA "CreatorForge\NativeHost"
$ExePath     = Join-Path $AppDir "NativeHost\creator_forge_native_host.exe"
$ScriptDst   = Join-Path $NHDir "creator_forge_host.py"
$WrapperBat  = Join-Path $NHDir "creator_forge_host.bat"
$ManifestDst = Join-Path $NHDir "$HostName.json"

$Browsers = @(
    @{ Name = "Chrome"; Key = "HKCU\Software\Google\Chrome\NativeMessagingHosts\$HostName" },
    @{ Name = "Edge";   Key = "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\$HostName" }
)

# ── Validate mode ──────────────────────────────────────────────────────────────

if ($Validate) {
    foreach ($b in $Browsers) {
        Write-Host "=== $($b.Name) : $($b.Key) ==="
        $out = & reg query $b.Key /ve 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host $out
            $mpath = ($out | Select-String 'REG_SZ\s+(.+)$' -AllMatches).Matches[0]?.Groups[1]?.Value?.Trim()
            if ($mpath -and (Test-Path $mpath)) {
                Write-Host "Manifest contents:"
                Get-Content $mpath
            } else {
                Write-Host "  WARNING: Manifest not found at: $mpath"
            }
        } else {
            Write-Host "  Not registered."
        }
    }
    Write-Host ""
    Write-Host "Host executable (preferred): $ExePath  $(if (Test-Path $ExePath) { '[FOUND]' } else { '[NOT FOUND]' })"
    Write-Host "Host bat wrapper (fallback): $WrapperBat  $(if (Test-Path $WrapperBat) { '[FOUND]' } else { '[NOT FOUND]' })"
    exit 0
}

# ── Unregister mode ────────────────────────────────────────────────────────────

if ($Unregister) {
    foreach ($b in $Browsers) {
        & reg delete $b.Key /f 2>&1 | Out-Null
        Write-Host "Removed registry key: $($b.Key)"
    }
    exit 0
}

# ── Validate extension ID format (if provided) ────────────────────────────────

function Assert-ExtensionId {
    param([string]$Id)
    if ($Id.Length -ne 32) {
        throw "Extension ID must be exactly 32 characters (got $($Id.Length))."
    }
    if ($Id -notmatch '^[a-z]{32}$') {
        throw "Extension ID must contain only lowercase letters a-z (got '$Id')."
    }
}

if ($ExtensionId -ne "") {
    Assert-ExtensionId -Id $ExtensionId
}

# ── Determine host executable path ────────────────────────────────────────────

$HostExec = $null

# Prefer compiled exe shipped with the installer.
if (Test-Path $ExePath) {
    $HostExec = $ExePath
    Write-Host "Using compiled host: $HostExec"
} else {
    # Fall back: generate a bat wrapper using the user's Python.
    $python = $null
    foreach ($candidate in @("python", "python3", "py")) {
        try {
            $ver = & $candidate --version 2>&1
            if ($ver -match "Python 3") {
                $python = (Get-Command $candidate -ErrorAction SilentlyContinue)?.Source
                break
            }
        } catch {}
    }

    if ($python) {
        New-Item -ItemType Directory -Force -Path $NHDir | Out-Null
        @"
@echo off
"$python" "$ScriptDst" %*
"@ | Set-Content -Path $WrapperBat -Encoding ASCII
        $HostExec = $WrapperBat
        Write-Host "Using Python bat wrapper: $WrapperBat"
    } else {
        Write-Host "WARNING: Neither creator_forge_native_host.exe nor Python 3 was found."
        Write-Host "Browser extension integration will not be available until one is installed."
        Write-Host "The in-app Browser Integration wizard will guide you through setup."
        exit 0
    }
}

# ── Ensure NativeHost directory exists ────────────────────────────────────────

New-Item -ItemType Directory -Force -Path $NHDir | Out-Null

# ── Determine origin ──────────────────────────────────────────────────────────

# If no extension ID is supplied, use a placeholder origin so the manifest is
# syntactically valid and the host is discoverable.  The in-app wizard will
# call this script again (or use reg.exe directly) with the real ID.
$origin = if ($ExtensionId -ne "") {
    "chrome-extension://$ExtensionId/"
} else {
    "chrome-extension://creatorforge-placeholder-replace-me-aaa/"
}

# ── Write manifest ────────────────────────────────────────────────────────────

$manifest = [ordered]@{
    name            = $HostName
    description     = "CreatorForge Native Messaging Host"
    path            = $HostExec
    type            = "stdio"
    allowed_origins = @($origin)
}
$json = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($ManifestDst, $json, [System.Text.Encoding]::UTF8)
Write-Host "Manifest written: $ManifestDst"

# ── Register with Chrome + Edge using reg.exe /ve ─────────────────────────────
# /ve sets the unnamed default value — the value Chrome reads.
# /t REG_SZ — string type.
# /f — overwrite without prompting.

$anyFailed = $false
foreach ($b in $Browsers) {
    $exitCode = 0
    $output = & reg add $b.Key /ve /t REG_SZ /d $ManifestDst /f 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Write-Host "Registered $($b.Name): $($b.Key)"
    } else {
        Write-Host "WARNING: Failed to register $($b.Name): $output"
        $anyFailed = $true
    }
}

# ── Read-back verification ────────────────────────────────────────────────────

Write-Host ""
Write-Host "Verifying registration…"
$allOk = $true
foreach ($b in $Browsers) {
    $out = & reg query $b.Key /ve 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL  $($b.Name): registry key not found."
        $allOk = $false
        continue
    }
    $mpath = ($out | Select-String 'REG_SZ\s+(.+)' -AllMatches).Matches[0]?.Groups[1]?.Value?.Trim()
    if ($mpath -ne $ManifestDst) {
        Write-Host "  FAIL  $($b.Name): registry value mismatch. Expected: $ManifestDst  Got: $mpath"
        $allOk = $false
        continue
    }
    if (-not (Test-Path $ManifestDst)) {
        Write-Host "  FAIL  $($b.Name): manifest file not found at $ManifestDst"
        $allOk = $false
        continue
    }
    Write-Host "  OK    $($b.Name)"
}

if (-not $allOk -or $anyFailed) {
    Write-Host ""
    Write-Host "One or more verifications failed.  The in-app wizard will attempt"
    Write-Host "to repair the registration automatically."
    exit 1
}

Write-Host ""
if ($ExtensionId -ne "") {
    Write-Host "Native host registered for extension ID: $ExtensionId"
} else {
    Write-Host "Native host registered with placeholder origin."
    Write-Host "Open CreatorForge → Browser Integration to complete setup."
}
