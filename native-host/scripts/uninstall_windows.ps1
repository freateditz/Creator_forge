# CreatorForge — Native Messaging Host Uninstaller (Windows)
#
# Reverses install_windows.ps1 for the current user.
# Does NOT touch CreatorForge app data outside the NativeHost directory.
# Safe to run multiple times (idempotent).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File uninstall_windows.ps1

$ErrorActionPreference = "Stop"

$HostName = "com.creatorforge.native_host"
$InstallDir = Join-Path $env:APPDATA "CreatorForge\NativeHost"

$RegistryPaths = @(
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HostName"
)

Write-Host "CreatorForge Native Messaging Host Uninstaller (Windows)"
Write-Host "==========================================================="

$removedAnything = $false

# 1. Remove HKCU registry keys.
foreach ($regPath in $RegistryPaths) {
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Force
        Write-Host "  Removed registry key: $regPath"
        $removedAnything = $true
    }
}

# 2. Remove the NativeHost installation directory.
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "  Removed directory: $InstallDir"
    $removedAnything = $true
}

if (-not $removedAnything) {
    Write-Host "  Nothing to remove — native host was not installed."
}

Write-Host ""
Write-Host "Uninstall complete."
Write-Host "Note: CreatorForge app data has not been modified."
