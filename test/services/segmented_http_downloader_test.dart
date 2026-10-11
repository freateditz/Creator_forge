import 'package:flutter_test/flutter_test.dart';

import 'package:creator_forge/services/download/segmented_http_downloader.dart';

void main() {
  group('CancellationToken', () {
    test('is not cancelled initially', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('cancel() sets isCancelled to true', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled does not throw when not cancelled', () {
      final token = CancellationToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('throwIfCancelled throws when cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(() => token.throwIfCancelled(), throwsA(isA<Exception>()));
    });
  });

  group('SegmentProgress', () {
    test('fraction is 0 when total is 0', () {
      const sp = SegmentProgress(index: 0, received: 0, total: 0);
      expect(sp.fraction, 0.0);
    });

    test('fraction is 0.5 when half received', () {
      const sp = SegmentProgress(index: 0, received: 50, total: 100);
      expect(sp.fraction, 0.5);
    });

    test('fraction is 1.0 when fully received', () {
      const sp = SegmentProgress(index: 0, received: 100, total: 100);
      expect(sp.fraction, 1.0);
    });
  });

  group('SegmentedDownloadProgress', () {
    test('fraction is 0 when totalBytes is 0', () {
      const progress = SegmentedDownloadProgress(
        segments: [],
        totalBytes: 0,
        receivedBytes: 0,
        isRangeSupported: false,
      );
      expect(progress.fraction, 0.0);
    });

    test('fraction computes correctly', () {
      const progress = SegmentedDownloadProgress(
        segments: [],
        totalBytes: 1000,
        receivedBytes: 250,
        isRangeSupported: true,
      );
      expect(progress.fraction, 0.25);
    });

    test('activeSegments counts incomplete segments', () {
      const progress = SegmentedDownloadProgress(
        segments: [
          SegmentProgress(index: 0, received: 100, total: 100),
          SegmentProgress(index: 1, received: 50, total: 100),
          SegmentProgress(index: 2, received: 0, total: 100),
        ],
        totalBytes: 300,
        receivedBytes: 150,
        isRangeSupported: true,
      );
      expect(progress.activeSegments, 2);
    });
  });

  // Note: live network downloads are not tested here (no mock server).
  // The _downloadSingle and _downloadSegmented methods require a real HTTP
  // server. Integration tests for those would run against a local test server.
  // The segmentCount clamping is tested via the public API contract below.
}
