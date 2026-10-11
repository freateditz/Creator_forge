# Browser Extension Setup

The CreatorForge browser extension detects downloadable media on any page and
sends it to the desktop app. All processing is local — no media is uploaded to
any server.

## What it does

- Detects `<video>` and `<audio>` elements on the current page using a
  `MutationObserver` and event listeners
- Identifies direct media URLs, HLS/DASH streams, and yt-dlp-compatible pages
- Displays detected candidates in the popup with type and source information
- Sends the selected candidate to CreatorForge via native messaging
- Shows download status from the desktop app

## Supported browsers

| Browser | Status |
|---------|--------|
| Chrome (MV3) | Supported |
| Microsoft Edge (MV3) | Supported |
| Brave | Compatible (same Chromium MV3 runtime) |
| Firefox | Not supported (different extension API) |
| Safari | Not supported |

## Security model

- No cookies, passwords, bearer tokens, or authentication headers are captured
- No browsing history is recorded or transmitted
- All communication is local (native messaging + Unix socket / TCP loopback)
- Localhost and private-IP download URLs are rejected by the desktop app
- DRM-protected streams are flagged as unsupported and cannot be downloaded

## Build the extension

```bash
cd browser-extension
npm ci
npm run build
```

Output is in `browser-extension/dist/`.

## Load as unpacked extension

1. Open Chrome or Edge and navigate to `chrome://extensions/`
2. Enable **Developer mode** (toggle in the top-right)
3. Click **Load unpacked**
4. Select the `browser-extension/dist/` directory
5. Note the **Extension ID** shown under the extension name

## Install the native messaging host

The native host bridges the extension to the desktop app.

### macOS

```bash
bash native-host/scripts/install_macos.sh <EXTENSION_ID>
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File native-host\scripts\install_windows.ps1 <EXTENSION_ID>
```

Replace `<EXTENSION_ID>` with the ID from `chrome://extensions/`.

## Getting the extension ID

1. Build and load the extension (steps above)
2. Open `chrome://extensions/`
3. Find **CreatorForge** in the list
4. Copy the ID shown below the extension name (32-character lowercase string)

## Re-registering after getting the ID

Re-run the install script with the ID as the argument. The existing manifest is
overwritten — no need to uninstall first.

## Uninstallation

```bash
# macOS
bash native-host/scripts/uninstall_macos.sh

# Windows
powershell -ExecutionPolicy Bypass -File native-host\scripts\uninstall_windows.ps1
```

## Limitations

- **Public media only** — the extension cannot download DRM-protected content
- **No authentication passthrough** — authenticated streams (requiring login cookies) are
  not supported and will not be added
- **MV3 service worker** — the background service worker is unloaded when idle; this is
  normal Chrome MV3 behaviour and does not indicate a bug
- **HLS/DASH streams** — the extension detects `.m3u8`/`.mpd` URLs but CreatorForge
  requires yt-dlp to be installed to download them
