/// Output audio format.
enum AudioOutputFormat {
  mp3,
  wav,
  flac,
  aac,
  m4a,
  opus;

  String get extension => switch (this) {
    mp3 => 'mp3',
    wav => 'wav',
    flac => 'flac',
    aac => 'aac',
    m4a => 'm4a',
    opus => 'opus',
  };

  String get label => switch (this) {
    mp3 => 'MP3',
    wav => 'WAV',
    flac => 'FLAC',
    aac => 'AAC',
    m4a => 'M4A',
    opus => 'OPUS',
  };

  /// FFmpeg encoder name.
  String get ffmpegEncoder => switch (this) {
    mp3 => 'libmp3lame',
    wav => 'pcm_s16le',
    flac => 'flac',
    aac => 'aac',
    m4a => 'aac', // AAC codec in an M4A container
    opus => 'libopus',
  };

  bool get isLossless => this == flac || this == wav;

  /// Whether this format uses a bitrate setting.
  bool get supportsBitRate => !isLossless && this != opus;

  /// OPUS requires a specific sample rate set.
  bool get requiresFixedSampleRate => this == opus;

  /// Source audio codec names that allow stream copy into this format.
  Set<String> get streamCopySourceCodecs => switch (this) {
    mp3 => {'mp3'},
    wav => {'pcm_s16le', 'pcm_s16be', 'pcm_u16le'},
    flac => {'flac'},
    aac => {'aac'},
    m4a => {'aac'},
    opus => {'opus'},
  };

  static AudioOutputFormat? fromId(String id) {
    for (final f in values) {
      if (f.name == id) return f;
    }
    return null;
  }
}

/// Preset for an audio output configuration.
class AudioPreset {
  final String id;
  final String label;
  final String description;
  final AudioOutputFormat format;
  final int? bitRateKbps; // null = lossless or format default
  final int? sampleRateHz;
  final String? channels; // 'stereo', 'mono', null = preserve

  const AudioPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.format,
    this.bitRateKbps,
    this.sampleRateHz,
    this.channels,
  });

  static const List<AudioPreset> builtIn = [
    AudioPreset(
      id: 'high_mp3',
      label: 'High Quality MP3',
      description: '320 kbps · 44.1 kHz',
      format: AudioOutputFormat.mp3,
      bitRateKbps: 320,
      sampleRateHz: 44100,
    ),
    AudioPreset(
      id: 'standard_mp3',
      label: 'Standard MP3',
      description: '192 kbps · 44.1 kHz',
      format: AudioOutputFormat.mp3,
      bitRateKbps: 192,
      sampleRateHz: 44100,
    ),
    AudioPreset(
      id: 'wav_edit',
      label: 'WAV (Editing)',
      description: 'Uncompressed PCM · 44.1 kHz · stereo',
      format: AudioOutputFormat.wav,
      sampleRateHz: 44100,
      channels: 'stereo',
    ),
    AudioPreset(
      id: 'flac_lossless',
      label: 'FLAC (Lossless)',
      description: 'Lossless · 44.1 kHz',
      format: AudioOutputFormat.flac,
      sampleRateHz: 44100,
    ),
    AudioPreset(
      id: 'aac_general',
      label: 'AAC (General)',
      description: '256 kbps · 44.1 kHz',
      format: AudioOutputFormat.aac,
      bitRateKbps: 256,
      sampleRateHz: 44100,
    ),
    AudioPreset(
      id: 'm4a_compat',
      label: 'M4A (Compatible)',
      description: '256 kbps AAC in M4A · 44.1 kHz',
      format: AudioOutputFormat.m4a,
      bitRateKbps: 256,
      sampleRateHz: 44100,
    ),
    AudioPreset(
      id: 'opus_compact',
      label: 'OPUS (Compact)',
      description: '128 kbps · 48 kHz',
      format: AudioOutputFormat.opus,
      bitRateKbps: 128,
      sampleRateHz: 48000,
    ),
  ];

  static AudioPreset? findById(String id) {
    for (final p in builtIn) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Default preset for each format.
  static AudioPreset defaultForFormat(AudioOutputFormat fmt) {
    return builtIn.firstWhere(
      (p) => p.format == fmt,
      orElse: () => builtIn.first,
    );
  }

  /// All presets for a given format.
  static List<AudioPreset> forFormat(AudioOutputFormat fmt) =>
      builtIn.where((p) => p.format == fmt).toList();
}
