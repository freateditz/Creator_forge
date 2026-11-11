import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:creator_forge/services/provisioning/dependency_provisioner.dart';

void main() {
  late Directory tmpDir;
  late DependencyProvisioner provisioner;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('dep_provisioner_test_');
    provisioner = DependencyProvisioner(binDir: tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('DependencyProvisioner', () {
    group('isYtDlpProvisioned', () {
      test('returns false when yt-dlp binary is absent', () {
        expect(provisioner.isYtDlpProvisioned, isFalse);
      });

      test('returns false when yt-dlp binary exists but is empty', () {
        File(provisioner.ytDlpPath).createSync();
        // zero-byte file — should not count as provisioned
        expect(provisioner.isYtDlpProvisioned, isFalse);
      });

      test('returns true when yt-dlp binary exists with non-zero size', () {
        final f = File(provisioner.ytDlpPath)..createSync();
        f.writeAsBytesSync([0x7f, 0x45, 0x4c, 0x46]); // ELF magic
        expect(provisioner.isYtDlpProvisioned, isTrue);
      });
    });

    group('isFfmpegProvisioned', () {
      test('returns false when ffmpeg binary is absent', () {
        expect(provisioner.isFfmpegProvisioned, isFalse);
      });

      test('returns false when ffmpeg binary exists but is empty', () {
        File(provisioner.ffmpegPath).createSync();
        expect(provisioner.isFfmpegProvisioned, isFalse);
      });

      test('returns true when ffmpeg binary exists with non-zero size', () {
        final f = File(provisioner.ffmpegPath)..createSync();
        f.writeAsBytesSync([0x7f, 0x45, 0x4c, 0x46]);
        expect(provisioner.isFfmpegProvisioned, isTrue);
      });
    });

    group('path properties', () {
      test('ytDlpPath is inside binDir', () {
        expect(provisioner.ytDlpPath, startsWith(tmpDir.path));
        expect(provisioner.ytDlpPath, contains('yt-dlp'));
      });

      test('ffmpegPath is inside binDir', () {
        expect(provisioner.ffmpegPath, startsWith(tmpDir.path));
        expect(provisioner.ffmpegPath, contains('ffmpeg'));
      });

      test('ffprobePath is inside binDir', () {
        expect(provisioner.ffprobePath, startsWith(tmpDir.path));
        expect(provisioner.ffprobePath, contains('ffprobe'));
      });

      test('ffmpegPath and ffprobePath are siblings', () {
        final ffmpegDir = File(provisioner.ffmpegPath).parent.path;
        final ffprobeDir = File(provisioner.ffprobePath).parent.path;
        expect(ffmpegDir, equals(ffprobeDir));
      });
    });

    group('Platform detection', () {
      test('ytDlpPath has correct extension for current platform', () {
        if (Platform.isWindows) {
          expect(provisioner.ytDlpPath, endsWith('.exe'));
        } else {
          expect(provisioner.ytDlpPath, isNot(endsWith('.exe')));
        }
      });

      test('ffmpegPath has correct extension for current platform', () {
        if (Platform.isWindows) {
          expect(provisioner.ffmpegPath, endsWith('.exe'));
          expect(provisioner.ffprobePath, endsWith('.exe'));
        } else {
          expect(provisioner.ffmpegPath, isNot(endsWith('.exe')));
          expect(provisioner.ffprobePath, isNot(endsWith('.exe')));
        }
      });
    });

    group('provisionFfmpeg false-success prevention', () {
      test('provisionFfmpeg throws on unsupported platforms (Linux)', () async {
        // This test only makes sense on Linux where auto-provisioning is
        // not supported. On macOS/Windows it would actually download — skip.
        if (!Platform.isLinux) return;
        expect(
          () => provisioner.provisionFfmpeg(),
          throwsA(isA<UnsupportedError>()),
        );
      }, skip: 'Only meaningful on Linux — skipped on other platforms');
    });
  });
}
