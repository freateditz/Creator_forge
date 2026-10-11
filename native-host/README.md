# CreatorForge Native Messaging Host

This directory contains the native messaging host that bridges the browser extension and the CreatorForge desktop application.

## Architecture

```
Chrome/Edge Extension
        ↓
  Chromium Native Messaging (4-byte length-prefix protocol)
        ↓
  creator_forge_host.py  (this host)
        ↓
  NDJSON over Unix socket (macOS) or TCP loopback (Windows)
        ↓
  CreatorForge Flutter Desktop App
```

## Requirements

- Python 3.7+ (uses only stdlib: `json`, `socket`, `struct`, `sys`, `os`)
- CreatorForge running (the host connects to its IPC socket at startup)

## Installation

### macOS / Linux

```bash
# Install for all supported browsers (current user):
bash native-host/scripts/install_macos.sh

# Install with extension ID (required for the extension to connect):
bash native-host/scripts/install_macos.sh abcdefghijklmnopabcdefghijklmnop
```

**What it does:**
- Copies `creator_forge_host.py` to `~/Library/Application Support/CreatorForge/NativeHost/`
- Creates a shell wrapper at the same location
- Writes the NM manifest to:
  - Chrome: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
  - Edge:   `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/`
  - Brave:  `~/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/`

### Windows

```powershell
# Install (no extension ID yet):
powershell -ExecutionPolicy Bypass -File native-host\scripts\install_windows.ps1

# Install with extension ID:
powershell -ExecutionPolicy Bypass -File native-host\scripts\install_windows.ps1 abcdefghijklmnopabcdefghijklmnop
```

**What it does:**
- Copies `creator_forge_host.py` and creates a `.bat` wrapper
- Writes the NM manifest to `%APPDATA%\CreatorForge\NativeHost\`
- Registers the manifest path in HKCU for Chrome and Edge (no admin required)

## Getting the Extension ID

1. Build the extension: `cd browser-extension && npm run build`
2. Open Chrome → `chrome://extensions/`
3. Enable **Developer mode** (top-right toggle)
4. Click **Load unpacked** → select `browser-extension/dist/`
5. Copy the extension ID (e.g., `abcdefghijklmnopabcdefghijklmnop`)
6. Re-run the install script with that ID

## IPC Connection File

When CreatorForge starts, it writes an IPC connection descriptor to:

| Platform | Path |
|----------|------|
| macOS    | `~/Library/Application Support/creator_forge/ipc/creator_forge.conn` |
| Windows  | `%APPDATA%\creator_forge\ipc\creator_forge.conn` |

**macOS example:**
```json
{"version": 1, "socket": "/Users/alice/Library/Application Support/creator_forge/ipc/creator_forge.sock"}
```

**Windows example (TCP with session token):**
```json
{"version": 1, "host": "127.0.0.1", "port": 52341, "token": "a1b2c3d4e5f6..."}
```

The host reads this file at startup to locate the running application. If the file is absent, all browser messages receive an `APP_NOT_RUNNING` error response.

## Running Tests

```bash
python3 native-host/test_native_host.py
# or
python3 -m pytest native-host/test_native_host.py -v
```

## Protocol

All messages between the host and Flutter use newline-delimited JSON (NDJSON). Each message is a complete JSON object on one line, followed by `\n`.

### Example exchange

Extension → Host (Native Messaging frame):
```json
{"version": 1, "type": "DOWNLOAD_REQUEST", "requestId": "req-1", "url": "https://example.com/video.mp4", "pageUrl": "https://example.com", "pageTitle": "Example", "downloadType": "videoAndAudio"}
```

Host → Flutter (via Unix socket):
```
{"version":1,"type":"DOWNLOAD_REQUEST","requestId":"req-1","url":"https://example.com/video.mp4",...}\n
```

Flutter → Host (via Unix socket):
```
{"version":1,"type":"DOWNLOAD_ACCEPTED","requestId":"req-1","taskId":"uuid-..."}\n
```

Host → Extension (Native Messaging frame):
```json
{"version": 1, "type": "DOWNLOAD_ACCEPTED", "requestId": "req-1", "taskId": "uuid-..."}
```

## Security

- The host never constructs shell commands from message content.
- All URL validation happens inside CreatorForge, not in this host.
- Localhost/private-IP URLs are rejected by CreatorForge.
- The host does not log message contents (only type/status).
- On TCP connections, CreatorForge issues a per-session token that the host must present.
- The NM manifest `allowed_origins` must list the exact extension ID — no wildcards.

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| "CreatorForge not running" in popup | CreatorForge is not open. Start it first. |
| "CreatorForge not connected" badge | Extension ID in manifest doesn't match loaded extension. |
| Host not found error in Chrome | Install script not run, or Python not found. |
| Token rejected (TCP) | Old `.conn` file from previous session. Restart CreatorForge. |
| Extension keeps reconnecting | `creator_forge.conn` not writable; check directory permissions. |

For verbose host logs: `python3 creator_forge_host.py 2>host.log` (for manual testing only).
