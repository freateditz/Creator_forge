import '../errors/app_exception.dart';

class Validators {
  Validators._();

  static const _allowedSchemes = {'http', 'https'};
  static const _blockedHosts = <String>{};

  static Uri validateUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('URL cannot be empty.', field: 'url');
    }

    late final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e) {
      throw ValidationException(
        'Invalid URL format.',
        field: 'url',
        technicalDetails: e.toString(),
      );
    }

    if (!uri.hasScheme || !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
      throw const ValidationException(
        'Only HTTP and HTTPS URLs are supported.',
        field: 'url',
      );
    }

    if (!uri.hasAuthority || uri.host.isEmpty) {
      throw const ValidationException(
        'URL must have a valid host.',
        field: 'url',
      );
    }

    if (_blockedHosts.contains(uri.host.toLowerCase())) {
      throw const ValidationException(
        'This URL is not supported.',
        field: 'url',
      );
    }

    return uri;
  }

  static const _windowsReservedNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  static String sanitizeFilename(String name) {
    if (name.isEmpty) return 'untitled';

    // Remove path separators and path traversal components
    String clean = name
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Strip trailing dots and spaces (invalid on Windows)
    while (clean.endsWith('.') || clean.endsWith(' ')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }

    if (clean.isEmpty) return 'download';

    // Check Windows reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9)
    final stem = clean.contains('.')
        ? clean.substring(0, clean.indexOf('.')).toUpperCase()
        : clean.toUpperCase();

    if (_windowsReservedNames.contains(stem)) {
      clean = 'file_$clean';
    }

    return clean;
  }

  static bool isValidPath(String path) {
    if (path.isEmpty) return false;
    return path.length < 32768;
  }
}
