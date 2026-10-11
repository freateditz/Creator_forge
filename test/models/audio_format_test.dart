import 'package:flutter_test/flutter_test.dart';

import 'package:creator_forge/models/audio_format.dart';

void main() {
  group('AudioOutputFormat', () {
    test('each format has a non-empty extension', () {
      for (final fmt in AudioOutputFormat.values) {
        expect(fmt.extension, isNotEmpty, reason: '${fmt.name} extension');
      }
    });

    test('each format has a non-empty FFmpeg encoder', () {
      for (final fmt in AudioOutputFormat.values) {
        expect(fmt.ffmpegEncoder, isNotEmpty, reason: '${fmt.name} encoder');
      }
    });

    test('WAV and FLAC are lossless', () {
      expect(AudioOutputFormat.wav.isLossless, isTrue);
      expect(AudioOutputFormat.flac.isLossless, isTrue);
    });

    test('MP3, AAC, M4A, OPUS are not lossless', () {
      for (final fmt in [
        AudioOutputFormat.mp3,
        AudioOutputFormat.aac,
        AudioOutputFormat.m4a,
        AudioOutputFormat.opus,
      ]) {
        expect(fmt.isLossless, isFalse, reason: fmt.name);
      }
    });

    test('lossless formats do not support bitrate', () {
      expect(AudioOutputFormat.wav.supportsBitRate, isFalse);
      expect(AudioOutputFormat.flac.supportsBitRate, isFalse);
    });

    test('OPUS does not support bitrate via supportsBitRate flag', () {
      // OPUS uses -b:a too, but supportsBitRate is false — bitrate is set
      // differently. Verify flag is false.
      expect(AudioOutputFormat.opus.supportsBitRate, isFalse);
    });

    test('only OPUS requiresFixedSampleRate', () {
      expect(AudioOutputFormat.opus.requiresFixedSampleRate, isTrue);
      for (final fmt in AudioOutputFormat.values) {
        if (fmt != AudioOutputFormat.opus) {
          expect(fmt.requiresFixedSampleRate, isFalse, reason: fmt.name);
        }
      }
    });

    test('streamCopySourceCodecs is non-empty for all formats', () {
      for (final fmt in AudioOutputFormat.values) {
        expect(
          fmt.streamCopySourceCodecs,
          isNotEmpty,
          reason: '${fmt.name} streamCopySourceCodecs',
        );
      }
    });

    test('AAC and M4A share aac as stream copy codec', () {
      expect(AudioOutputFormat.aac.streamCopySourceCodecs, contains('aac'));
      expect(AudioOutputFormat.m4a.streamCopySourceCodecs, contains('aac'));
    });

    test('fromId returns correct format', () {
      for (final fmt in AudioOutputFormat.values) {
        expect(AudioOutputFormat.fromId(fmt.name), fmt);
      }
    });

    test('fromId returns null for unknown id', () {
      expect(AudioOutputFormat.fromId('unknown'), isNull);
    });
  });

  group('AudioPreset', () {
    test('all built-in presets have non-empty id and label', () {
      for (final p in AudioPreset.builtIn) {
        expect(p.id, isNotEmpty);
        expect(p.label, isNotEmpty);
      }
    });

    test('findById returns correct preset', () {
      for (final p in AudioPreset.builtIn) {
        expect(AudioPreset.findById(p.id)?.id, p.id);
      }
    });

    test('findById returns null for unknown id', () {
      expect(AudioPreset.findById('no_such_preset'), isNull);
    });

    test('defaultForFormat returns a preset for each format', () {
      for (final fmt in AudioOutputFormat.values) {
        final preset = AudioPreset.defaultForFormat(fmt);
        expect(preset, isNotNull, reason: 'no default for ${fmt.name}');
      }
    });

    test('forFormat returns only presets for that format', () {
      for (final fmt in AudioOutputFormat.values) {
        final presets = AudioPreset.forFormat(fmt);
        for (final p in presets) {
          expect(p.format, fmt);
        }
      }
    });

    test('OPUS preset has sampleRateHz 48000', () {
      final opusPreset = AudioPreset.findById('opus_compact');
      expect(opusPreset?.sampleRateHz, 48000);
    });

    test('high_mp3 has bitRateKbps 320', () {
      expect(AudioPreset.findById('high_mp3')?.bitRateKbps, 320);
    });

    test('WAV edit preset has stereo channels', () {
      expect(AudioPreset.findById('wav_edit')?.channels, 'stereo');
    });
  });
}
