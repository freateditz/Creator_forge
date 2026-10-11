class MediaFormat {
  final String formatId;
  final String ext;
  final int? width;
  final int? height;
  final double? fps;
  final String? vcodec;
  final String? acodec;
  final int? fileSizeBytes;
  final int? fileSizeApproxBytes;
  final double? totalBitrateKbps;
  final double? audioBitrateKbps;
  final double? videoBitrateKbps;
  final String? dynamicRange;
  final String? formatNote;

  const MediaFormat({
    required this.formatId,
    required this.ext,
    this.width,
    this.height,
    this.fps,
    this.vcodec,
    this.acodec,
    this.fileSizeBytes,
    this.fileSizeApproxBytes,
    this.totalBitrateKbps,
    this.audioBitrateKbps,
    this.videoBitrateKbps,
    this.dynamicRange,
    this.formatNote,
  });

  bool get hasVideo => vcodec != null && vcodec != 'none';
  bool get hasAudio => acodec != null && acodec != 'none';
  bool get isVideoOnly => hasVideo && !hasAudio;
  bool get isAudioOnly => hasAudio && !hasVideo;
  bool get isMuxed => hasVideo && hasAudio;

  int? get effectiveSizeBytes => fileSizeBytes ?? fileSizeApproxBytes;

  bool get isHdr =>
      dynamicRange != null && dynamicRange != 'SDR' && dynamicRange!.isNotEmpty;

  String? get resolution {
    if (height != null && width != null) return '${width}x$height';
    if (height != null) return '${height}p';
    return null;
  }

  String get displayLabel {
    if (isAudioOnly) {
      final br = audioBitrateKbps;
      return br != null ? '${br.round()}kbps audio' : 'Audio';
    }
    final h = height;
    if (h != null) {
      final hdr = isHdr ? ' HDR' : '';
      final fpsStr = fps != null && fps! > 30 ? ' ${fps!.round()}fps' : '';
      return '${h}p$fpsStr$hdr ${ext.toUpperCase()}';
    }
    return '$ext ${formatNote ?? formatId}';
  }

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    return MediaFormat(
      formatId: json['format_id'] as String? ?? '',
      ext: json['ext'] as String? ?? '',
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      fps: _toDouble(json['fps']),
      vcodec: json['vcodec'] as String?,
      acodec: json['acodec'] as String?,
      fileSizeBytes: _toInt(json['filesize']),
      fileSizeApproxBytes: _toInt(json['filesize_approx']),
      totalBitrateKbps: _toDouble(json['tbr']),
      audioBitrateKbps: _toDouble(json['abr']),
      videoBitrateKbps: _toDouble(json['vbr']),
      dynamicRange: json['dynamic_range'] as String?,
      formatNote: json['format_note'] as String?,
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class MediaInfo {
  final String url;
  final String? videoId;
  final String title;
  final String? thumbnailUrl;
  final String? uploaderName;
  final int? durationSeconds;
  final List<MediaFormat> formats;
  final DateTime resolvedAt;

  const MediaInfo({
    required this.url,
    this.videoId,
    required this.title,
    this.thumbnailUrl,
    this.uploaderName,
    this.durationSeconds,
    required this.formats,
    required this.resolvedAt,
  });

  List<MediaFormat> get videoFormats =>
      formats.where((f) => f.hasVideo).toList();

  List<MediaFormat> get audioFormats =>
      formats.where((f) => f.isAudioOnly).toList();

  int? get maxVideoHeight => videoFormats
      .map((f) => f.height)
      .whereType<int>()
      .fold<int?>(null, (m, h) => m == null || h > m ? h : m);

  Set<int> get availableVideoHeights =>
      videoFormats.map((f) => f.height).whereType<int>().toSet();

  List<QualityOption> get availableQualityOptions {
    final heights = availableVideoHeights;
    const standardHeights = [2160, 1440, 1080, 720, 480, 360];
    final hasAudio =
        audioFormats.isNotEmpty || formats.any((f) => f.isMuxed && f.hasAudio);

    return [
      QualityOption.best,
      for (final h in standardHeights)
        QualityOption.forHeight(
          h,
          available: heights.any((avail) => avail >= h),
        ),
      if (hasAudio || formats.isNotEmpty) QualityOption.audioOnly,
    ];
  }

  factory MediaInfo.fromJson(Map<String, dynamic> json, {required String url}) {
    final rawFormats = json['formats'] as List<dynamic>? ?? [];
    final formats = rawFormats
        .whereType<Map<String, dynamic>>()
        .map(MediaFormat.fromJson)
        .toList();

    // Pick best thumbnail (last in array tends to be highest quality for most extractors)
    String? thumbnail = json['thumbnail'] as String?;
    final thumbnails = json['thumbnails'] as List<dynamic>?;
    if (thumbnail == null && thumbnails != null && thumbnails.isNotEmpty) {
      final last = thumbnails.last;
      if (last is Map<String, dynamic>) {
        thumbnail = last['url'] as String?;
      }
    }

    final duration = json['duration'];

    return MediaInfo(
      url: url,
      videoId: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      thumbnailUrl: thumbnail,
      uploaderName: json['uploader'] as String? ?? json['channel'] as String?,
      durationSeconds: duration is num ? duration.round() : null,
      formats: formats,
      resolvedAt: DateTime.now(),
    );
  }
}

enum QualityPreset {
  best,
  q2160p,
  q1440p,
  q1080p,
  q720p,
  q480p,
  q360p,
  audioOnly,
}

class QualityOption {
  final QualityPreset preset;
  final String label;
  final String formatSelector;
  final bool available;

  const QualityOption._({
    required this.preset,
    required this.label,
    required this.formatSelector,
    this.available = true,
  });

  static const best = QualityOption._(
    preset: QualityPreset.best,
    label: 'Best available',
    formatSelector:
        'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
  );

  static const audioOnly = QualityOption._(
    preset: QualityPreset.audioOnly,
    label: 'Audio only',
    formatSelector: 'bestaudio[ext=m4a]/bestaudio[ext=mp4]/bestaudio',
  );

  static QualityOption forHeight(int height, {bool available = true}) {
    const labels = {
      2160: '2160p (4K)',
      1440: '1440p (2K)',
      1080: '1080p',
      720: '720p',
      480: '480p',
      360: '360p',
    };
    const presets = {
      2160: QualityPreset.q2160p,
      1440: QualityPreset.q1440p,
      1080: QualityPreset.q1080p,
      720: QualityPreset.q720p,
      480: QualityPreset.q480p,
      360: QualityPreset.q360p,
    };
    return QualityOption._(
      preset: presets[height] ?? QualityPreset.best,
      label: labels[height] ?? '${height}p',
      formatSelector:
          'bestvideo[height<=$height][ext=mp4]+bestaudio[ext=m4a]/'
          'bestvideo[height<=$height]+bestaudio/'
          'best[height<=$height]',
      available: available,
    );
  }

  String get audioFormatSelector =>
      'bestaudio[ext=m4a]/bestaudio[ext=mp4]/bestaudio';
}
