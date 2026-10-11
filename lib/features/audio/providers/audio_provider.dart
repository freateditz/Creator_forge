import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/audio_format.dart';
import '../../../models/audio_request.dart';
import '../../../models/media_probe_result.dart';
import '../../../services/ffmpeg/ffmpeg_service.dart';
import '../../../providers/app_providers.dart';

enum AudioTab { extract, convert, batch }

class AudioScreenState {
  final AudioTab activeTab;
  final List<String> selectedFiles;
  final Map<String, MediaProbeResult> probeCache;
  final AudioOutputFormat outputFormat;
  final String? presetId;
  final int? customBitRateKbps;
  final int? customSampleRateHz;
  final String? customChannels;
  final String? outputDirectory;
  final bool isProbing;

  const AudioScreenState({
    this.activeTab = AudioTab.extract,
    this.selectedFiles = const [],
    this.probeCache = const {},
    this.outputFormat = AudioOutputFormat.mp3,
    this.presetId,
    this.customBitRateKbps,
    this.customSampleRateHz,
    this.customChannels,
    this.outputDirectory,
    this.isProbing = false,
  });

  AudioScreenState copyWith({
    AudioTab? activeTab,
    List<String>? selectedFiles,
    Map<String, MediaProbeResult>? probeCache,
    AudioOutputFormat? outputFormat,
    String? presetId,
    int? customBitRateKbps,
    int? customSampleRateHz,
    String? customChannels,
    String? outputDirectory,
    bool? isProbing,
    bool clearPreset = false,
    bool clearBitRate = false,
    bool clearSampleRate = false,
    bool clearChannels = false,
  }) {
    return AudioScreenState(
      activeTab: activeTab ?? this.activeTab,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      probeCache: probeCache ?? this.probeCache,
      outputFormat: outputFormat ?? this.outputFormat,
      presetId: clearPreset ? null : (presetId ?? this.presetId),
      customBitRateKbps: clearBitRate
          ? null
          : (customBitRateKbps ?? this.customBitRateKbps),
      customSampleRateHz: clearSampleRate
          ? null
          : (customSampleRateHz ?? this.customSampleRateHz),
      customChannels: clearChannels
          ? null
          : (customChannels ?? this.customChannels),
      outputDirectory: outputDirectory ?? this.outputDirectory,
      isProbing: isProbing ?? this.isProbing,
    );
  }

  AudioRequest buildRequest() {
    return AudioRequest(
      operation: activeTab == AudioTab.extract
          ? AudioOperation.extract
          : AudioOperation.convert,
      outputFormat: outputFormat,
      presetId: presetId,
      bitRateKbps: customBitRateKbps,
      sampleRateHz: customSampleRateHz,
      channels: customChannels,
      outputDirectory: outputDirectory ?? _defaultDir(),
    );
  }

  static String _defaultDir() {
    if (Platform.isWindows) {
      return '${Platform.environment['USERPROFILE'] ?? 'C:\\Users\\User'}\\Music\\CreatorForge';
    }
    return '${Platform.environment['HOME'] ?? '.'}/Music/CreatorForge';
  }
}

class AudioScreenNotifier extends Notifier<AudioScreenState> {
  @override
  AudioScreenState build() => const AudioScreenState();

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);

  void setTab(AudioTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setOutputFormat(AudioOutputFormat fmt) {
    // Auto-select the default preset for the chosen format.
    final defaultPreset = AudioPreset.defaultForFormat(fmt);
    state = state.copyWith(
      outputFormat: fmt,
      presetId: defaultPreset.id,
      clearBitRate: true,
      clearSampleRate: true,
      clearChannels: true,
    );
  }

  void setPreset(String? presetId) {
    state = state.copyWith(
      presetId: presetId,
      clearBitRate: true,
      clearSampleRate: true,
      clearChannels: true,
    );
  }

  void setCustomBitRate(int? kbps) {
    state = state.copyWith(customBitRateKbps: kbps, clearPreset: kbps != null);
  }

  void setCustomSampleRate(int? hz) {
    state = state.copyWith(customSampleRateHz: hz, clearPreset: hz != null);
  }

  void setCustomChannels(String? channels) {
    state = state.copyWith(
      customChannels: channels,
      clearPreset: channels != null,
    );
  }

  void setOutputDirectory(String dir) {
    state = state.copyWith(outputDirectory: dir);
  }

  Future<void> addFiles(List<String> paths) async {
    final existing = Set<String>.from(state.selectedFiles);
    final newPaths = paths.where((p) => !existing.contains(p)).toList();
    if (newPaths.isEmpty) return;

    state = state.copyWith(
      selectedFiles: [...state.selectedFiles, ...newPaths],
      isProbing: true,
    );

    final updated = Map<String, MediaProbeResult>.from(state.probeCache);
    for (final path in newPaths) {
      try {
        final result = await _ffmpeg.probeMedia(path);
        updated[path] = result;
      } catch (_) {
        // Probe failure is not fatal — UI will show unknown duration.
      }
    }

    state = state.copyWith(probeCache: updated, isProbing: false);
  }

  void removeFile(String path) {
    final files = List<String>.from(state.selectedFiles)..remove(path);
    final cache = Map<String, MediaProbeResult>.from(state.probeCache)
      ..remove(path);
    state = state.copyWith(selectedFiles: files, probeCache: cache);
  }

  void clearFiles() {
    state = state.copyWith(selectedFiles: [], probeCache: {});
  }
}

final audioScreenProvider =
    NotifierProvider<AudioScreenNotifier, AudioScreenState>(
      AudioScreenNotifier.new,
    );
