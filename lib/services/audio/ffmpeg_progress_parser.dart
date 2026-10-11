/// Stateful parser for FFmpeg's `-progress pipe:1` stdout stream.
///
/// FFmpeg emits groups of key=value lines terminated by `progress=continue`
/// or `progress=end`. We accumulate each group and emit a [ProgressUpdate]
/// when the group is complete.
class FfmpegProgressParser {
  final Map<String, String> _current = {};

  /// Call with each line from FFmpeg stdout.
  /// Returns a [ProgressUpdate] when a complete group has been received,
  /// otherwise null.
  ProgressUpdate? parseLine(String line) {
    line = line.trim();
    if (line.isEmpty) return null;

    final eq = line.indexOf('=');
    if (eq < 0) return null;

    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    _current[key] = value;

    if (key == 'progress') {
      final update = _build(value == 'end');
      _current.clear();
      return update;
    }
    return null;
  }

  ProgressUpdate _build(bool done) {
    final outTimeUs = _parseInt(_current['out_time_us']);
    final speed = _parseSpeed(_current['speed']);
    return ProgressUpdate(
      elapsedMicroseconds: outTimeUs,
      speed: speed,
      isDone: done,
    );
  }

  static int? _parseInt(String? v) {
    if (v == null) return null;
    return int.tryParse(v);
  }

  static double? _parseSpeed(String? v) {
    if (v == null || v == 'N/A') return null;
    // Value is like "1.23x"
    return double.tryParse(v.replaceAll('x', ''));
  }
}

class ProgressUpdate {
  /// Elapsed output time in microseconds (from out_time_us).
  final int? elapsedMicroseconds;

  /// Playback-speed multiplier (e.g. 2.5 means processing at 2.5× realtime).
  final double? speed;

  final bool isDone;

  const ProgressUpdate({
    this.elapsedMicroseconds,
    this.speed,
    required this.isDone,
  });

  /// Progress fraction [0.0, 1.0] given total duration.
  /// Returns null if either value is unavailable.
  double? fraction(double? totalSeconds) {
    if (totalSeconds == null || totalSeconds <= 0) return null;
    final us = elapsedMicroseconds;
    if (us == null) return null;
    return (us / 1e6 / totalSeconds).clamp(0.0, 1.0);
  }
}
