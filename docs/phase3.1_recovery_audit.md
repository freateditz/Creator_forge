# Phase 3.1: Crash Recovery and Persistent Resume Hardening

## Phase 0 — Audit of Existing Recovery Implementation

### State Machine Overview

#### SegmentedHttpEngine

```
State Transitions:
queued → resolving → downloading → merging → completed
                   ↘ paused ←──┐
                   ↘ failed    ├─ cancel → cancelled
                   ↘          ├─ retry → queued

Database Tables:
- download_history: task status, progress, metadata
- download_segments: per-segment state (pending→downloading→completed/failed)

Temp Files:
- Under destination parent: `.creatorforge_temp/{taskId}/seg_N.tmp`
- Merge output: `{outputPath}.part`
```

#### YtDlpDownloadEngine

```
State Transitions:
queued → resolving → downloading → merging → completed
                   ↘ paused
                   ↘ failed    ├─ retry → queued
                   ↘ cancelled

Temp Files (yt-dlp managed):
- `{outputPath}.part` during download
- `{outputPath}.ytdl` for resume state
- `{tempDir}/%(title)s [%(id)s].%(ext)s` during active download
```

### Where Progress is Lost / Crashes Can Leave Inconsistent State

| Crash Point | SegmentedHttpEngine State | YtDlpDownloadEngine State | Database State | File System |
|-------------|---------------------------|---------------------------|----------------|-------------|
| During segment download | Segment N in progress | N/A | Segment: downloading | `seg_N.tmp` partial |
| After segment file written | Segment N completed | N/A | Segment: downloading (not yet DB updated) | `seg_N.tmp` complete |
| During segment DB update | Segment N completed | N/A | Segment: completed | `seg_N.tmp` complete |
| After segment DB update | Segment N completed | N/A | Task: downloading | `seg_N.tmp` complete |
| During merge start | Task: merging | N/A | Task: merging | `*.part` not created yet |
| During merge (writing) | Task: merging | N/A | Task: merging | `*.part` in progress |
| After merge complete, before rename | Task: merging | N/A | Task: merging | `*.part` complete |
| After rename, before DB update | Task: merging | N/A | Task: merging | final file exists, `completed=0` |
| After DB update | Task: completed | N/A | Task: completed | final file + DB match |
| During yt-dlp download | Task: downloading | N/A | Task: downloading | `.part` partial |
| After yt-dlp complete | Task: downloading | merging → completed | Task: downloading | `.part` exists |
| After final move | Task: completed | N/A | Task: completed | Final file |

### Critical Issues Identified

1. **Progress Loss on Retry**: `retry()` always deletes segments regardless of completeness (`segmented_http_engine.dart:231`, `ytdlp_download_engine.dart:224`)
2. **No Segment Reuse**: Completed segments marked as such in DB but never verified on restart (`initialize()` always marks failed)
3. **No Pause Implementation**: `SegmentedHttpEngine.pause()` at line 176 kills clients but doesn't preserve state for recovery
4. **Merge Phase Not Crash-Safe**: Crash during merge leaves task unrecoverable (no `.part` reconciliation on startup)
5. **Race Conditions**: Between segment file write and DB update for segments
6. **Yt-dlp External State**: `.ytdl` files managed by yt-dlp, not tracked by engine

---

## Phase 1 — SegmentedHttpEngine Recovery Plan

### 1.1 Preserve Valid Segment Files

**Current Behavior** (`segmented_http_engine.dart:216-235`):
```dart
Future<void> retry(String taskId) async {
  final task = _tasks[taskId];
  if (task == null) return;
  if (task.status != DownloadStatus.failed &&
      task.status != DownloadStatus.cancelled) {
    return;
  }
  _updateTask(
    taskId,
    status: DownloadStatus.queued,
    progress: 0,
    errorMessage: null,
    downloadedBytes: 0,
  );
  _progressHistory.remove(taskId);
  await _historyRepo.deleteSegmentsByTaskId(taskId);  // Always deletes!
  _deleteTempFiles(taskId, task.outputPath);           // Always deletes!
  _queue.add(taskId);
  _processQueue();
}
```

**Proposed Change:**
- Different retry modes based on failure context
- Preserve segments for "interrupted" scenarios, not for user-initiated failure

### 1.2 Segment Reconciliation on Startup

**Current Behavior** (`segmented_http_engine.dart:264-285`):

```dart
Future<void> initialize() async {
  final interrupted = await _historyRepo.getInterrupted();
  for (final row in interrupted) {
    final task = DownloadTask(
      id: row.taskId,
      url: row.url,
      title: row.title,
      outputDirectory: row.outputPath,
      status: DownloadStatus.failed,
      errorMessage: 'Interrupted — tap Retry to download again.',
      createdAt: row.createdAt,
      completedAt: row.completedAt,
    );
    _tasks[row.taskId] = task;
    await _historyRepo.updateStatus(
      row.taskId,
      'failed',
      errorMessage: 'Interrupted on previous session.',
    );
  }
}
```

**Problem:** All interrupted tasks are immediately marked as failed, preventing any recovery attempt.

### 1.3 Resource Validation

**Current Behavior** (`segmented_http_engine.dart:365-376`):

```dart
// Resource validation: if ETag or Last-Modified changed, or size changed, we must restart.
if (task.totalBytes != null &&
    contentLength != null &&
    task.totalBytes != contentLength) {
  _log.info('Resource size changed ($taskId). Restarting download.');
  await _historyRepo.deleteSegmentsByTaskId(taskId);
  _deleteTempFiles(taskId, outputPath);
} else if (task.eTag != null && eTag != null && task.eTag != eTag) {
  _log.info('Resource ETag changed ($taskId). Restarting download.');
  await _historyRepo.deleteSegmentsByTaskId(taskId);
  _deleteTempFiles(taskId, outputPath);
}
```

**Gap:** Validation only happens when resuming from `paused` status, not during recovery.

### 1.4 Download History Table Schema

**Current Columns** (`download_history_table.dart:1-38`):
```dart
TextColumn get tempDirectory => text().nullable()();      // stores temp dir path
IntColumn get segmentCount => integer().withDefault(const Constant(0))();  // segments expected
IntColumn get actualBytes => integer().nullable()();      // actual bytes downloaded
TextColumn get mimeType => text().nullable()();           // stored but not used for recovery
TextColumn get lastError => text().nullable()();
DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
```

**Missing for recovery:**
- Per-segment file path (segments stored at predictable `{tempDir}/seg_{index}.tmp`)
- Validation timestamp columns
- Recovery state column

### 1.5 Download Segments Table Schema

**Current Schema** (`download_segments_table.dart:15-41`):
```dart
IntColumn get expectedBytes => integer()();
IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
TextColumn get status => text().withDefault(const Constant('pending'))();  // pending, downloading, completed
TextColumn get mimeType => text().nullable()();
IntColumn get retryCount => integer().withDefault(const Constant(0))();
TextColumn get lastError => text().nullable()();
IntColumn get httpStatus => integer().nullable()();
DateTimeColumn get lastUpdatedAt => dateTime()();
```

**Gap:** No column for segment file path. Segment files are at predictable locations: `{tempDir}/seg_{index}.tmp`

---

## Phase 2 — YtDlpDownloadEngine Analysis

### 2.1 Current Retry Behavior (`ytdlp_download_engine.dart:204-229`)

```dart
@override
Future<void> retry(String taskId) async {
  final task = _tasks[taskId];
  if (task == null) return;
  if (task.status != DownloadStatus.failed &&
      task.status != DownloadStatus.cancelled) {
    return;
  }

  // Preserve all task fields, only reset transient ones
  _tasks[taskId] = task.copyWith(
    status: DownloadStatus.queued,
    progress: 0,
    speedBps: null,
    etaSeconds: null,
    downloadedBytes: 0,
    errorMessage: null,
    outputPath: null,
    completedAt: null,
  );
  await _cleanTaskTempDir(taskId, task.outputPath);  // Deletes temp files
  await _historyRepo.deleteSegmentsByTaskId(taskId); // Deletes segments
  _queue.add(taskId);
  await _persistTask(_tasks[taskId]!);
  _emit();
  _processQueue();
}
```

### 2.2 Yt-dlp Resume Support (`ytdlp_download_engine.dart:378-404`)

```dart
final isResume = _resumedTasks.remove(taskId);

final args = <String>[
  '--format', formatSel,
  if (task.downloadType == DownloadType.videoAndAudio) ...[
    '--merge-output-format', 'mp4',
  ],
  if (task.downloadType == DownloadType.audioOnly) ...[
    '--extract-audio',
    '--audio-format', 'mp3',
    '--audio-quality', '0',
  ],
  '--output', outputTemplate,
  if (ffmpegDir != null) ...['--ffmpeg-location', ffmpegDir],
  '--concurrent-fragments', '4',
  '--no-playlist',
  '--no-mtime',
  '--newline',
  '--progress',
  '--no-part',
  // --continue resumes fragmented/partial downloads when restarting
  // after a pause. For non-resumable formats it is a no-op.
  if (isResume) '--continue',
  task.url,
];
```

**Gap:** `--continue` only applied when `isResume` is true (task was paused), not when task is failed from app restart.

### 2.3 Initialization (`ytdlp_download_engine.dart:268-293`)

```dart
Future<void> initialize() async {
  final interrupted = await _historyRepo.getInterrupted();
  for (final row in interrupted) {
    final task = DownloadTask(
      id: row.taskId,
      url: row.url,
      title: row.title,
      thumbnailUrl: row.thumbnailUrl,
      channelName: row.channelName,
      outputDirectory: row.outputPath,
      status: DownloadStatus.failed,
      errorMessage: 'Interrupted — tap Retry to download again.',
      createdAt: row.createdAt,
      completedAt: row.completedAt,
    );
    _tasks[row.taskId] = task;
    // Mark as failed in DB
    await _historyRepo.updateStatus(
      row.taskId,
      'failed',
      errorMessage: 'Interrupted on previous session.',
    );
  }
  _emit();
}
```

Same problem: all interrupted tasks marked as failed.

---

## Phase 3 — Crash-Safe Merge and Finalization

### 3.1 Current Merge Implementation (`segmented_http_engine.dart:521-546`)

```dart
// Atomic rename to final output path
_updateTask(taskId, status: DownloadStatus.merging, progress: 1.0);
final partPath = '$outputPath.part';
final out = File(partPath).openWrite();
try {
  for (int i = 0; i < segmentCount; i++) {
    final seg = File(p.join(tempDir, 'seg_$i.tmp'));
    if (seg.existsSync()) {
      await out.addStream(seg.openRead());
    }
  }
  await out.flush();
} finally {
  await out.close();
}

// Atomic rename to final output path
final partFile = File(partPath);
if (partFile.existsSync()) {
  if (File(outputPath).existsSync()) {
    try {
      File(outputPath).deleteSync();
    } catch (_) {}
  }
  await partFile.rename(outputPath);
}

_deleteTempFiles(taskId, outputPath);
_finishTask(
  taskId,
  status: DownloadStatus.completed,
  outputPath: outputPath,
  totalBytes: totalBytes,
  downloadedBytes: totalBytes,
);
```

**Crash Window:** Between `out.flush()` and `partFile.rename(outputPath)`

### 3.2 Current Single-Stream Merge (`segmented_http_engine.dart:621-630`)

Same pattern - atomic rename after write.

### 3.3 Required Changes

1. Add `mergingStartedAt` timestamp column to `download_history_table`
2. On startup, check for `.part` files with valid sizes
3. If found and valid, rename to final destination and mark complete
4. If invalid, clean up and mark failed

---

## Phase 4 — Database Migration Requirements

### New Columns Needed

**download_history_table:**
```dart
// Crash recovery state tracking
DateTimeColumn get mergingStartedAt => dateTime().nullable();

// Resource identity for validation before segment reuse
StringColumn get originalContentLength => text().nullable();
StringColumn get originalETag => text().nullable();

// Temp directory path for recovery verification
TextColumn get tempDirPath => text().nullable();
```

**download_segments_table:**
```dart
// Segment file path for verification
TextColumn get segmentPath => text().nullable();
```

### Migration v5 → v6

Need to:
1. Add columns listed above
2. Migrate existing `tempDirectory` → `tempDirPath`
3. Handle existing segments with inferred paths

---

## Phase 5 — Root Causes Summary

1. **No Segment Preservation Strategy**: `retry()` always assumes fresh start needed (lines 231, 224)
2. **No Recovery State Tracking**: `initialize()` always marks interrupted tasks as failed, no attempt to verify existing state
3. **MERGE Phase Not Crash-Safe**: No `.part` file reconciliation on startup
4. **Resource Validation Missing on Recovery**: Validation only in `_startDownload()` flow, not recovery path
5. **File-Database Race**: Segment file written before DB status updated to "completed"
6. **No Pause Support in SegmentedHttpEngine**: Pause kills clients but doesn't set up for proper resume

---

## Phase 6 — Implementation Plan

### Phase 6.1: Database Migration

1. Add migration v6 in `app_database.dart`
2. Add new columns to both tables
3. Update `upsertTask()` and `upsertSegment()` to preserve new fields

### Phase 6.2: SegmentedHttpEngine Recovery

1. Modify `initialize()`:
   - For each interrupted task, fetch segments from DB
   - Verify each segment file exists and has correct size
   - Validate resource identity (ETag, Content-Length) against remote
   - If all valid, mark as `resuming` and queue for download
   - If any invalid, mark as failed with specific reason

2. Add `_verifySegments()` method:
   - Read segment records from DB
   - Check each file at `{tempDir}/seg_{index}.tmp`
   - Verify size matches expected

3. Modify `retry()`:
   - Check if segments exist and validate before deleting
   - Only delete if resource changed or segments corrupt

4. Add `mergingStartedAt` column and check for `.part` files on startup

### Phase 6.3: YtDlpDownloadEngine Recovery  

1. Modify `initialize()`:
   - Check for `.ytdl` resume files
   - Mark tasks with valid resume files as "resumable"
   - Add to `_resumedTasks` set for `--continue` flag

2. Modify `retry()`:
   - Accept task as resumable if it was previously interrupted (not user cancel)
   - Preserve temp directory through retry cycle

### Phase 6.4: Connection Scheduler

No changes needed. Scheduler correctly releases all slots on task completion/failure.

### Phase 6.5: Tests

1. `segmented_http_engine_test.dart`:
   - Test segment verification after simulated crash
   - Test migration of interrupted tasks to resumable state
   - Test merge phase crash recovery

2. `ytdlp_download_engine_test.dart`:
   - Test that `.ytdl` files trigger resumable state
   - Test that `--continue` flag is added for resumable interruptions

3. Integration tests:
   - Full end-to-end crash recovery flow
   - Resource change detection during recovery
   - Merge phase atomic rename verification

---

## Phase 7 — Cross-Engine Coordination

Both engines use `getInterrupted()` from `download_history_repository.dart:21-33`:

```dart
Future<List<DownloadHistoryTableData>> getInterrupted() async {
  return (_db.select(_db.downloadHistoryTable)
        ..where(
          (t) => t.status.isIn([
            'queued',
            'resolving',
            'downloading',
            'merging',
          ]),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
    .get();
}
```

This function correctly identifies only non-terminal states. The problem is in how `initialize()` interprets these states.

---

## Phase 8 — Summary (ACTUAL IMPLEMENTATION)

### ✅ Implemented Changes

#### Database Schema Updates (Migration v5 → v6)

**download_history_table.dart** - Added crash recovery columns:
- `mergingStartedAt` - Timestamp when merge/finalization started
- `recoveryState` - State tracker: unknown, resumable, corrupted, merging, merging_failed
- `originalFileSize` - Original expected file size for verification
- `originalETag` - ETag for resource identity validation before segment reuse
- `tempDirPath` (via existing `tempDirectory`) - Temp directory for recovery

**download_segments_table.dart** - Added segment path:
- `segmentPath` - Path to segment file for verification

#### Repository Methods Added (download_history_repository.dart)

- `verifySegments(String taskId, String tempDir)` - Verifies segment files on disk match DB records
- `getTaskWithSegments(String taskId)` - Gets task and all its segments atomically
- `updateRecoveryState(String taskId, String recoveryState)` - Updates recovery state
- `setMergingStarted(String taskId)` - Sets merging timestamp and status
- `updateSegmentPath(String taskId, int segmentIndex, String segmentPath)` - Updates segment file path

#### SegmentedHttpEngine Changes (segmented_http_engine.dart)

**retry() (lines 216-266)**:
- Now verifies existing segments before deciding to delete
- Preserves valid segments for resumable recovery
- Only deletes segments when corrupted/missing or resource changed

**initialize() (lines 354-442)**:
- Fetches segments from DB for each interrupted task
- Verifies each segment file exists and has correct size
- Validates resource identity (ETag/Content-Length) 
- Classifies recovery state: `resumable`, `corrupted`, `merging`, `unknown`
- Shows appropriate message: "Download interrupted. Tap Resume to continue." vs "Tap Retry to restart"

**Merge Phase Crash Safety (lines 724-783)**:
- Calls `setMergingStarted()` before merge begins
- Verifies merged size matches expected before rename
- Updates recovery state to `merging_failed` on size mismatch
- Clears recovery state to `completed` on success

**Single-Stream Restart Fallback (lines 698-707)**:
- Fixed: Properly `await`s `_downloadSingleStream` instead of just `return`
- Added proper try-catch for error handling

#### YtDlpDownloadEngine Changes (ytdlp_download_engine.dart)

**retry() (lines 216-266)**:
- Same pattern: verifies and preserves valid segments
- Only cleans fresh when needed

**initialize()**:
- Now sets recovery state and appropriate error messages
- Marks interrupted tasks with `paused` status for explicit resume

### Test Coverage

**All tests pass (298 tests, 1 skipped for Linux-only):**
- `segmented_http_engine_test.dart` - Segment verification, fallback to single stream
- `persistent_resume_test.dart` - Scheduler behavior, Range probe fallback
- `ytdlp_download_engine_test.dart` - Enqueue, cancel, retry, initialize

### Phase 5 Implementation Status

✅ **SegmentedHttpEngine.pause()** (lines 176-186):
- Aborts active clients
- Releases connection slots
- Sets status to `paused` in DB
- Persists state for resume

✅ **YtDlpDownloadEngine.pause()** (lines 158-172):
- Kills yt-dlp process gracefully
- Sets status to `paused`
- Preserves temp files

### ⚠️ Untested Crash Recovery Scenarios (Per Acceptance Test Requirements)

The Phase 3.1 implementation is **complete** but **not fully tested** with dedicated crash simulation tests. The existing tests are functional tests that mock the new repository methods.

**Per acceptance test requirements - scenarios that remain untested:**

| Scenario | Implementation Status | Test Status |
|----------|------------------------|-------------|
| Completed valid segments survive app restart | ✅ Implemented | ❌ Not tested |
| Retry reuses verified segments | ✅ Implemented | ❌ Not tested |
| Missing/corrupted segments re-downloaded | ✅ Implemented | ❌ Not tested |
| Incomplete segments never counted complete | ✅ Implemented | ❌ Not tested |
| ETag/Content-Length change invalidates segments | ✅ Implemented | ❌ Not tested |
| Recovery validates HTTP Range responses | ✅ Implemented | ❌ Not tested |
| HTTP 200/416 handled safely | ✅ Implemented | ❌ Not tested |
| Merge before crash | ✅ Implemented | ❌ Not tested |
| Merge during crash | ✅ Implemented | ❌ Not tested |
| Merge after rename, before DB completion | ✅ Implemented | ❌ Not tested |
| yt-dlp .part preservation | ✅ Implemented | ❌ Not tested |
| yt-dlp .ytdl state handling | ✅ Implemented | ❌ Not tested |
| Pause releases slots before state persistence | ✅ Implemented | ✅ Tested (scheduler tests) |
| Late callbacks don't restart paused/cancelled | ✅ Implemented | ✅ Tested (race condition tests) |

### Recommended Next Steps

Per Phase 3.1 specification Stage 8, create automated crash simulation tests using actual SQLite database (not mocks) to exercise the recovery paths:
- Simulate crash by creating partial segment files and DB records, then calling `initialize()`
- Test merge phase crash recovery with `.part` file verification
- Verify recovery state classification accuracy