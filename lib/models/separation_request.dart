import 'dart:convert';

enum SeparationMode {
  /// Produce Vocals.wav + Instrumental.wav only.
  voicePlusInstrumental,

  /// Produce individual stems (drums, bass, other, vocals) plus Instrumental.
  allStems,
}

enum SeparationDevice {
  /// Select the best available hardware automatically.
  auto,
  cpu,
  mps,
  cuda,
}

class SeparationRequest {
  final String modelName;
  final SeparationMode mode;
  final SeparationDevice device;

  /// Absolute path to the output directory.
  final String outputDirectory;

  const SeparationRequest({
    this.modelName = 'htdemucs',
    this.mode = SeparationMode.voicePlusInstrumental,
    this.device = SeparationDevice.auto,
    required this.outputDirectory,
  });

  SeparationRequest copyWith({
    String? modelName,
    SeparationMode? mode,
    SeparationDevice? device,
    String? outputDirectory,
  }) {
    return SeparationRequest(
      modelName: modelName ?? this.modelName,
      mode: mode ?? this.mode,
      device: device ?? this.device,
      outputDirectory: outputDirectory ?? this.outputDirectory,
    );
  }

  Map<String, dynamic> toJson() => {
    'modelName': modelName,
    'mode': mode.name,
    'device': device.name,
    'outputDirectory': outputDirectory,
  };

  factory SeparationRequest.fromJson(Map<String, dynamic> json) {
    return SeparationRequest(
      modelName: json['modelName'] as String? ?? 'htdemucs',
      mode: SeparationMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => SeparationMode.voicePlusInstrumental,
      ),
      device: SeparationDevice.values.firstWhere(
        (e) => e.name == json['device'],
        orElse: () => SeparationDevice.auto,
      ),
      outputDirectory: json['outputDirectory'] as String? ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      'SeparationRequest(model=$modelName, mode=${mode.name}, device=${device.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeparationRequest &&
          modelName == other.modelName &&
          mode == other.mode &&
          device == other.device &&
          outputDirectory == other.outputDirectory;

  @override
  int get hashCode => Object.hash(modelName, mode, device, outputDirectory);
}
