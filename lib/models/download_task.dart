import 'package:equatable/equatable.dart';

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
  final DownloadStatus status;
  final double progress;
  final int? speedBps;
  final int? etaSeconds;
  final int? totalBytes;
  final int? downloadedBytes;
  final String? errorMessage;
  final String? outputPath;
  final DateTime createdAt;
  final DateTime? completedAt;

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
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.speedBps,
    this.etaSeconds,
    this.totalBytes,
    this.downloadedBytes,
    this.errorMessage,
    this.outputPath,
    required this.createdAt,
    this.completedAt,
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
    DownloadStatus? status,
    double? progress,
    int? speedBps,
    int? etaSeconds,
    int? totalBytes,
    int? downloadedBytes,
    String? errorMessage,
    String? outputPath,
    DateTime? createdAt,
    DateTime? completedAt,
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
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedBps: speedBps ?? this.speedBps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      outputPath: outputPath ?? this.outputPath,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [id, url, status, progress];
}
