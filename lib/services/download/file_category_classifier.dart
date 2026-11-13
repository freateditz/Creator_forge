/// Represents a file category for automatic organization.
enum FileCategory {
  videos('Videos'),
  music('Music'),
  documents('Documents'),
  compressed('Compressed'),
  programs('Programs'),
  images('Images'),
  other('Other');

  const FileCategory(this.folderName);

  /// The default folder name for this category.
  final String folderName;

  /// Get category from a string (case-insensitive).
  static FileCategory? fromString(String value) {
    try {
      return FileCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == value.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get category from folder name (case-insensitive).
  static FileCategory? fromFolderName(String folderName) {
    try {
      return FileCategory.values.firstWhere(
        (c) => c.folderName.toLowerCase() == folderName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Classification result with source information for debugging.
class ClassificationResult {
  final FileCategory category;
  final ClassificationSource source;
  final String? matchedExtension;
  final String? matchedMimeType;

  const ClassificationResult({
    required this.category,
    required this.source,
    this.matchedExtension,
    this.matchedMimeType,
  });

  @override
  String toString() =>
      'ClassificationResult(category: $category, source: $source, '
      'ext: $matchedExtension, mime: $matchedMimeType)';
}

/// Source of classification for debugging and precedence.
enum ClassificationSource {
  /// Determined from HTTP Content-Type header.
  mimeType,

  /// Determined from Content-Disposition filename.
  contentDisposition,

  /// Determined from final downloaded filename/extension.
  finalFilename,

  /// Determined from browser-provided hints (URL, initial filename).
  browserHint,

  /// Unknown - defaulted to Other.
  unknown,
}

/// Service for classifying files into categories.
///
/// Uses a priority-based approach:
/// 1. Response MIME type (most reliable)
/// 2. Content-Disposition filename
/// 3. Final filename/extension
/// 4. Browser-provided hints (URL, initial filename)
/// 5. Defaults to Other
class FileCategoryClassifier {
  FileCategoryClassifier._();

  static final FileCategoryClassifier instance = FileCategoryClassifier._();

  // ── MIME type to category mapping ──────────────────────────────────────────

  static const Map<String, FileCategory> _mimeToCategory = {
    // Video
    'video/mp4': FileCategory.videos,
    'video/x-matroska': FileCategory.videos,
    'video/x-msvideo': FileCategory.videos,
    'video/quicktime': FileCategory.videos,
    'video/webm': FileCategory.videos,
    'video/x-m4v': FileCategory.videos,
    'video/mpeg': FileCategory.videos,
    'video/3gpp': FileCategory.videos,
    'video/3gpp2': FileCategory.videos,
    'video/x-flv': FileCategory.videos,
    'video/x-ms-wmv': FileCategory.videos,
    'video/x-ms-asf': FileCategory.videos,
    'video/ogg': FileCategory.videos,
    'video/av1': FileCategory.videos,
    'video/h264': FileCategory.videos,
    'video/h265': FileCategory.videos,

    // Audio
    'audio/mpeg': FileCategory.music,
    'audio/mp3': FileCategory.music,
    'audio/wav': FileCategory.music,
    'audio/x-wav': FileCategory.music,
    'audio/flac': FileCategory.music,
    'audio/aac': FileCategory.music,
    'audio/mp4': FileCategory.music,
    'audio/x-m4a': FileCategory.music,
    'audio/ogg': FileCategory.music,
    'audio/opus': FileCategory.music,
    'audio/webm': FileCategory.music,
    'audio/x-ms-wma': FileCategory.music,
    'audio/basic': FileCategory.music,
    'audio/midi': FileCategory.music,

    // Documents
    'application/pdf': FileCategory.documents,
    'application/msword': FileCategory.documents,
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        FileCategory.documents,
    'application/vnd.ms-excel': FileCategory.documents,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        FileCategory.documents,
    'application/vnd.ms-powerpoint': FileCategory.documents,
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        FileCategory.documents,
    'text/plain': FileCategory.documents,
    'text/csv': FileCategory.documents,
    'text/tab-separated-values': FileCategory.documents,
    'application/rtf': FileCategory.documents,
    'application/x-rtf': FileCategory.documents,

    // Compressed
    'application/zip': FileCategory.compressed,
    'application/x-zip-compressed': FileCategory.compressed,
    'application/x-rar-compressed': FileCategory.compressed,
    'application/vnd.rar': FileCategory.compressed,
    'application/x-7z-compressed': FileCategory.compressed,
    'application/x-tar': FileCategory.compressed,
    'application/gzip': FileCategory.compressed,
    'application/x-gzip': FileCategory.compressed,
    'application/x-bzip2': FileCategory.compressed,
    'application/x-xz': FileCategory.compressed,

    // Programs
    'application/x-msdownload': FileCategory.programs,
    'application/x-msi': FileCategory.programs,
    'application/vnd.microsoft.portable-executable': FileCategory.programs,
    'application/x-apple-diskimage': FileCategory.programs,
    'application/vnd.android.package-archive': FileCategory.programs,
    'application/x-sh': FileCategory.programs,
    'application/x-python': FileCategory.programs,
    'text/x-shellscript': FileCategory.programs,
    'application/x-powershell': FileCategory.programs,

    // Images
    'image/jpeg': FileCategory.images,
    'image/png': FileCategory.images,
    'image/gif': FileCategory.images,
    'image/svg+xml': FileCategory.images,
    'image/webp': FileCategory.images,
    'image/bmp': FileCategory.images,
    'image/tiff': FileCategory.images,
    'image/x-tiff': FileCategory.images,
    'image/heic': FileCategory.images,
    'image/heif': FileCategory.images,
    'image/vnd.microsoft.icon': FileCategory.images,
  };

  // ── Extension to category mapping ──────────────────────────────────────────

  static const Map<String, FileCategory> _extToCategory = {
    // Video
    'mp4': FileCategory.videos,
    'mkv': FileCategory.videos,
    'avi': FileCategory.videos,
    'mov': FileCategory.videos,
    'webm': FileCategory.videos,
    'm4v': FileCategory.videos,
    'mpeg': FileCategory.videos,
    'mpg': FileCategory.videos,
    '3gp': FileCategory.videos,
    '3g2': FileCategory.videos,
    'flv': FileCategory.videos,
    'wmv': FileCategory.videos,
    'asf': FileCategory.videos,
    'ogv': FileCategory.videos,
    'av1': FileCategory.videos,
    'ts': FileCategory.videos,
    'm2ts': FileCategory.videos,
    'vob': FileCategory.videos,

    // Audio
    'mp3': FileCategory.music,
    'wav': FileCategory.music,
    'flac': FileCategory.music,
    'aac': FileCategory.music,
    'm4a': FileCategory.music,
    'ogg': FileCategory.music,
    'opus': FileCategory.music,
    'wma': FileCategory.music,
    'mid': FileCategory.music,
    'midi': FileCategory.music,
    'amr': FileCategory.music,
    'aiff': FileCategory.music,
    'ape': FileCategory.music,

    // Documents
    'pdf': FileCategory.documents,
    'doc': FileCategory.documents,
    'docx': FileCategory.documents,
    'txt': FileCategory.documents,
    'xls': FileCategory.documents,
    'xlsx': FileCategory.documents,
    'ppt': FileCategory.documents,
    'pptx': FileCategory.documents,
    'csv': FileCategory.documents,
    'rtf': FileCategory.documents,
    'odt': FileCategory.documents,
    'ods': FileCategory.documents,
    'odp': FileCategory.documents,

    // Compressed
    'zip': FileCategory.compressed,
    'rar': FileCategory.compressed,
    '7z': FileCategory.compressed,
    'tar': FileCategory.compressed,
    'gz': FileCategory.compressed,
    'gzip': FileCategory.compressed,
    'bz2': FileCategory.compressed,
    'xz': FileCategory.compressed,
    'tgz': FileCategory.compressed,
    'tbz2': FileCategory.compressed,
    'txz': FileCategory.compressed,

    // Programs
    'exe': FileCategory.programs,
    'msi': FileCategory.programs,
    'msix': FileCategory.programs,
    'appx': FileCategory.programs,
    'bat': FileCategory.programs,
    'cmd': FileCategory.programs,
    'ps1': FileCategory.programs,
    'sh': FileCategory.programs,
    'py': FileCategory.programs,
    'apk': FileCategory.programs,
    'dmg': FileCategory.programs,
    'pkg': FileCategory.programs,
    'appimage': FileCategory.programs,
    'deb': FileCategory.programs,
    'rpm': FileCategory.programs,

    // Images
    'jpg': FileCategory.images,
    'jpeg': FileCategory.images,
    'png': FileCategory.images,
    'gif': FileCategory.images,
    'svg': FileCategory.images,
    'webp': FileCategory.images,
    'bmp': FileCategory.images,
    'tiff': FileCategory.images,
    'tif': FileCategory.images,
    'heic': FileCategory.images,
    'heif': FileCategory.images,
    'ico': FileCategory.images,
  };

  // ── Compound extensions that should be recognized ──────────────────────────

  static const Set<String> _compoundExtensions = {
    'tar.gz',
    'tar.bz2',
    'tar.xz',
    'tar.zst',
    'tgz',
    'tbz2',
    'txz',
  };

  /// Classify a file using the available information.
  ///
  /// Priority order:
  /// 1. MIME type from response headers
  /// 2. Content-Disposition filename
  /// 3. Final filename/extension
  /// 4. Browser-provided hints (initial filename, URL)
  /// 5. Unknown → Other
  ClassificationResult classify({
    String? mimeType,
    String? contentDispositionFilename,
    String? finalFilename,
    String? browserFilename,
    String? url,
  }) {
    // 1. Check MIME type (highest priority)
    if (mimeType != null && mimeType.isNotEmpty) {
      final normalizedMime = mimeType.toLowerCase().split(';').first.trim();
      if (_mimeToCategory.containsKey(normalizedMime)) {
        return ClassificationResult(
          category: _mimeToCategory[normalizedMime]!,
          source: ClassificationSource.mimeType,
          matchedMimeType: normalizedMime,
        );
      }
    }

    // 2. Check Content-Disposition filename
    if (contentDispositionFilename != null &&
        contentDispositionFilename.isNotEmpty) {
      final ext = _extractExtension(contentDispositionFilename);
      if (ext != null) {
        final result = _classifyByExtension(ext);
        if (result.category != FileCategory.other) {
          return ClassificationResult(
            category: result.category,
            source: ClassificationSource.contentDisposition,
            matchedExtension: result.extension,
          );
        }
      }
    }

    // 3. Check final filename (after download, from server)
    if (finalFilename != null && finalFilename.isNotEmpty) {
      final ext = _extractExtension(finalFilename);
      if (ext != null) {
        final result = _classifyByExtension(ext);
        if (result.category != FileCategory.other) {
          return ClassificationResult(
            category: result.category,
            source: ClassificationSource.finalFilename,
            matchedExtension: result.extension,
          );
        }
      }
    }

    // 4. Check browser-provided filename hint
    if (browserFilename != null && browserFilename.isNotEmpty) {
      final ext = _extractExtension(browserFilename);
      if (ext != null) {
        final result = _classifyByExtension(ext);
        if (result.category != FileCategory.other) {
          return ClassificationResult(
            category: result.category,
            source: ClassificationSource.browserHint,
            matchedExtension: result.extension,
          );
        }
      }
    }

    // 5. Check URL path as last resort
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final lastSegment = pathSegments.last;
          final ext = _extractExtension(lastSegment);
          if (ext != null) {
            final result = _classifyByExtension(ext);
            if (result.category != FileCategory.other) {
              return ClassificationResult(
                category: result.category,
                source: ClassificationSource.browserHint,
                matchedExtension: result.extension,
              );
            }
          }
        }
      } catch (_) {
        // Ignore URL parse errors
      }
    }

    // Default to Other
    return const ClassificationResult(
      category: FileCategory.other,
      source: ClassificationSource.unknown,
    );
  }

  /// Classify using only an extension string (e.g., "pdf", "tar.gz").
  _ClassificationByExt _classifyByExtension(String ext) {
    final lower = ext.toLowerCase();

    // Check compound extensions first
    for (final compound in _compoundExtensions) {
      if (lower.endsWith(compound)) {
        final category = _extToCategory[compound];
        if (category != null) {
          return _ClassificationByExt(category, compound);
        }
      }
    }

    // Check simple extension
    final category = _extToCategory[lower];
    if (category != null) {
      return _ClassificationByExt(category, lower);
    }

    return _ClassificationByExt(FileCategory.other, lower);
  }

  /// Extract extension from filename, handling compound extensions.
  String? _extractExtension(String filename) {
    // Remove query string and fragment
    final cleanName = filename.split('?').first.split('#').first;
    final lower = cleanName.toLowerCase();

    // Check compound extensions
    for (final compound in _compoundExtensions) {
      if (lower.endsWith('.$compound')) {
        return compound;
      }
    }

    // Simple extension
    final dotIndex = cleanName.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < cleanName.length - 1) {
      return cleanName.substring(dotIndex + 1).toLowerCase();
    }

    return null;
  }

  /// Get the default folder name for a category.
  String getDefaultFolderName(FileCategory category) {
    return category.folderName;
  }

  /// Get all available categories.
  List<FileCategory> getAllCategories() {
    return FileCategory.values;
  }
}

/// Internal helper for extension-based classification.
class _ClassificationByExt {
  final FileCategory category;
  final String extension;

  _ClassificationByExt(this.category, this.extension);
}
