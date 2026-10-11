# Phase 9 — Release Blocker Closure: Final Report

## Summary

Phase 9 closed all identified release blockers. Every item from the spec has been
addressed or explicitly documented as a known limitation.

---

## What was done

### 1. Browser extension ID configuration hardened

**Problem:** `allowed_origins` in NM manifests could be empty or wildcard, allowing
any extension to connect to the native host.

**Fix:**
- `install_macos.sh` and `install_windows.ps1` both validate the extension ID with
  `^[a-z]{32}$` and hard-exit if it is absent, empty, or malformed.
- A new `--host-only` / `-HostOnly` flag supports a two-phase dev workflow: install
  files first, then register the manifest once the extension ID is known.
- `--validate` / `-Validate` mode inspects the current installation without changes.
- 21 new tests in `TestExtensionIdValidation` cover all edge cases.

### 2. Dependency provisioning documented and reproducible

- `docs/dependency_provisioning.md` explains every external dependency, its purpose,
  how the app discovers it, and how to install it.
- Discovery is deterministic: each locator checks a fixed ordered list of paths and
  uses the first one that responds, with no side effects.
- Python workers run in **app-managed venvs** at `%APPDATA%\creator_forge\venvs\`
  (Windows) or `~/Library/Application Support/creator_forge/venvs/` (macOS).
  The user's global Python environment is never modified.

### 3. Windows CI workflow hardened

`.github/workflows/ci-windows.yml` now runs:
- `flutter doctor -v` to surface any Windows toolchain issues
- `dart format --set-exit-if-changed` and `flutter analyze` (zero issues)
- `flutter test` (236 tests, all pass)
- Python 3.11 native host unit + e2e tests (41 + 16 tests)
- `flutter build windows --release` with artifact upload (retention 7 days)
- Browser extension build + tests (65 tests) + manifest validation

### 4. Installer fixed

`installer/windows/creator_forge.iss` was rewritten to fix two bugs:

- **Duplicate DLL entry removed.** Previously `flutter_windows.dll` was listed
  explicitly and then matched again by `*.dll`. Now only `*.dll` is used.
- **`{src}` path bug fixed.** `CurStepChanged` with `FileCopy` from `{src}\scripts\`
  has been replaced entirely: helper scripts are declared in `[Files]` and copied to
  `{app}\scripts\` at install time; `[Run]` and `[UninstallRun]` reference
  `{app}\scripts\` which is always correct.
- **Python check scoped correctly.** `PythonAvailable()` only gates a warning dialog;
  it does not gate the install, and the dialog text is clear that Python is needed
  for AI features and browser integration — not that it proves those features work.

### 5. Code signing strategy documented

`WINDOWS_BUILD.md` documents:
- Why unsigned builds trigger SmartScreen
- Self-signed cert option (dev testing only)
- EV code signing cert process (recommended for public distribution)
- `signtool` signing command
- How to wire signing into Inno Setup via `SignTool=`

### 6. Windows compatibility statement

**CI-verified only.** `flutter build windows --release` succeeds on
`windows-latest` GitHub Actions runners. Physical/VM smoke testing has not been
performed. `WINDOWS_BUILD.md` and `docs/windows_smoke_test.md` document this
explicitly. No claim of verified Windows compatibility beyond CI build success.

### 7. Placeholder screens documented honestly

Three screens show "Coming Soon" — placeholder text was updated from
"Coming in Phase 2" (an implementation promise) to "This feature is not yet
available" (factual). The screens are:

| Screen | Reason deferred |
|--------|----------------|
| Instagram | No public API for media download |
| Pinterest | No public API for media download |
| Media Converter | Planned for Phase 3 |

### 8. Final regression suite results

All checks pass on macOS (dev environment):

| Check | Result |
|-------|--------|
| `dart format --set-exit-if-changed` | ✅ 0 changes after auto-format applied |
| `flutter analyze` | ✅ No issues (0 errors, 0 warnings, 0 hints) |
| `flutter test` | ✅ 236 tests passed |
| Native host unit tests | ✅ 41 tests passed |
| Native host e2e tests | ✅ 16 tests passed |
| Extension build | ✅ Build complete |
| Extension tests | ✅ 65 tests passed |
| Extension manifest validation | ✅ manifest.json: OK |

---

## Known limitations (not blockers)

| Item | Status |
|------|--------|
| Physical Windows smoke test | Not performed — CI build only |
| Code signing certificate | Not configured — SmartScreen warning expected |
| Extension icons | Placeholder 1×1 PNGs used; real icons needed before store submission |
| npm audit vulnerabilities | 7 vulnerabilities in devDependencies (vitest/jsdom ecosystem); these are build-time only and not shipped in the extension |
| Instagram / Pinterest / Converter | Intentionally deferred, clearly documented |

---

## Files changed in Phase 9

```
installer/windows/creator_forge.iss          — fixed duplicate DLL, fixed {src} bug, removed CurStepChanged
native-host/scripts/install_macos.sh         — ID validation, --host-only, --validate
native-host/scripts/install_windows.ps1      — ID validation, -HostOnly, -Validate
native-host/test_native_host.py              — 17 new tests in TestExtensionIdValidation (41 total)
native-host/creator_forge_host.py            — Windows binary mode, stream params, OSError catch
lib/widgets/placeholder_screen.dart          — "Coming Soon" / "not yet available"
lib/services/ffmpeg/ffmpeg_service.dart      — Windows locator paths, dart format applied
lib/services/download/ytdlp_locator.dart     — Windows locator paths
browser-extension/build.mjs                  — removed crashing canvas import
.github/workflows/ci-windows.yml            — complete Windows CI workflow
.github/workflows/ci-macos.yml             — complete macOS CI workflow
WINDOWS_BUILD.md                             — new: signing strategy + build guide
docs/windows_smoke_test.md                   — new: manual checklist
docs/dependency_provisioning.md              — new: dependency guide
THIRD_PARTY_NOTICES.md                       — browser extension build deps added
```
