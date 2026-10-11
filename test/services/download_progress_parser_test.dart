import 'package:flutter_test/flutter_test.dart';
import 'package:creator_forge/services/download/download_progress_parser.dart';

void main() {
  group('DownloadProgressParser.parseProgress', () {
    test('parses standard in-progress line', () {
      const line = '[download]  23.4% of  100.00MiB at    5.00MiB/s ETA 00:16';
      final result = DownloadProgressParser.parseProgress(line);
      expect(result, isNotNull);
      expect(result!.percent, closeTo(0.234, 0.001));
      expect(result.totalBytes, equals(100 * 1024 * 1024));
      expect(result.speedBps, equals(5 * 1024 * 1024));
      expect(result.etaSeconds, equals(16));
    });

    test('parses 100% completion line', () {
      const line = '[download] 100.0% of  100.00MiB at   10.00MiB/s ETA 00:00';
      final result = DownloadProgressParser.parseProgress(line);
      expect(result, isNotNull);
      expect(result!.percent, closeTo(1.0, 0.001));
      expect(result.etaSeconds, equals(0));
    });

    test('handles Unknown speed', () {
      const line = '[download]   0.0% of  100.00MiB at Unknown B/s ETA Unknown';
      final result = DownloadProgressParser.parseProgress(line);
      expect(result, isNotNull);
      expect(result!.speedBps, isNull);
      expect(result.etaSeconds, isNull);
    });

    test('parses KiB units correctly', () {
      const line = '[download]  50.0% of  500.00KiB at  100.00KiB/s ETA 00:02';
      final result = DownloadProgressParser.parseProgress(line);
      expect(result, isNotNull);
      expect(result!.totalBytes, equals(500 * 1024));
      expect(result.speedBps, equals(100 * 1024));
    });

    test('parses GiB units correctly', () {
      const line = '[download]  10.0% of    1.00GiB at    1.00MiB/s ETA 00:10';
      final result = DownloadProgressParser.parseProgress(line);
      expect(result, isNotNull);
      expect(result!.totalBytes, equals(1024 * 1024 * 1024));
    });

    test('returns null for non-progress lines', () {
      expect(
        DownloadProgressParser.parseProgress('[youtube] Downloading...'),
        isNull,
      );
      expect(
        DownloadProgressParser.parseProgress(
          '[download] Destination: /path/to/file.mp4',
        ),
        isNull,
      );
      expect(DownloadProgressParser.parseProgress(''), isNull);
    });

    test('clamps percent to 0.0–1.0', () {
      const line = '[download] 100.5% of  100.00MiB at    5.00MiB/s ETA 00:00';
      final result = DownloadProgressParser.parseProgress(line);
      if (result != null) {
        expect(result.percent, lessThanOrEqualTo(1.0));
        expect(result.percent, greaterThanOrEqualTo(0.0));
      }
    });
  });

  group('DownloadProgressParser.parseDestination', () {
    test('parses download destination', () {
      const line = '[download] Destination: /Users/test/downloads/video.mp4';
      expect(
        DownloadProgressParser.parseDestination(line),
        equals('/Users/test/downloads/video.mp4'),
      );
    });

    test('parses merger destination', () {
      const line =
          '[Merger] Merging formats into "/Users/test/downloads/video.mp4"';
      expect(
        DownloadProgressParser.parseDestination(line),
        equals('/Users/test/downloads/video.mp4'),
      );
    });

    test('returns null for non-destination lines', () {
      expect(
        DownloadProgressParser.parseDestination('[download]  50.0%...'),
        isNull,
      );
    });
  });

  group('DownloadProgressParser.parseError', () {
    test('parses ERROR: lines', () {
      const line = 'ERROR: [youtube] Video unavailable';
      expect(
        DownloadProgressParser.parseError(line),
        equals('[youtube] Video unavailable'),
      );
    });

    test('returns null for non-error lines', () {
      expect(DownloadProgressParser.parseError('[download]  50.0%...'), isNull);
    });
  });

  group('DownloadProgressParser.isMerging', () {
    test('detects merger lines', () {
      expect(
        DownloadProgressParser.isMerging(
          '[Merger] Merging formats into "video.mp4"',
        ),
        isTrue,
      );
      expect(
        DownloadProgressParser.isMerging('[VideoRemuxer] Remuxing video...'),
        isTrue,
      );
    });

    test('returns false for non-merger lines', () {
      expect(DownloadProgressParser.isMerging('[download]  50.0%...'), isFalse);
    });
  });
}
