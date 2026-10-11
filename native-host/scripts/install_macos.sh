#!/usr/bin/env bash
# CreatorForge — Native Messaging Host installer (macOS)
#
# USAGE
#   bash install_macos.sh <EXTENSION_ID>          # full install + register
#   bash install_macos.sh --host-only              # install host files, skip manifest
#   bash install_macos.sh --validate               # print installed manifest and exit
#
# EXTENSION_ID
#   The 32-character ID shown in chrome://extensions/ after loading the
#   extension in Developer mode.  Example:
#     bash install_macos.sh nkbihfbeogaeaoehlefnkodbefgpgknn
#
# TWO-PHASE DEVELOPMENT WORKFLOW
#   Phase 1:  bash install_macos.sh --host-only
#             (installs Python script + wrapper; no manifest written yet)
#   Phase 2:  bash install_macos.sh <EXTENSION_ID>
#             (writes manifest with the correct allowed_origins)
#
# RELEASE WORKFLOW
#   Pass the CRX extension ID as the first argument.  The ID is known before
#   packaging because it is derived from the extension's signing key.
#
# NOTES
#   - Installs for the current user only; no system directories are modified.
#   - Registers for Chrome and Edge.  Brave is registered when its directory
#     already exists (indicating the user has Brave installed).
#   - The manifest NEVER uses wildcard or empty allowed_origins.
#   - Running this script a second time with the same ID is safe (idempotent).

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOST_SCRIPT_SRC="$REPO_ROOT/native-host/creator_forge_host.py"
MANIFEST_TEMPLATE="$REPO_ROOT/native-host/manifests/com.creatorforge.native_host.json"

HOST_NAME="com.creatorforge.native_host"
NM_HOST_DIR="$HOME/Library/Application Support/CreatorForge/NativeHost"
HOST_SCRIPT_DST="$NM_HOST_DIR/creator_forge_host.py"
WRAPPER_SCRIPT="$NM_HOST_DIR/creator_forge_host"

# ── Argument parsing ──────────────────────────────────────────────────────────

EXTENSION_ID=""
HOST_ONLY=false
VALIDATE=false

for arg in "$@"; do
  case "$arg" in
    --host-only) HOST_ONLY=true ;;
    --validate)  VALIDATE=true  ;;
    -*)
      echo "Unknown option: $arg" >&2
      echo "Usage: bash install_macos.sh [--host-only | --validate | <EXTENSION_ID>]" >&2
      exit 1
      ;;
    *)
      if [[ -n "$EXTENSION_ID" ]]; then
        echo "ERROR: Unexpected argument '$arg' (extension ID already set)." >&2
        exit 1
      fi
      EXTENSION_ID="$arg"
      ;;
  esac
done

# ── Validate mode ─────────────────────────────────────────────────────────────

if [[ "$VALIDATE" == true ]]; then
  for browser_nm_dir in \
      "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts" \
      "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"; do
    manifest="$browser_nm_dir/$HOST_NAME.json"
    if [[ -f "$manifest" ]]; then
      echo "=== $manifest ==="
      python3 -c "import json,sys; d=json.load(open('$manifest')); print(json.dumps(d,indent=2))"
    else
      echo "Not installed: $manifest"
    fi
  done
  exit 0
fi

# ── Validate extension ID format ──────────────────────────────────────────────
# Chrome extension IDs are 32 lowercase characters (letters a-p, the base-16
# encoding used by Chrome).  Accept a-z to handle any encoding variant.

_validate_id() {
  local id="$1"
  if [[ ${#id} -ne 32 ]]; then
    echo "ERROR: Extension ID must be exactly 32 characters (got ${#id})." >&2
    return 1
  fi
  if ! [[ "$id" =~ ^[a-z]+$ ]]; then
    echo "ERROR: Extension ID must contain only lowercase letters (got '$id')." >&2
    return 1
  fi
}

if [[ -z "$EXTENSION_ID" && "$HOST_ONLY" == false ]]; then
  echo "ERROR: Extension ID required." >&2
  echo "" >&2
  echo "  bash install_macos.sh <EXTENSION_ID>" >&2
  echo "" >&2
  echo "To install host files without registering a manifest (phase 1 of a" >&2
  echo "two-phase development setup), use --host-only:" >&2
  echo "" >&2
  echo "  bash install_macos.sh --host-only" >&2
  exit 1
fi

if [[ -n "$EXTENSION_ID" ]]; then
  _validate_id "$EXTENSION_ID"
fi

# ── Verify prerequisites ──────────────────────────────────────────────────────

echo "CreatorForge Native Messaging Host Installer (macOS)"
echo "======================================================"

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found.  Install Python 3.7+ from https://python.org" >&2
  exit 1
fi
PYTHON="$(command -v python3)"
echo "  Python:    $PYTHON ($($PYTHON --version 2>&1))"

if [[ ! -f "$HOST_SCRIPT_SRC" ]]; then
  echo "ERROR: Host script not found: $HOST_SCRIPT_SRC" >&2
  exit 1
fi

# ── Install host files ────────────────────────────────────────────────────────

mkdir -p "$NM_HOST_DIR"

cp "$HOST_SCRIPT_SRC" "$HOST_SCRIPT_DST"
echo "  Installed: $HOST_SCRIPT_DST"

cat > "$WRAPPER_SCRIPT" << WRAPPER
#!/usr/bin/env bash
exec "$PYTHON" "$HOST_SCRIPT_DST" "\$@"
WRAPPER
chmod +x "$WRAPPER_SCRIPT"
echo "  Wrapper:   $WRAPPER_SCRIPT"

# ── Host-only mode: stop here ─────────────────────────────────────────────────

if [[ "$HOST_ONLY" == true ]]; then
  echo ""
  echo "Host files installed.  No manifest has been written yet."
  echo "NEXT: Load the extension in Chrome, copy the extension ID from"
  echo "  chrome://extensions/, then re-run:"
  echo ""
  echo "    bash install_macos.sh <EXTENSION_ID>"
  exit 0
fi

# ── Build and register the NM manifest ───────────────────────────────────────

ORIGIN="chrome-extension://$EXTENSION_ID/"
echo "  Extension: $ORIGIN"

MANIFEST_JSON="$(python3 - <<EOF
import json, sys

with open("$MANIFEST_TEMPLATE") as f:
    data = json.load(f)

data["path"] = "$WRAPPER_SCRIPT"
data["allowed_origins"] = ["$ORIGIN"]
print(json.dumps(data, indent=2))
EOF
)"

_register_browser() {
  local nm_dir="$1"
  local browser_label="$2"
  mkdir -p "$nm_dir"
  echo "$MANIFEST_JSON" > "$nm_dir/$HOST_NAME.json"
  echo "  $browser_label $nm_dir/$HOST_NAME.json"
}

_register_browser \
  "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts" \
  "Chrome:  "

_register_browser \
  "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts" \
  "Edge:    "

BRAVE_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
if [[ -d "$(dirname "$BRAVE_DIR")" ]]; then
  _register_browser "$BRAVE_DIR" "Brave:   "
fi

echo ""
echo "Installation complete."
echo "NEXT: Reload the extension in chrome://extensions/ and test the connection."
echo "  To verify: bash install_macos.sh --validate"
