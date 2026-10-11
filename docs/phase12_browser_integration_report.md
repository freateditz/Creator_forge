# Phase 12 — Browser Integration: Final Verification Report

Date: 2026-10-11  
Commits: `48192d3`, `7f16708`

---

## Summary

This report covers the 12-phase browser extension / native messaging repair
and wizard spec that was submitted to fix the error:

> `Unchecked runtime.lastError: Specified native messaging host not found.`

---

## Root Causes Identified (Phase 1)

| # | Root cause | Severity |
|---|-----------|---------|
| 1 | `install_native_host.ps1` ran with no extension ID → skipped registry write entirely | **Critical** |
| 2 | Manifest's `path` pointed to a `.bat` file; Chrome may not reliably launch batch files as binary-stdio NM hosts | High |
| 3 | `Set-ItemProperty -Name "(Default)"` created a named value instead of the unnamed default that Chrome reads | High |
| 4 | No in-app UX: users were expected to run PowerShell scripts manually with no guidance | Medium |

---

## Work Completed

### Phase 1 — Audit
- Traced the exact failure path through `install_native_host.ps1`, the
  registry key layout, and the Chrome NM host-lookup sequence.

### Phase 2 — Fix "host not found"
- `NativeHostService` (`lib/services/browser_extension/native_host_service.dart`):
  detects Chrome / Edge / Brave via `HKLM\SOFTWARE\Microsoft\Windows\
  CurrentVersion\App Paths\<browser>.exe`, writes the NM manifest to
  `%APPDATA%\CreatorForge\NativeHost\`, and registers HKCU keys using
  `reg.exe /ve` (unnamed default — what Chrome reads).
- Post-write read-back verification confirms the value before returning success.

### Phase 3 — Bundle files in installer
- `creator_forge.iss` bundles `browser-extension/dist/*` to
  `{app}\browser-extension\dist\` and the PyInstaller-built
  `creator_forge_native_host.exe` to `{app}\NativeHost\`.

### Phase 4 — Unpacked dev mode
- `BrowserDownloadsScreen` wizard guides the user through Load Unpacked:
  opens Chrome Extensions page, opens the `{app}\browser-extension\dist\`
  folder in Explorer, and collects the resulting extension ID via a
  3-step inline dialog.

### Phase 5 — In-app wizard
- `BrowserDownloadsScreen` rewritten with a full state-machine wizard.
- `BrowserSetupStage`: `initial → detecting → idle/noBrowserFound →
  registering → waitingForConnection → connected / error`.
- Browser tiles with install-status indicators; inline diagnostics chips.

### Phase 6 — Real handshake via ping stream
- `IpcServer` now exposes `Stream<DateTime> pingStream`.  It emits each
  time the native host relays a `browser_ping` message from the extension.
- `waitForConnection()` calls `pingStream.first.timeout(45s)` and only
  advances to `connected` after a real PING is received end-to-end.
- Ongoing ping subscription keeps the `Connected` badge live.

### Phase 7 — Repair flow
- `repair()` re-diagnoses the current browser, extracts any previously
  registered extension ID from `allowed_origins`, and re-runs
  `submitExtensionId()` automatically if valid.
- Error card shows a **Repair** button.

### Phase 8 — Startup health check
- `AppShell` converted to `ConsumerStatefulWidget`.
- `initState` schedules `browserIntegrationProvider.notifier.initialize()`
  via `addPostFrameCallback` — runs once after the first frame, never
  blocking the UI.  `initialize()` is idempotent.

### Phase 9 — Installer + CI update
- `install_native_host.ps1` rewritten: `reg.exe /ve`, prefers exe,
  falls back to bat+Python, `-Validate` / `-Unregister` modes.
- `.github/workflows/ci-windows.yml`: adds `pip install pyinstaller`,
  `pyinstaller build_windows.spec`, copy-exe-to-release-tree, and
  verifies `NativeHost\creator_forge_native_host.exe` exists.

### Phase 10 — Automated tests
- `test/services/native_host_service_test.dart`: 20 tests covering
  `validateExtensionId`, `NativeHostDiagnostics` (`isHealthy`,
  `containsOrigin`, `toTextReport`), `kNativeHostName` constant, and
  platform-guarded service behaviour on macOS.

### Phase 11 — Manual end-to-end verification
- **Not performed** — requires a Windows 10/11 machine with Chrome or
  Edge installed.  No Windows environment was available during
  implementation.

### Phase 12 — Final report
- This document.

---

## Metrics

| Metric | Value |
|--------|-------|
| `flutter analyze` issues | **0** |
| `flutter test` | **279 / 279 passed** |
| New files | 4 |
| Modified files | 7 |
| New tests | 20 |
| Windows end-to-end verified | **No** |

---

## Known Limitations / Not Implemented

| Item | Status |
|------|--------|
| Stable extension `key` field in `manifest.json` | Not added — extension ID changes each time the extension is loaded from a different path. The wizard handles this by collecting the ID interactively. |
| Brave browser support in installer | `NativeHostService` registers Brave; `install_native_host.ps1` registers Chrome + Edge only. Brave users must complete setup via the in-app wizard. |
| Windows end-to-end test | Requires a real Windows machine. Not verified. |
| macOS / Linux NM registration | Out of scope per spec; existing manual instructions preserved in the macOS branch of the wizard screen. |

---

## What the user must do after installing

1. Open CreatorForge → **Browser Integration** (sidebar or Quick Actions).
2. The wizard detects Chrome / Edge automatically.
3. Click **Open Extensions Page**, then **Open Extension Folder**.
4. Load the extension unpacked from the opened folder.
5. Copy the extension ID that Chrome shows, paste it into the dialog.
6. Click **Register** — the app writes the manifest and registry key.
7. Reload the extension if prompted; the wizard polls for a PING and
   shows **Connected** when the end-to-end handshake succeeds.
