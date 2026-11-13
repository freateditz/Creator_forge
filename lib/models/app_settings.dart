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
  final String selectedBrowserId;
  final String downloadProfile; // 'balanced' (4), 'fast' (8), 'maximum' (16)

  // Phase 2: Automatic File Organization
  final bool autoOrganizeEnabled;
  final Map<String, String>? categoryFolderOverrides;

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
    this.selectedBrowserId = 'edge',
    this.downloadProfile = 'fast',
    this.autoOrganizeEnabled = true,
    this.categoryFolderOverrides,
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
    String? selectedBrowserId,
    String? downloadProfile,
    bool? autoOrganizeEnabled,
    Map<String, String>? categoryFolderOverrides,
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
      selectedBrowserId: selectedBrowserId ?? this.selectedBrowserId,
      downloadProfile: downloadProfile ?? this.downloadProfile,
      autoOrganizeEnabled: autoOrganizeEnabled ?? this.autoOrganizeEnabled,
      categoryFolderOverrides:
          categoryFolderOverrides ?? this.categoryFolderOverrides,
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
    'selectedBrowserId': selectedBrowserId,
    'downloadProfile': downloadProfile,
    'autoOrganizeEnabled': autoOrganizeEnabled,
    'categoryFolderOverrides': categoryFolderOverrides,
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
      selectedBrowserId: json['selectedBrowserId'] as String? ?? 'edge',
      downloadProfile: json['downloadProfile'] as String? ?? 'fast',
      autoOrganizeEnabled: json['autoOrganizeEnabled'] as bool? ?? true,
      categoryFolderOverrides: json['categoryFolderOverrides'] != null
          ? Map<String, String>.from(
              json['categoryFolderOverrides'] as Map<String, dynamic>,
            )
          : null,
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
    selectedBrowserId,
    downloadProfile,
    autoOrganizeEnabled,
    categoryFolderOverrides,
  ];
}
