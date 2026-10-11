import '../../models/audio_format.dart';
import '../../models/audio_request.dart';
import '../../models/media_probe_result.dart';

/// Builds FFmpeg argument lists for audio extraction and conversion.
///
/// All args are produced as an explicit `List<String>` — never concatenated
/// into a shell string — so they are safe to pass to Process.start().
class FfmpegArgsBuilder {
  FfmpegArgsBuilder._();

  /// Returns the FFmpeg args for processing one audio job.
  ///
  /// [probe] is required so we can decide whether stream copy is viable.
  /// [jobTempPath] is a temp-directory-scoped output path; the caller moves
  /// it to the final destination only after verifying success.
  static List<String> build({
    required String inputPath,
    required String jobTempPath,
    required AudioRequest request,
    required MediaProbeResult probe,
  }) {
    final canCopy = _canStreamCopy(probe, request);

    return [
      '-i', inputPath,

      // Strip video for extraction; for conversion it's already audio-only
      // but keep -vn to be safe with container streams.
      '-vn',

      if (canCopy) ...[
        '-c:a',
        'copy',
      ] else ...[
        '-c:a',
        request.outputFormat.ffmpegEncoder,
        ..._bitrateArgs(request),
        ..._sampleRateArgs(request),
        ..._channelArgs(request),
      ],

      // M4A requires the mp4 container explicitly.
      if (request.outputFormat == AudioOutputFormat.m4a) ...['-f', 'mp4'],

      // Machine-readable progress to stdout, parsed by FfmpegProgressParser.
      '-progress', 'pipe:1',

      // Never prompt; overwrite temp file if it somehow exists.
      '-y',

      jobTempPath,
    ];
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static bool _canStreamCopy(MediaProbeResult probe, AudioRequest request) {
    final src = probe.firstAudio;
    if (src == null) return false;
    // WAV lossless formats have multiple codec variants; only copy if exact.
    if (!request.outputFormat.streamCopySourceCodecs.contains(src.codecName)) {
      return false;
    }
    // If the request specifies sample-rate or channel changes, we must transcode.
    final targetRate = request.effectiveSampleRateHz;
    if (targetRate != null && targetRate != src.sampleRate) return false;
    final targetChannels = request.effectiveChannels;
    if (targetChannels != null) return false;
    return true;
  }

  static List<String> _bitrateArgs(AudioRequest request) {
    final fmt = request.outputFormat;
    if (!fmt.supportsBitRate) return const [];
    final kbps = request.effectiveBitRateKbps;
    if (kbps == null) return const [];
    return ['-b:a', '${kbps}k'];
  }

  static List<String> _sampleRateArgs(AudioRequest request) {
    final hz = request.effectiveSampleRateHz;
    if (hz == null) return const [];
    return ['-ar', '$hz'];
  }

  static List<String> _channelArgs(AudioRequest request) {
    final ch = request.effectiveChannels;
    if (ch == null) return const [];
    return switch (ch) {
      'mono' => ['-ac', '1'],
      'stereo' => ['-ac', '2'],
      _ => const [],
    };
  }
}
