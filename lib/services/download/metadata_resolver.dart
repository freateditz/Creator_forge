import 'dart:convert';
import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/validators.dart';
import '../../models/media_info.dart';
import 'ytdlp_locator.dart';

class MetadataResolver {
  final YtDlpLocator _locator;
  final _log = AppLogger.get('MetadataResolver');

  MetadataResolver({YtDlpLocator? locator})
    : _locator = locator ?? YtDlpLocator.instance;

  Future<MediaInfo> resolve(String rawUrl) async {
    final uri = Validators.validateUrl(rawUrl);
    final url = uri.toString();

    final ytdlpPath = await _locator.resolve();
    if (ytdlpPath == null) {
      throw const DependencyException(
        'yt-dlp is not installed or could not be found. '
        'Install it with: pip install yt-dlp',
        dependency: 'yt-dlp',
      );
    }

    final args = [
      '--dump-json',
      '--no-download',
      '--no-playlist',
      '--no-warnings',
      url,
    ];

    _log.info('Resolving metadata for: $url');

    ProcessResult result;
    try {
      result =
          await Process.run(
            ytdlpPath,
            args,
            runInShell: false,
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw const NetworkException(
              'Metadata request timed out after 30 seconds.',
            ),
          );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        'Failed to connect to media source.',
        technicalDetails: e.toString(),
        cause: e,
      );
    }

    if (result.exitCode != 0) {
      final stderr = result.stderr as String;
      _log.warning('yt-dlp metadata exit ${result.exitCode}: $stderr');
      throw _interpretError(stderr, url);
    }

    final stdout = result.stdout as String;
    if (stdout.trim().isEmpty) {
      throw const MediaException(
        'No media information was returned for this URL.',
      );
    }

    return _parseJson(stdout.trim(), url);
  }

  MediaInfo _parseJson(String jsonStr, String url) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MediaInfo.fromJson(json, url: url);
    } catch (e) {
      throw MediaException(
        'Unable to retrieve media information.',
        technicalDetails: e.toString(),
        cause: e,
      );
    }
  }

  AppException _interpretError(String stderr, String url) {
    if (stderr.contains('This video is unavailable') ||
        stderr.contains('Video unavailable')) {
      return const MediaException('This video is unavailable.');
    }
    if (stderr.contains('Private video') || stderr.contains('private')) {
      return const AuthRequiredException(
        'This content is private and cannot be accessed.',
      );
    }
    if (stderr.contains('Sign in') ||
        stderr.contains('login required') ||
        stderr.contains('not logged in')) {
      return const AuthRequiredException(
        'This content requires authentication.',
      );
    }
    if (stderr.contains('DRM') || stderr.contains('Widevine')) {
      return const DrmProtectedException(
        'This content is DRM-protected and cannot be downloaded.',
      );
    }
    if (stderr.contains('HTTP Error 429') ||
        stderr.contains('rate limit') ||
        stderr.contains('Too Many Requests')) {
      return const NetworkException(
        'Rate limited by media source. Please wait a moment and try again.',
      );
    }
    if (stderr.contains('Unable to extract') ||
        stderr.contains('Unsupported URL')) {
      return const MediaException(
        'This URL is not supported. Please check that it is a valid media page.',
      );
    }
    if (stderr.contains('HTTP Error 403')) {
      return const NetworkException(
        'Access denied. The server refused the request.',
      );
    }
    if (stderr.contains('HTTP Error 404')) {
      return const MediaException(
        'This media could not be found (404). It may have been removed.',
      );
    }
    return MediaException(
      'Unable to retrieve media information.',
      technicalDetails: stderr.length > 500 ? stderr.substring(0, 500) : stderr,
    );
  }
}
