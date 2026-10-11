import 'audio_format.dart';

enum AudioOperation { extract, convert }

/// Describes one audio processing task for a single input file.
class AudioRequest {
  final AudioOperation operation;
  final AudioOutputFormat outputFormat;
  final String? presetId;
  final int? bitRateKbps;
  final int? sampleRateHz;
  final String? channels; // 'stereo', 'mono', null = preserve
  final String outputDirectory;

  const AudioRequest({
    required this.operation,
    required this.outputFormat,
    this.presetId,
    this.bitRateKbps,
    this.sampleRateHz,
    this.channels,
    required this.outputDirectory,
  });

  /// Effective bitrate: custom override → preset → null.
  int? get effectiveBitRateKbps {
    if (bitRateKbps != null) return bitRateKbps;
    if (presetId != null) return AudioPreset.findById(presetId!)?.bitRateKbps;
    return null;
  }

  /// Effective sample rate: custom override → preset → null.
  int? get effectiveSampleRateHz {
    // OPUS requires 48000 Hz regardless.
    if (outputFormat == AudioOutputFormat.opus) return 48000;
    if (sampleRateHz != null) return sampleRateHz;
    if (presetId != null) return AudioPreset.findById(presetId!)?.sampleRateHz;
    return null;
  }

  /// Effective channel config: custom → preset → null.
  String? get effectiveChannels {
    if (channels != null) return channels;
    if (presetId != null) return AudioPreset.findById(presetId!)?.channels;
    return null;
  }

  /// Serialise to the ProcessingJob.params map (stored as JSON in DB).
  Map<String, dynamic> toParams() => {
    'operation': operation.name,
    'outputFormat': outputFormat.name,
    if (presetId != null) 'presetId': presetId,
    if (bitRateKbps != null) 'bitRateKbps': bitRateKbps,
    if (sampleRateHz != null) 'sampleRateHz': sampleRateHz,
    if (channels != null) 'channels': channels,
    'outputDirectory': outputDirectory,
  };

  factory AudioRequest.fromParams(Map<String, dynamic> params) {
    return AudioRequest(
      operation: AudioOperation.values.firstWhere(
        (o) => o.name == params['operation'],
        orElse: () => AudioOperation.extract,
      ),
      outputFormat:
          AudioOutputFormat.fromId(params['outputFormat'] as String? ?? '') ??
          AudioOutputFormat.mp3,
      presetId: params['presetId'] as String?,
      bitRateKbps: params['bitRateKbps'] as int?,
      sampleRateHz: params['sampleRateHz'] as int?,
      channels: params['channels'] as String?,
      outputDirectory: params['outputDirectory'] as String? ?? '',
    );
  }
}
