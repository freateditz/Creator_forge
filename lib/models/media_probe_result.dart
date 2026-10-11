import 'dart:convert';

class AudioStreamInfo {
  final int streamIndex;
  final String codecName;
  final int? sampleRate;
  final int? channels;
  final String? channelLayout;
  final int? bitRateBps;

  const AudioStreamInfo({
    required this.streamIndex,
    required this.codecName,
    this.sampleRate,
    this.channels,
    this.channelLayout,
    this.bitRateBps,
  });

  factory AudioStreamInfo.fromJson(Map<String, dynamic> j, int index) {
    return AudioStreamInfo(
      streamIndex: index,
      codecName: j['codec_name'] as String? ?? '',
      sampleRate: _parseInt(j['sample_rate']),
      channels: j['channels'] as int?,
      channelLayout: j['channel_layout'] as String?,
      bitRateBps: _parseInt(j['bit_rate']),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class MediaProbeResult {
  final String path;
  final double? durationSeconds;
  final List<AudioStreamInfo> audioStreams;
  final bool hasVideo;
  final int? fileSizeBytes;

  const MediaProbeResult({
    required this.path,
    this.durationSeconds,
    required this.audioStreams,
    required this.hasVideo,
    this.fileSizeBytes,
  });

  bool get hasAudio => audioStreams.isNotEmpty;
  AudioStreamInfo? get firstAudio =>
      audioStreams.isNotEmpty ? audioStreams.first : null;

  factory MediaProbeResult.fromJson(
    Map<String, dynamic> json, {
    required String path,
  }) {
    final streams = json['streams'] as List<dynamic>? ?? [];
    final format = json['format'] as Map<String, dynamic>? ?? {};

    final audioStreams = streams
        .cast<Map<String, dynamic>>()
        .where((s) => s['codec_type'] == 'audio')
        .toList()
        .asMap()
        .entries
        .map((e) => AudioStreamInfo.fromJson(e.value, e.key))
        .toList();

    final hasVideo = streams.cast<Map<String, dynamic>>().any(
      (s) => s['codec_type'] == 'video',
    );

    final durStr = format['duration'] as String?;
    final durationSeconds = durStr != null ? double.tryParse(durStr) : null;
    final sizeStr = format['size'] as String?;
    final fileSizeBytes = sizeStr != null ? int.tryParse(sizeStr) : null;

    return MediaProbeResult(
      path: path,
      durationSeconds: durationSeconds,
      audioStreams: audioStreams,
      hasVideo: hasVideo,
      fileSizeBytes: fileSizeBytes,
    );
  }

  // Convenience: parse from the raw ffprobe JSON string.
  factory MediaProbeResult.fromRawJson(String raw, {required String path}) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return MediaProbeResult.fromJson(json, path: path);
  }
}
