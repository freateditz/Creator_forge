import 'dart:io';

import '../../core/utils/validators.dart';
import '../../models/app_settings.dart';
import '../../services/download/file_category_classifier.dart';

/// Centralized destination resolver for all download engines.
///
/// Ensures temp files are on the same filesystem volume as the final destination
/// for atomic rename, and applies Windows filename safety rules.
class DestinationResolver {
  DestinationResolver._();

  static final DestinationResolver instance = DestinationResolver._();

  /// Resolve the final output directory for a download based on its category
  /// and the current app settings.
  Future<Directory> resolveOutputDirectory({
    required FileCategory category,
    required AppSettings settings,
    String? customCategoryFolder,
  }) async {
    // Determine the base directory
    String baseDir = settings.defaultDownloadsDir;

    // If auto-organize is enabled, append the category folder
    if (settings.autoOrganizeEnabled) {
      final categoryFolder = _resolveCategoryFolder(
        customCategoryFolder: customCategoryFolder,
        category: category,
        settings: settings,
      );

      baseDir = _joinPath(baseDir, categoryFolder);
    }

    // Ensure the directory exists
    final dir = Directory(baseDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Resolve the final output path for a download.
  ///
  /// This is the single source of truth for the final destination used by
  /// ALL download engines (SegmentedHttpEngine, YtDlpDownloadEngine).
  ///
  /// Returns a tuple of (outputDirectory, outputFilename, finalPath).
  Future<(Directory outputDirectory, String outputFilename, String finalPath)>
  resolve({
    required String suggestedFilename,
    required FileCategory category,
    required AppSettings settings,
    String? customCategoryFolder,
    int? duplicateIndex, // For handling duplicates (0 = first, 1 = (1), etc.)
  }) async {
    // Sanitize the filename
    String filename = Validators.sanitizeFilename(suggestedFilename);
    if (filename.isEmpty) {
      filename = 'untitled';
    }

    // Handle duplicate index
    if (duplicateIndex != null && duplicateIndex > 0) {
      filename = _addDuplicateSuffix(filename, duplicateIndex);
    }

    // Resolve the output directory
    final outputDir = await resolveOutputDirectory(
      category: category,
      settings: settings,
      customCategoryFolder: customCategoryFolder,
    );

    final finalPath = _joinPath(outputDir.path, filename);

    return (outputDir, filename, finalPath);
  }

  /// Resolve the temporary directory for a download.
  ///
  /// CRITICAL: Temp files MUST be on the same filesystem volume as the final
  /// destination to allow atomic rename (no cross-volume copy).
  Future<Directory> resolveTempDirectory({
    required String taskId,
    required String finalDestinationPath,
  }) async {
    // On Windows, use the same volume as the final destination
    // On Unix, we can use the system temp dir if it's on the same filesystem
    // For simplicity and safety, we'll create a temp directory under the
    // final destination's parent directory (guaranteed same volume).
    final destFile = File(finalDestinationPath);
    final parentDir = destFile.parent;
    final tempDirPath = _joinPath(
      _joinPath(parentDir.path, '.creatorforge_temp'),
      taskId,
    );

    final tempDir = Directory(tempDirPath);
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    return tempDir;
  }

  /// Get the category folder override from settings, if any.
  String? _getCategoryFolderOverride(
    FileCategory category,
    AppSettings settings,
  ) {
    final overrides = settings.categoryFolderOverrides;
    if (overrides == null) return null;
    return overrides[category.name];
  }

  /// Resolve the category folder to use, honoring precedence and treating
  /// empty/blank overrides as "fall back to the default".
  String _resolveCategoryFolder({
    required String? customCategoryFolder,
    required FileCategory category,
    required AppSettings settings,
  }) {
    // Explicit customCategoryFolder takes precedence.
    if (customCategoryFolder != null && customCategoryFolder.isNotEmpty) {
      return customCategoryFolder;
    }
    // Otherwise use the per-category override, if set and non-empty.
    final override = _getCategoryFolderOverride(category, settings);
    if (override != null && override.isNotEmpty) {
      return override;
    }
    // Fall back to the category's default folder name.
    return category.folderName;
  }

  /// Join path segments in a platform-aware way.
  ///
  /// If [segment] is an absolute path (Windows drive letter or Unix root),
  /// it is returned directly without joining to [base].
  String _joinPath(String base, String segment) {
    if (base.isEmpty) return segment;
    if (segment.isEmpty) return base;

    // If segment is already an absolute path, use it directly
    if (_isAbsolutePath(segment)) {
      return segment;
    }

    // Normalize separators
    final normalizedBase = base.replaceAll('/', Platform.pathSeparator);
    final normalizedSegment = segment.replaceAll('/', Platform.pathSeparator);

    if (normalizedBase.endsWith(Platform.pathSeparator)) {
      return '$normalizedBase$normalizedSegment';
    }
    return '$normalizedBase${Platform.pathSeparator}$normalizedSegment';
  }

  /// Check if a path is absolute (Windows drive letter or Unix root).
  bool _isAbsolutePath(String path) {
    if (path.isEmpty) return false;
    // Windows: C:\..., D:/..., \\server\share (UNC)
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) return true;
    if (path.startsWith('\\\\') || path.startsWith('//')) return true;
    // Unix/macOS: /...
    if (path.startsWith('/')) return true;
    return false;
  }

  /// Add a duplicate suffix to a filename: "file (1).ext"
  String _addDuplicateSuffix(String filename, int index) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex > 0) {
      final stem = filename.substring(0, dotIndex);
      final ext = filename.substring(dotIndex);
      return '$stem ($index)$ext';
    }
    return '$filename ($index)';
  }

  /// Generate a unique filename by checking for existing files.
  ///
  /// Returns the final path with a unique name (appends (1), (2), etc.).
  Future<String> ensureUniquePath({
    required String basePath,
    required FileCategory category,
    required AppSettings settings,
    String? customCategoryFolder,
  }) async {
    final dir = await resolveOutputDirectory(
      category: category,
      settings: settings,
      customCategoryFolder: customCategoryFolder,
    );

    String filename = Validators.sanitizeFilename(
      basePath.split(Platform.pathSeparator).last,
    );
    if (filename.isEmpty) {
      filename = 'untitled';
    }

    String candidatePath = _joinPath(dir.path, filename);
    int index = 0;

    while (await File(candidatePath).exists()) {
      index++;
      filename = _addDuplicateSuffix(filename, index);
      candidatePath = _joinPath(dir.path, filename);
    }

    return candidatePath;
  }
}
