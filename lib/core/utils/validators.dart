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

  static String sanitizeFilename(String name) {
    if (name.isEmpty) return 'untitled';
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool isValidPath(String path) {
    if (path.isEmpty) return false;
    return path.length < 32768;
  }
}
