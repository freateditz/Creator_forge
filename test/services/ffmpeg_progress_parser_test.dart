import 'package:flutter_test/flutter_test.dart';

import 'package:creator_forge/services/audio/ffmpeg_progress_parser.dart';

List<String> _progressGroup({
  String outTimeUs = '30000000', // 30 seconds
  String speed = '2.5x',
  String progress = 'continue',
}) {
  return [
    'frame=100',
    'fps=25.00',
    'stream_0_0_q=-0.0',
    'bitrate=128.0kbits/s',
    'total_size=1234567',
    'out_time_us=$outTimeUs',
    'out_time_ms=30000',
    'out_time=00:00:30.000000',
    'dup_frames=0',
    'drop_frames=0',
    'speed=$speed',
    'progress=$progress',
  ];
}

void main() {
  group('FfmpegProgressParser', () {
    test('returns null for empty lines', () {
      final parser = FfmpegProgressParser();
      expect(parser.parseLine(''), isNull);
      expect(parser.parseLine('   '), isNull);
    });

    test('returns null for lines without =', () {
      final parser = FfmpegProgressParser();
      expect(parser.parseLine('not a key-value pair'), isNull);
    });

    test('returns null for intermediate key=value lines', () {
      final parser = FfmpegProgressParser();
      expect(parser.parseLine('frame=100'), isNull);
      expect(parser.parseLine('out_time_us=30000000'), isNull);
    });

    test('returns ProgressUpdate on progress=continue', () {
      final parser = FfmpegProgressParser();
      ProgressUpdate? update;
      for (final line in _progressGroup()) {
        update = parser.parseLine(line);
      }
      expect(update, isNotNull);
      expect(update!.isDone, isFalse);
    });

    test('returns ProgressUpdate with isDone=true on progress=end', () {
      final parser = FfmpegProgressParser();
      ProgressUpdate? update;
      for (final line in _progressGroup(progress: 'end')) {
        update = parser.parseLine(line);
      }
      expect(update, isNotNull);
      expect(update!.isDone, isTrue);
    });

    test('parses out_time_us correctly', () {
      final parser = FfmpegProgressParser();
      ProgressUpdate? update;
      for (final line in _progressGroup(outTimeUs: '60000000')) {
        update = parser.parseLine(line);
      }
      expect(update?.elapsedMicroseconds, 60000000);
    });

    test('parses speed multiplier correctly', () {
      final parser = FfmpegProgressParser();
      ProgressUpdate? update;
      for (final line in _progressGroup(speed: '1.75x')) {
        update = parser.parseLine(line);
      }
      expect(update?.speed, closeTo(1.75, 0.01));
    });

    test('handles speed=N/A gracefully', () {
      final parser = FfmpegProgressParser();
      ProgressUpdate? update;
      for (final line in _progressGroup(speed: 'N/A')) {
        update = parser.parseLine(line);
      }
      expect(update?.speed, isNull);
    });

    test('fraction() computes correct ratio', () {
      const update = ProgressUpdate(
        elapsedMicroseconds: 30000000, // 30s
        isDone: false,
      );
      expect(update.fraction(120.0), closeTo(0.25, 0.001));
    });

    test('fraction() returns null when totalSeconds is null', () {
      const update = ProgressUpdate(
        elapsedMicroseconds: 30000000,
        isDone: false,
      );
      expect(update.fraction(null), isNull);
    });

    test('fraction() clamps to 1.0', () {
      const update = ProgressUpdate(
        elapsedMicroseconds: 200000000, // 200s
        isDone: false,
      );
      expect(update.fraction(120.0), 1.0);
    });

    test('fraction() returns null when elapsedMicroseconds is null', () {
      const update = ProgressUpdate(isDone: false);
      expect(update.fraction(120.0), isNull);
    });

    test('parser resets after each group', () {
      final parser = FfmpegProgressParser();

      // First group
      for (final line in _progressGroup(outTimeUs: '30000000')) {
        parser.parseLine(line);
      }

      // Second group — should parse fresh
      ProgressUpdate? update;
      for (final line in _progressGroup(outTimeUs: '60000000')) {
        update = parser.parseLine(line);
      }
      expect(update?.elapsedMicroseconds, 60000000);
    });

    test('handles multiple groups emitting updates for each', () {
      final parser = FfmpegProgressParser();
      final updates = <ProgressUpdate>[];

      for (final group in [
        _progressGroup(outTimeUs: '10000000'),
        _progressGroup(outTimeUs: '20000000'),
        _progressGroup(outTimeUs: '30000000', progress: 'end'),
      ]) {
        for (final line in group) {
          final u = parser.parseLine(line);
          if (u != null) updates.add(u);
        }
      }

      expect(updates.length, 3);
      expect(updates[0].elapsedMicroseconds, 10000000);
      expect(updates[1].elapsedMicroseconds, 20000000);
      expect(updates[2].isDone, isTrue);
    });
  });
}
