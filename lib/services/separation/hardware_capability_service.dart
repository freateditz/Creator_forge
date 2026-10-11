import 'dart:convert';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import 'demucs_progress_parser.dart';
import 'runtime_manager.dart';

class HardwareInfo {
  final bool mpsAvailable;
  final bool cudaAvailable;
  final int cudaDeviceCount;
  final String demucsVersion;
  final String torchVersion;

  const HardwareInfo({
    required this.mpsAvailable,
    required this.cudaAvailable,
    required this.cudaDeviceCount,
    required this.demucsVersion,
    required this.torchVersion,
  });

  static const unavailable = HardwareInfo(
    mpsAvailable: false,
    cudaAvailable: false,
    cudaDeviceCount: 0,
    demucsVersion: '',
    torchVersion: '',
  );

  bool get hasGpu => mpsAvailable || cudaAvailable;

  String get bestDevice {
    if (mpsAvailable) return 'mps';
    if (cudaAvailable) return 'cuda';
    return 'cpu';
  }
}

/// Queries the demucs worker for hardware accelerator availability.
class HardwareCapabilityService {
  final RuntimeManager _runtime;
  final _log = AppLogger.get('HardwareCapabilityService');
  final _parser = DemucsProgressParser();

  HardwareCapabilityService(this._runtime);

  /// Returns [HardwareInfo.unavailable] if the runtime is not installed
  /// or the check fails.
  Future<HardwareInfo> check() async {
    try {
      final process = await _runtime.startWorker(
        command: {'action': 'check_runtime'},
      );

      RuntimeInfoEvent? info;
      await for (final line
          in process.stdout
              .transform(const SystemEncoding().decoder)
              .transform(const LineSplitter())) {
        final event = _parser.parseLine(line);
        if (event is RuntimeInfoEvent) info = event;
      }

      await process.exitCode;

      if (info == null) return HardwareInfo.unavailable;

      return HardwareInfo(
        mpsAvailable: info.mpsAvailable,
        cudaAvailable: info.cudaAvailable,
        cudaDeviceCount: info.cudaDeviceCount,
        demucsVersion: info.demucsVersion,
        torchVersion: info.torchVersion,
      );
    } catch (e) {
      _log.warning('Hardware check failed.', e);
      return HardwareInfo.unavailable;
    }
  }
}
