import 'package:equatable/equatable.dart';

import '../services/download/file_category_classifier.dart';

enum DownloadStatus {
  queued,
  resolving,
  downloading,
  paused,
  merging,
  completed,
  failed,
  cancelled,
}

enum DownloadType { videoAndAudio, videoOnly, audioOnly }

class DownloadTask extends Equatable {
  final String id;
  final String url;
  final String? title;
  final String? thumbnailUrl;
  final String? channelName;
  final int? durationSeconds;
  final DownloadType downloadType;
  final String? selectedFormat;
  final String? selectedQuality;
  final String outputDirectory;
  final String? outputFilename;
  final FileCategory? category;
  final String? destinationFolder;
  final DownloadStatus status;
  final double progress;
  final int? speedBps;
  final int? etaSeconds;
  final int? totalBytes;
  final int? downloadedBytes;
  final String? errorMessage;
  final String? outputPath;
  final String? eTag;
  final String? lastModified;
  final String? profile;
  final DateTime createdAt;
  final DateTime? completedAt;

  // ── Crash recovery metadata ───────────────────────────────────────────────
  /// When the task was in merging state - used to detect interrupted merge
  final DateTime? mergingStartedAt;

  /// Recovery state: unknown, resumable, corrupted, merging, merging_failed
  final String? recoveryState;

  /// Original expected file size - verified after crash recovery
  final int? originalFileSize;

  /// Original ETag - used to validate resource identity before segment reuse
  final String? originalETag;

  /// Temporary directory where segments are stored
  final String? tempDirectory;

  const DownloadTask({
    required this.id,
    required this.url,
    this.title,
    this.thumbnailUrl,
    this.channelName,
    this.durationSeconds,
    this.downloadType = DownloadType.videoAndAudio,
    this.selectedFormat,
    this.selectedQuality,
    required this.outputDirectory,
    this.outputFilename,
    this.category,
    this.destinationFolder,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.speedBps,
    this.etaSeconds,
    this.totalBytes,
    this.downloadedBytes,
    this.errorMessage,
    this.outputPath,
    this.eTag,
    this.lastModified,
    this.profile,
    required this.createdAt,
    this.completedAt,
    // ── Crash recovery metadata ─────────────────────────────────────────────
    this.mergingStartedAt,
    this.recoveryState,
    this.originalFileSize,
    this.originalETag,
    this.tempDirectory,
  });

  DownloadTask copyWith({
    String? id,
    String? url,
    String? title,
    String? thumbnailUrl,
    String? channelName,
    int? durationSeconds,
    DownloadType? downloadType,
    String? selectedFormat,
    String? selectedQuality,
    String? outputDirectory,
    String? outputFilename,
    FileCategory? category,
    String? destinationFolder,
    DownloadStatus? status,
    double? progress,
    int? speedBps,
    int? etaSeconds,
    int? totalBytes,
    int? downloadedBytes,
    String? errorMessage,
    String? outputPath,
    String? eTag,
    String? lastModified,
    String? profile,
    DateTime? createdAt,
    DateTime? completedAt,
    // ── Crash recovery metadata ─────────────────────────────────────────────
    DateTime? mergingStartedAt,
    String? recoveryState,
    int? originalFileSize,
    String? originalETag,
    String? tempDirectory,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelName: channelName ?? this.channelName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      downloadType: downloadType ?? this.downloadType,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      outputFilename: outputFilename ?? this.outputFilename,
      category: category ?? this.category,
      destinationFolder: destinationFolder ?? this.destinationFolder,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedBps: speedBps ?? this.speedBps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      outputPath: outputPath ?? this.outputPath,
      eTag: eTag ?? this.eTag,
      lastModified: lastModified ?? this.lastModified,
      profile: profile ?? this.profile,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      // ── Crash recovery metadata ─────────────────────────────────────────────
      mergingStartedAt: mergingStartedAt ?? this.mergingStartedAt,
      recoveryState: recoveryState ?? this.recoveryState,
      originalFileSize: originalFileSize ?? this.originalFileSize,
      originalETag: originalETag ?? this.originalETag,
      tempDirectory: tempDirectory ?? this.tempDirectory,
    );
  }

  @override
  List<Object?> get props => [
    id,
    url,
    title,
    thumbnailUrl,
    channelName,
    durationSeconds,
    downloadType,
    selectedFormat,
    selectedQuality,
    outputDirectory,
    outputFilename,
    category,
    destinationFolder,
    status,
    progress,
    speedBps,
    etaSeconds,
    totalBytes,
    downloadedBytes,
    errorMessage,
    outputPath,
    eTag,
    lastModified,
    profile,
    createdAt,
    completedAt,
    // ── Crash recovery metadata ─────────────────────────────────────────────
    mergingStartedAt,
    recoveryState,
    originalFileSize,
    originalETag,
    tempDirectory,
  ];
}
