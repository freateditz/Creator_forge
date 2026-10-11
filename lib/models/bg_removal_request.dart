import 'dart:convert';

enum BgRemovalModel {
  isnetGeneralUse(
    'isnet-general-use',
    'IS-Net General Use',
    '~177 MB',
    'Best quality; hair, fur, and fine details.',
  ),
  u2net('u2net', 'U2-Net', '~176 MB', 'Good general-purpose quality.'),
  u2netp('u2netp', 'U2-Net Lite', '~4 MB', 'Fastest; lower quality.'),
  silueta('silueta', 'Silueta', '~44 MB', 'Fast with decent quality.');

  final String id;
  final String displayName;
  final String sizeLabel;
  final String description;

  const BgRemovalModel(
    this.id,
    this.displayName,
    this.sizeLabel,
    this.description,
  );

  static BgRemovalModel fromId(String id) => BgRemovalModel.values.firstWhere(
    (m) => m.id == id,
    orElse: () => BgRemovalModel.isnetGeneralUse,
  );
}

class BgRemovalRequest {
  final BgRemovalModel model;
  final String outputDirectory;
  final bool alphaMatting;
  final int alphaMattingFgThreshold;
  final int alphaMattingBgThreshold;
  final int alphaMattingErodeSize;
  final bool postProcessMask;

  const BgRemovalRequest({
    this.model = BgRemovalModel.isnetGeneralUse,
    required this.outputDirectory,
    this.alphaMatting = false,
    this.alphaMattingFgThreshold = 240,
    this.alphaMattingBgThreshold = 10,
    this.alphaMattingErodeSize = 10,
    this.postProcessMask = false,
  });

  BgRemovalRequest copyWith({
    BgRemovalModel? model,
    String? outputDirectory,
    bool? alphaMatting,
    int? alphaMattingFgThreshold,
    int? alphaMattingBgThreshold,
    int? alphaMattingErodeSize,
    bool? postProcessMask,
  }) => BgRemovalRequest(
    model: model ?? this.model,
    outputDirectory: outputDirectory ?? this.outputDirectory,
    alphaMatting: alphaMatting ?? this.alphaMatting,
    alphaMattingFgThreshold:
        alphaMattingFgThreshold ?? this.alphaMattingFgThreshold,
    alphaMattingBgThreshold:
        alphaMattingBgThreshold ?? this.alphaMattingBgThreshold,
    alphaMattingErodeSize: alphaMattingErodeSize ?? this.alphaMattingErodeSize,
    postProcessMask: postProcessMask ?? this.postProcessMask,
  );

  Map<String, dynamic> toJson() => {
    'model': model.id,
    'outputDirectory': outputDirectory,
    'alphaMatting': alphaMatting,
    'alphaMattingFgThreshold': alphaMattingFgThreshold,
    'alphaMattingBgThreshold': alphaMattingBgThreshold,
    'alphaMattingErodeSize': alphaMattingErodeSize,
    'postProcessMask': postProcessMask,
  };

  factory BgRemovalRequest.fromJson(Map<String, dynamic> json) =>
      BgRemovalRequest(
        model: BgRemovalModel.fromId(json['model'] as String? ?? ''),
        outputDirectory: json['outputDirectory'] as String? ?? '',
        alphaMatting: json['alphaMatting'] as bool? ?? false,
        alphaMattingFgThreshold: json['alphaMattingFgThreshold'] as int? ?? 240,
        alphaMattingBgThreshold: json['alphaMattingBgThreshold'] as int? ?? 10,
        alphaMattingErodeSize: json['alphaMattingErodeSize'] as int? ?? 10,
        postProcessMask: json['postProcessMask'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BgRemovalRequest &&
          model == other.model &&
          outputDirectory == other.outputDirectory &&
          alphaMatting == other.alphaMatting &&
          alphaMattingFgThreshold == other.alphaMattingFgThreshold &&
          alphaMattingBgThreshold == other.alphaMattingBgThreshold &&
          alphaMattingErodeSize == other.alphaMattingErodeSize &&
          postProcessMask == other.postProcessMask;

  @override
  int get hashCode => Object.hash(
    model,
    outputDirectory,
    alphaMatting,
    alphaMattingFgThreshold,
    alphaMattingBgThreshold,
    alphaMattingErodeSize,
    postProcessMask,
  );
}
