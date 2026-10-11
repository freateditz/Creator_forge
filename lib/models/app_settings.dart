import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String defaultDownloadsDir;
  final String tempDir;
  final int maxConcurrentDownloads;
  final int maxConcurrentJobs;
  final bool autoDeleteTempFiles;
  final bool keepDownloadHistory;
  final String gpuPreference;
  final bool showNotifications;
  final bool startMinimized;
  final String fileNamingTemplate;
  final int httpSegments;

  const AppSettings({
    required this.defaultDownloadsDir,
    required this.tempDir,
    this.maxConcurrentDownloads = 3,
    this.maxConcurrentJobs = 2,
    this.autoDeleteTempFiles = true,
    this.keepDownloadHistory = true,
    this.gpuPreference = 'auto',
    this.showNotifications = true,
    this.startMinimized = false,
    this.fileNamingTemplate = '%(title)s.%(ext)s',
    this.httpSegments = 8,
  });

  AppSettings copyWith({
    String? defaultDownloadsDir,
    String? tempDir,
    int? maxConcurrentDownloads,
    int? maxConcurrentJobs,
    bool? autoDeleteTempFiles,
    bool? keepDownloadHistory,
    String? gpuPreference,
    bool? showNotifications,
    bool? startMinimized,
    String? fileNamingTemplate,
    int? httpSegments,
  }) {
    return AppSettings(
      defaultDownloadsDir: defaultDownloadsDir ?? this.defaultDownloadsDir,
      tempDir: tempDir ?? this.tempDir,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      maxConcurrentJobs: maxConcurrentJobs ?? this.maxConcurrentJobs,
      autoDeleteTempFiles: autoDeleteTempFiles ?? this.autoDeleteTempFiles,
      keepDownloadHistory: keepDownloadHistory ?? this.keepDownloadHistory,
      gpuPreference: gpuPreference ?? this.gpuPreference,
      showNotifications: showNotifications ?? this.showNotifications,
      startMinimized: startMinimized ?? this.startMinimized,
      fileNamingTemplate: fileNamingTemplate ?? this.fileNamingTemplate,
      httpSegments: httpSegments ?? this.httpSegments,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultDownloadsDir': defaultDownloadsDir,
    'tempDir': tempDir,
    'maxConcurrentDownloads': maxConcurrentDownloads,
    'maxConcurrentJobs': maxConcurrentJobs,
    'autoDeleteTempFiles': autoDeleteTempFiles,
    'keepDownloadHistory': keepDownloadHistory,
    'gpuPreference': gpuPreference,
    'showNotifications': showNotifications,
    'startMinimized': startMinimized,
    'fileNamingTemplate': fileNamingTemplate,
    'httpSegments': httpSegments,
  };

  factory AppSettings.fromJson(
    Map<String, dynamic> json, {
    required String fallbackDownloadsDir,
    required String fallbackTempDir,
  }) {
    return AppSettings(
      defaultDownloadsDir:
          json['defaultDownloadsDir'] as String? ?? fallbackDownloadsDir,
      tempDir: json['tempDir'] as String? ?? fallbackTempDir,
      maxConcurrentDownloads: json['maxConcurrentDownloads'] as int? ?? 3,
      maxConcurrentJobs: json['maxConcurrentJobs'] as int? ?? 2,
      autoDeleteTempFiles: json['autoDeleteTempFiles'] as bool? ?? true,
      keepDownloadHistory: json['keepDownloadHistory'] as bool? ?? true,
      gpuPreference: json['gpuPreference'] as String? ?? 'auto',
      showNotifications: json['showNotifications'] as bool? ?? true,
      startMinimized: json['startMinimized'] as bool? ?? false,
      fileNamingTemplate:
          json['fileNamingTemplate'] as String? ?? '%(title)s.%(ext)s',
      httpSegments: json['httpSegments'] as int? ?? 8,
    );
  }

  @override
  List<Object?> get props => [
    defaultDownloadsDir,
    tempDir,
    maxConcurrentDownloads,
    maxConcurrentJobs,
    autoDeleteTempFiles,
    keepDownloadHistory,
    gpuPreference,
    showNotifications,
    startMinimized,
    fileNamingTemplate,
    httpSegments,
  ];
}
