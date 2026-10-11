# CreatorForge

A professional creator toolkit for Windows and macOS. Download media, process audio, separate vocals, remove backgrounds, and send content directly from your browser — all running locally.

## Features

- **Download engine** — Video and audio downloads powered by yt-dlp with format selection and queue management
- **Audio tools** — FFmpeg-backed extraction, conversion, and batch processing
- **Vocal separator** — Local AI source separation (demucs/htdemucs) — no cloud upload
- **Background remover** — Local AI background removal (rembg/isnet) — no cloud upload
- **Browser extension** — Chromium MV3 extension (Chrome, Edge, Brave) with native messaging bridge

## Platform support

| Platform | Status |
|----------|--------|
| macOS (Apple Silicon / Intel) | Tested |
| Windows 10/11 x64 | Build verified via CI; runtime testing in progress |
| Linux | Not supported |

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.47.5+
- [Python](https://www.python.org/downloads/) 3.10+ (required for AI features)
- [FFmpeg](https://ffmpeg.org/download.html) (audio processing and extraction)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp#installation) (download engine)

## Quick start

```bash
git clone <repo-url>
cd creator_forge
flutter pub get
flutter run -d macos        # macOS
flutter run -d windows      # Windows
```

## Building

See [BUILD.md](BUILD.md) for full build and packaging instructions.

## Browser extension

See [BROWSER_EXTENSION.md](BROWSER_EXTENSION.md) for setup instructions including native host installation.

## Installation

See [INSTALLATION.md](INSTALLATION.md) for Windows installation and dependency setup.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Third-party notices

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for all dependency licenses.

> **Note:** The htdemucs model weights (vocal separator) are licensed CC BY-NC 4.0 — non-commercial use only.

## License

See LICENSE file. Third-party components retain their original licenses as documented in THIRD_PARTY_NOTICES.md.
