class DownloadProgress {
  final double percent;
  final int? totalBytes;
  final int? downloadedBytes;
  final int? speedBps;
  final int? etaSeconds;

  const DownloadProgress({
    required this.percent,
    this.totalBytes,
    this.downloadedBytes,
    this.speedBps,
    this.etaSeconds,
  });
}

// Parses yt-dlp progress output lines.
// Standard format with --newline:
//   [download]  23.4% of  100.00MiB at    5.00MiB/s ETA 00:16
//   [download] 100.0% of  100.00MiB in 00:00:10 at   10.00MiB/s
//   [download] Destination: /path/to/file.mp4
//   [Merger] Merging formats into "/path/to/file.mp4"
//   ERROR: ...
class DownloadProgressParser {
  DownloadProgressParser._();

  static final _progressRe = RegExp(
    r'\[download\]\s+([\d.]+)%\s+of\s+~?\s*([\d.]+)'
    r'(B|KiB|MiB|GiB|TiB)\s+at\s+([\d.]+|Unknown)\s*'
    r'(B|KiB|MiB|GiB|TiB)?/s\s+ETA\s+(\S+)',
    caseSensitive: false,
  );

  static final _destinationRe = RegExp(r'\[download\]\s+Destination:\s+(.+)');

  static final _mergerRe = RegExp(
    r'\[(?:Merger|VideoRemuxer)\]\s+Merging formats into\s+"(.+)"',
  );

  static final _errorRe = RegExp(r'^ERROR:\s+(.+)', multiLine: false);

  static DownloadProgress? parseProgress(String line) {
    final m = _progressRe.firstMatch(line);
    if (m == null) return null;

    final percent = double.tryParse(m.group(1) ?? '') ?? 0.0;
    final totalSize = double.tryParse(m.group(2) ?? '') ?? 0.0;
    final totalUnit = m.group(3) ?? 'B';
    final speedStr = m.group(4) ?? 'Unknown';
    final speedUnit = m.group(5) ?? 'B';
    final etaStr = m.group(6) ?? 'Unknown';

    final totalBytes = _parseSize(totalSize, totalUnit);
    final downloadedBytes = totalBytes != null
        ? ((percent / 100.0) * totalBytes).round()
        : null;
    final speedBps = speedStr != 'Unknown'
        ? _parseSize(double.tryParse(speedStr) ?? 0.0, speedUnit)
        : null;
    final etaSeconds = _parseEta(etaStr);

    return DownloadProgress(
      percent: (percent / 100.0).clamp(0.0, 1.0),
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      speedBps: speedBps,
      etaSeconds: etaSeconds,
    );
  }

  static String? parseDestination(String line) {
    final dm = _destinationRe.firstMatch(line);
    if (dm != null) return dm.group(1)?.trim();
    final mm = _mergerRe.firstMatch(line);
    return mm?.group(1)?.trim();
  }

  static String? parseError(String line) {
    final m = _errorRe.firstMatch(line);
    return m?.group(1)?.trim();
  }

  static bool isMerging(String line) =>
      line.contains('[Merger]') || line.contains('[VideoRemuxer]');

  static int? _parseSize(double value, String unit) {
    final multiplier = switch (unit.toUpperCase()) {
      'KIB' => 1024,
      'MIB' => 1024 * 1024,
      'GIB' => 1024 * 1024 * 1024,
      'TIB' => 1024 * 1024 * 1024 * 1024,
      _ => 1,
    };
    final result = (value * multiplier).round();
    return result > 0 ? result : null;
  }

  static int? _parseEta(String etaStr) {
    if (etaStr == 'Unknown' || etaStr == '--') return null;
    final parts = etaStr.split(':').map(int.tryParse).toList();
    return switch (parts.length) {
      2 => parts.every((p) => p != null) ? parts[0]! * 60 + parts[1]! : null,
      3 =>
        parts.every((p) => p != null)
            ? parts[0]! * 3600 + parts[1]! * 60 + parts[2]!
            : null,
      _ => null,
    };
  }
}
