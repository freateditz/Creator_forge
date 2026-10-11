import 'package:flutter_test/flutter_test.dart';

import 'package:creator_forge/models/audio_format.dart';
import 'package:creator_forge/models/audio_request.dart';
import 'package:creator_forge/models/media_probe_result.dart';
import 'package:creator_forge/services/audio/ffmpeg_args_builder.dart';

MediaProbeResult _probe({
  String codecName = 'aac',
  int? sampleRate = 44100,
  bool hasVideo = true,
}) {
  return MediaProbeResult(
    path: '/tmp/test.mp4',
    durationSeconds: 120.0,
    audioStreams: [
      AudioStreamInfo(
        streamIndex: 0,
        codecName: codecName,
        sampleRate: sampleRate,
        channels: 2,
        channelLayout: 'stereo',
        bitRateBps: 256000,
      ),
    ],
    hasVideo: hasVideo,
    fileSizeBytes: 10 * 1024 * 1024,
  );
}

AudioRequest _req({
  AudioOperation operation = AudioOperation.extract,
  AudioOutputFormat outputFormat = AudioOutputFormat.mp3,
  String? presetId,
  int? bitRateKbps,
  int? sampleRateHz,
  String? channels,
  String outputDirectory = '/tmp/out',
}) {
  return AudioRequest(
    operation: operation,
    outputFormat: outputFormat,
    presetId: presetId,
    bitRateKbps: bitRateKbps,
    sampleRateHz: sampleRateHz,
    channels: channels,
    outputDirectory: outputDirectory,
  );
}

void main() {
  group('FfmpegArgsBuilder', () {
    test('always includes -i inputPath and -vn', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.mp3',
        request: _req(),
        probe: _probe(),
      );
      expect(args, containsAllInOrder(['-i', '/src/video.mp4']));
      expect(args, contains('-vn'));
    });

    test('always includes -progress pipe:1 and -y', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.mp3',
        request: _req(),
        probe: _probe(),
      );
      expect(args, containsAllInOrder(['-progress', 'pipe:1']));
      expect(args, contains('-y'));
    });

    test('uses -c:a copy when source codec matches (aac → aac)', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.aac',
        request: _req(outputFormat: AudioOutputFormat.aac),
        probe: _probe(codecName: 'aac'),
      );
      expect(args, containsAllInOrder(['-c:a', 'copy']));
    });

    test('uses -c:a copy when source codec matches (mp3 → mp3)', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/audio.mp3',
        jobTempPath: '/tmp/out.mp3',
        request: _req(outputFormat: AudioOutputFormat.mp3),
        probe: _probe(codecName: 'mp3', hasVideo: false),
      );
      expect(args, containsAllInOrder(['-c:a', 'copy']));
    });

    test('transcodes when source codec does not match (aac → mp3)', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.mp3',
        request: _req(outputFormat: AudioOutputFormat.mp3),
        probe: _probe(codecName: 'aac'),
      );
      expect(args, containsAllInOrder(['-c:a', 'libmp3lame']));
      expect(args, isNot(containsAllInOrder(['-c:a', 'copy'])));
    });

    test(
      'includes bitrate flag when format supports it and bitrate is set',
      () {
        final args = FfmpegArgsBuilder.build(
          inputPath: '/src/video.mp4',
          jobTempPath: '/tmp/out.mp3',
          request: _req(outputFormat: AudioOutputFormat.mp3, bitRateKbps: 192),
          probe: _probe(codecName: 'aac'),
        );
        expect(args, containsAllInOrder(['-b:a', '192k']));
      },
    );

    test('no -b:a flag for lossless WAV', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.wav',
        request: _req(outputFormat: AudioOutputFormat.wav, bitRateKbps: 320),
        probe: _probe(codecName: 'aac'),
      );
      expect(args, isNot(contains('-b:a')));
    });

    test('includes -ar flag when sampleRate is set', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.mp3',
        request: _req(outputFormat: AudioOutputFormat.mp3, sampleRateHz: 44100),
        probe: _probe(codecName: 'aac'),
      );
      expect(args, containsAllInOrder(['-ar', '44100']));
    });

    test('enforces -ar 48000 for OPUS regardless of sample rate mismatch', () {
      // Source has 44100, request has no sampleRate override, OPUS forces 48000.
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.opus',
        request: _req(outputFormat: AudioOutputFormat.opus),
        probe: _probe(codecName: 'aac', sampleRate: 44100),
      );
      // Should transcode (aac != opus stream copy)
      expect(args, containsAllInOrder(['-ar', '48000']));
    });

    test('does not stream-copy OPUS when sample rate differs', () {
      // Even if source is opus at 44100, 44100 != 48000 so cannot copy.
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/audio.opus',
        jobTempPath: '/tmp/out.opus',
        request: _req(outputFormat: AudioOutputFormat.opus),
        probe: _probe(codecName: 'opus', sampleRate: 44100),
      );
      expect(args, containsAllInOrder(['-c:a', 'libopus']));
    });

    test('mono channels produces -ac 1', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.mp3',
        request: _req(outputFormat: AudioOutputFormat.mp3, channels: 'mono'),
        probe: _probe(codecName: 'aac'),
      );
      expect(args, containsAllInOrder(['-ac', '1']));
    });

    test('stereo channels produces -ac 2', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.mp3',
        request: _req(outputFormat: AudioOutputFormat.mp3, channels: 'stereo'),
        probe: _probe(codecName: 'aac'),
      );
      expect(args, containsAllInOrder(['-ac', '2']));
    });

    test('channel change prevents stream copy', () {
      // AAC → AAC would normally stream copy, but channel change forces transcode.
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.aac',
        request: _req(outputFormat: AudioOutputFormat.aac, channels: 'mono'),
        probe: _probe(codecName: 'aac'),
      );
      expect(args, containsAllInOrder(['-c:a', 'aac']));
    });

    test('M4A includes -f mp4 container flag', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/out.m4a',
        request: _req(outputFormat: AudioOutputFormat.m4a),
        probe: _probe(codecName: 'opus'),
      );
      expect(args, containsAllInOrder(['-f', 'mp4']));
    });

    test('output path is last argument', () {
      final args = FfmpegArgsBuilder.build(
        inputPath: '/src/video.mp4',
        jobTempPath: '/tmp/job123/out.mp3',
        request: _req(),
        probe: _probe(),
      );
      expect(args.last, '/tmp/job123/out.mp3');
    });
  });
}
