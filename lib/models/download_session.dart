import 'package:equatable/equatable.dart';

import 'download_task.dart';

/// Lifecycle state of a single byte-range segment.
///
/// The ordering matters: a segment must pass through PENDING → DOWNLOADING →
/// COMPLETED, and a crash between file-writing and database persistence must
/// never leave a falsely-COMPLETED segment behind.
enum SegmentState { pending, downloading, completed, failed }

/// A single byte-range segment of a resumable download.
///
/// [expectedBytes] is the byte range length declared at split time
/// ([endOffset] - [startOffset] + 1). [actualBytes] is the number of bytes
/// actually written to the segment file and validated. A segment is only
/// COMPLETED when [actualBytes] == [expectedBytes] and the file has been
/// flushed and closed.
class DownloadSegment extends Equatable {
  final int index;
  final int startOffset;
  final int endOffset;
  final int expectedBytes;
  final int actualBytes;
  final SegmentState state;
  final String? mimeType;
  final int retryCount;
  final String? lastError;
  final int? httpStatus;
  final DateTime lastUpdatedAt;

  const DownloadSegment({
    required this.index,
    required this.startOffset,
    required this.endOffset,
    required this.expectedBytes,
    this.actualBytes = 0,
    this.state = SegmentState.pending,
    this.mimeType,
    this.retryCount = 0,
    this.lastError,
    this.httpStatus,
    required this.lastUpdatedAt,
  });

  int get length => endOffset - startOffset + 1;

  bool get isComplete => state == SegmentState.completed;
  bool get isFailed => state == SegmentState.failed;
  bool get isPending => state == SegmentState.pending;
  bool get isDownloading => state == SegmentState.downloading;

  /// True when the on-disk segment file is trustworthy enough to keep during
  /// recovery (completed, or failed-but-partially-written and re-downloadable).
  bool get isRecoverable => state == SegmentState.completed;

  DownloadSegment copyWith({
    int? index,
    int? startOffset,
    int? endOffset,
    int? expectedBytes,
    int? actualBytes,
    SegmentState? state,
    String? mimeType,
    int? retryCount,
    String? lastError,
    int? httpStatus,
    DateTime? lastUpdatedAt,
  }) {
    return DownloadSegment(
      index: index ?? this.index,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      expectedBytes: expectedBytes ?? this.expectedBytes,
      actualBytes: actualBytes ?? this.actualBytes,
      state: state ?? this.state,
      mimeType: mimeType ?? this.mimeType,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      httpStatus: httpStatus ?? this.httpStatus,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  List<Object?> get props => [
    index,
    startOffset,
    endOffset,
    expectedBytes,
    actualBytes,
    state,
    mimeType,
    retryCount,
    lastError,
    httpStatus,
    lastUpdatedAt,
  ];
}

/// Full persisted metadata for one download session.
///
/// This is the authoritative record used by the startup recovery flow. It
/// intentionally duplicates a few fields from [DownloadTask] so that recovery
/// can proceed even if the in-memory task object has been discarded.
class DownloadSession extends Equatable {
  final String taskId;
  final String url;
  final String? refreshedUrl;
  final String destinationPath;
  final String tempDirectory;
  final int? expectedSize;
  final String? eTag;
  final String? lastModified;
  final String? mimeType;
  final String profile;
  final int segmentCount;
  final List<DownloadSegment> segments;
  final DownloadStatus lastStatus;
  final DateTime lastUpdatedAt;
  final int? actualBytes;
  final String? lastError;

  const DownloadSession({
    required this.taskId,
    required this.url,
    this.refreshedUrl,
    required this.destinationPath,
    required this.tempDirectory,
    this.expectedSize,
    this.eTag,
    this.lastModified,
    this.mimeType,
    required this.profile,
    required this.segmentCount,
    required this.segments,
    required this.lastStatus,
    required this.lastUpdatedAt,
    this.actualBytes,
    this.lastError,
  });

  /// Total bytes present in completed segments (verified on disk).
  int get completedBytes =>
      segments.where((s) => s.isComplete).fold(0, (a, b) => a + b.actualBytes);

  /// Segments that still need to be (re)downloaded.
  List<DownloadSegment> get incompleteSegments =>
      segments.where((s) => !s.isComplete).toList();

  /// True if every segment is completed and the total matches the expected size.
  bool get isConsistentlyComplete =>
      segments.every((s) => s.isComplete) &&
      (expectedSize == null || completedBytes == expectedSize);

  DownloadSession copyWith({
    String? url,
    String? refreshedUrl,
    String? destinationPath,
    String? tempDirectory,
    int? expectedSize,
    String? eTag,
    String? lastModified,
    String? mimeType,
    String? profile,
    int? segmentCount,
    List<DownloadSegment>? segments,
    DownloadStatus? lastStatus,
    DateTime? lastUpdatedAt,
    int? actualBytes,
    String? lastError,
  }) {
    return DownloadSession(
      taskId: taskId,
      url: url ?? this.url,
      refreshedUrl: refreshedUrl ?? this.refreshedUrl,
      destinationPath: destinationPath ?? this.destinationPath,
      tempDirectory: tempDirectory ?? this.tempDirectory,
      expectedSize: expectedSize ?? this.expectedSize,
      eTag: eTag ?? this.eTag,
      lastModified: lastModified ?? this.lastModified,
      mimeType: mimeType ?? this.mimeType,
      profile: profile ?? this.profile,
      segmentCount: segmentCount ?? this.segmentCount,
      segments: segments ?? this.segments,
      lastStatus: lastStatus ?? this.lastStatus,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      actualBytes: actualBytes ?? this.actualBytes,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  List<Object?> get props => [
    taskId,
    url,
    refreshedUrl,
    destinationPath,
    tempDirectory,
    expectedSize,
    eTag,
    lastModified,
    mimeType,
    profile,
    segmentCount,
    segments,
    lastStatus,
    lastUpdatedAt,
    actualBytes,
    lastError,
  ];
}
