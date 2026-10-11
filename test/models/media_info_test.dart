import 'package:flutter_test/flutter_test.dart';
import 'package:creator_forge/models/media_info.dart';

void main() {
  const testUrl = 'https://example.com/video';

  group('MediaFormat.fromJson', () {
    test('parses a muxed format (video+audio)', () {
      final f = MediaFormat.fromJson({
        'format_id': '22',
        'ext': 'mp4',
        'height': 720,
        'width': 1280,
        'fps': 30.0,
        'vcodec': 'avc1.64001F',
        'acodec': 'mp4a.40.2',
        'filesize': 52428800,
        'tbr': 2500.0,
        'dynamic_range': 'SDR',
        'format_note': 'hd720',
      });

      expect(f.formatId, '22');
      expect(f.ext, 'mp4');
      expect(f.height, 720);
      expect(f.width, 1280);
      expect(f.fps, 30.0);
      expect(f.hasVideo, isTrue);
      expect(f.hasAudio, isTrue);
      expect(f.isMuxed, isTrue);
      expect(f.isVideoOnly, isFalse);
      expect(f.isAudioOnly, isFalse);
      expect(f.fileSizeBytes, 52428800);
      expect(f.isHdr, isFalse);
    });

    test('identifies audio-only format (vcodec=none)', () {
      final f = MediaFormat.fromJson({
        'format_id': '140',
        'ext': 'm4a',
        'height': null,
        'width': null,
        'vcodec': 'none',
        'acodec': 'mp4a.40.2',
        'abr': 128.0,
      });

      expect(f.hasVideo, isFalse);
      expect(f.hasAudio, isTrue);
      expect(f.isAudioOnly, isTrue);
      expect(f.isMuxed, isFalse);
    });

    test('identifies video-only format (acodec=none)', () {
      final f = MediaFormat.fromJson({
        'format_id': '137',
        'ext': 'mp4',
        'height': 1080,
        'vcodec': 'avc1.640028',
        'acodec': 'none',
        'vbr': 5000.0,
      });

      expect(f.hasVideo, isTrue);
      expect(f.hasAudio, isFalse);
      expect(f.isVideoOnly, isTrue);
    });

    test('handles null filesize gracefully', () {
      final f = MediaFormat.fromJson({
        'format_id': '0',
        'ext': 'webm',
        'height': 240,
        'vcodec': 'vp9',
        'acodec': 'opus',
        'filesize': null,
        'filesize_approx': 30379224,
      });

      expect(f.fileSizeBytes, isNull);
      expect(f.fileSizeApproxBytes, 30379224);
      expect(f.effectiveSizeBytes, 30379224);
    });

    test('detects HDR formats', () {
      final hdr = MediaFormat.fromJson({
        'format_id': 'hdr',
        'ext': 'mp4',
        'height': 2160,
        'vcodec': 'av01',
        'acodec': 'none',
        'dynamic_range': 'HDR10',
      });
      expect(hdr.isHdr, isTrue);

      final sdr = MediaFormat.fromJson({
        'format_id': 'sdr',
        'ext': 'mp4',
        'height': 1080,
        'vcodec': 'avc1',
        'acodec': 'none',
        'dynamic_range': 'SDR',
      });
      expect(sdr.isHdr, isFalse);
    });

    test('generates correct display label for video format', () {
      final f = MediaFormat.fromJson({
        'format_id': '137',
        'ext': 'mp4',
        'height': 1080,
        'vcodec': 'avc1',
        'acodec': 'none',
        'dynamic_range': 'SDR',
      });
      expect(f.displayLabel, contains('1080p'));
      expect(f.displayLabel, contains('MP4'));
    });

    test('generates display label for audio-only format', () {
      final f = MediaFormat.fromJson({
        'format_id': '140',
        'ext': 'm4a',
        'vcodec': 'none',
        'acodec': 'mp4a.40.2',
        'abr': 128.0,
      });
      expect(f.displayLabel, contains('audio'));
    });
  });

  group('MediaInfo.fromJson', () {
    final sampleJson = {
      'id': 'test123',
      'title': 'Test Video Title',
      'uploader': 'Test Channel',
      'duration': 634,
      'thumbnail': 'https://example.com/thumb.jpg',
      'formats': [
        {
          'format_id': '137',
          'ext': 'mp4',
          'height': 1080,
          'width': 1920,
          'vcodec': 'avc1',
          'acodec': 'none',
          'filesize_approx': 100000000,
          'tbr': 5000.0,
          'dynamic_range': 'SDR',
        },
        {
          'format_id': '140',
          'ext': 'm4a',
          'vcodec': 'none',
          'acodec': 'mp4a.40.2',
          'abr': 128.0,
          'filesize_approx': 10000000,
        },
        {
          'format_id': '22',
          'ext': 'mp4',
          'height': 720,
          'width': 1280,
          'vcodec': 'avc1',
          'acodec': 'mp4a.40.2',
          'filesize': 52428800,
          'dynamic_range': 'SDR',
        },
      ],
    };

    test('parses basic fields', () {
      final info = MediaInfo.fromJson(sampleJson, url: testUrl);
      expect(info.videoId, 'test123');
      expect(info.title, 'Test Video Title');
      expect(info.uploaderName, 'Test Channel');
      expect(info.durationSeconds, 634);
      expect(info.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(info.formats.length, 3);
    });

    test('maxVideoHeight returns highest video height', () {
      final info = MediaInfo.fromJson(sampleJson, url: testUrl);
      expect(info.maxVideoHeight, 1080);
    });

    test('availableVideoHeights collects all video heights', () {
      final info = MediaInfo.fromJson(sampleJson, url: testUrl);
      expect(info.availableVideoHeights, containsAll([1080, 720]));
    });

    test('videoFormats filters to video-only formats', () {
      final info = MediaInfo.fromJson(sampleJson, url: testUrl);
      expect(info.videoFormats.every((f) => f.hasVideo), isTrue);
    });

    test('audioFormats filters to audio-only formats', () {
      final info = MediaInfo.fromJson(sampleJson, url: testUrl);
      expect(info.audioFormats.every((f) => f.isAudioOnly), isTrue);
    });

    test('availableQualityOptions includes Best and AudioOnly', () {
      final info = MediaInfo.fromJson(sampleJson, url: testUrl);
      final options = info.availableQualityOptions;
      expect(options.any((o) => o.preset == QualityPreset.best), isTrue);
      expect(options.any((o) => o.preset == QualityPreset.audioOnly), isTrue);
    });

    test('handles missing thumbnail gracefully', () {
      final json = Map<String, dynamic>.from(sampleJson)..remove('thumbnail');
      final info = MediaInfo.fromJson(json, url: testUrl);
      expect(info.thumbnailUrl, isNull);
    });

    test('handles float duration', () {
      final json = Map<String, dynamic>.from(sampleJson)
        ..['duration'] = 634.553;
      final info = MediaInfo.fromJson(json, url: testUrl);
      expect(info.durationSeconds, 635);
    });
  });

  group('QualityOption', () {
    test('best has correct format selector', () {
      expect(QualityOption.best.formatSelector, contains('bestvideo'));
      expect(QualityOption.best.formatSelector, contains('bestaudio'));
    });

    test('audioOnly is marked as audio type', () {
      expect(QualityOption.audioOnly.preset, QualityPreset.audioOnly);
      expect(QualityOption.audioOnly.formatSelector, contains('bestaudio'));
    });

    test('forHeight generates height-limited selector', () {
      final opt = QualityOption.forHeight(1080);
      expect(opt.formatSelector, contains('height<=1080'));
      expect(opt.available, isTrue);
    });

    test('forHeight marks unavailable correctly', () {
      final opt = QualityOption.forHeight(2160, available: false);
      expect(opt.available, isFalse);
    });
  });
}
