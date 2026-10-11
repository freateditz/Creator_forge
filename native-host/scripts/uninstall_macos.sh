#!/usr/bin/env bash
# CreatorForge — Native Messaging Host Uninstaller (macOS)
#
# Reverses install_macos.sh for the current user.
# Does NOT touch CreatorForge app data or the IPC connection file.
# Safe to run multiple times (idempotent).
#
# Usage:
#   bash native-host/scripts/uninstall_macos.sh

set -euo pipefail

HOST_NAME="com.creatorforge.native_host"
INSTALL_DIR="$HOME/Library/Application Support/CreatorForge/NativeHost"

NM_DIRS=(
  "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
  "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
  "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
)

echo "CreatorForge Native Messaging Host Uninstaller (macOS)"
echo "======================================================="

removed_anything=false

# 1. Remove NM manifests from all browser directories.
for nm_dir in "${NM_DIRS[@]}"; do
  manifest="$nm_dir/$HOST_NAME.json"
  if [[ -f "$manifest" ]]; then
    rm "$manifest"
    echo "  Removed: $manifest"
    removed_anything=true
  fi
done

# 2. Remove the installation directory (host script + wrapper).
if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  echo "  Removed: $INSTALL_DIR"
  removed_anything=true
fi

if [[ "$removed_anything" == false ]]; then
  echo "  Nothing to remove — native host was not installed."
fi

echo ""
echo "Uninstall complete."
echo "Note: CreatorForge app data has not been modified."
