import 'dart:math' as math;
import '../../core/logging/app_logger.dart';

enum DownloadProfile {
  balanced,
  fast,
  maximum,
}

class AdaptiveConcurrencyController {
  final String taskId;
  final DownloadProfile profile;
  final _log = AppLogger.get('AdaptiveConcurrency');

  final int _currentSegments;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureAt;
  
  // smoothed throughput metrics
  double _emaThroughput = 0.0;
  final double _alpha = 0.2; // smoothing factor

  AdaptiveConcurrencyController({
    required this.taskId,
    this.profile = DownloadProfile.balanced,
  }) : _currentSegments = _initialSegments(profile);

  static int _initialSegments(DownloadProfile p) => switch (p) {
    DownloadProfile.balanced => 4,
    DownloadProfile.fast => 8,
    DownloadProfile.maximum => 12,
  };

  int get currentSegments => _currentSegments;

  void reportProgress(int bytes, Duration delta) {
    if (delta.inMilliseconds == 0) return;
    final instantThroughput = bytes / (delta.inMilliseconds / 1000.0);
    
    if (_emaThroughput == 0.0) {
      _emaThroughput = instantThroughput;
    } else {
      _emaThroughput = (_alpha * instantThroughput) + ((1 - _alpha) * _emaThroughput);
    }

    // Heuristic: if throughput is stable and high, and we aren't at max, potentially increase.
    // Simplifying: we won't dynamically change segment COUNT during a running download 
    // because that would require re-splitting the remaining ranges which is complex.
    // Instead, "Adaptive Concurrency" in 1.2 will focus on connection slot allocation 
    // and backoff, rather than re-sharding the file.
  }

  void reportFailure() {
    _consecutiveFailures++;
    _lastFailureAt = DateTime.now();
    _log.warning('Task $taskId reported failure. Consecutive: $_consecutiveFailures');
  }

  void reportSuccess() {
    _consecutiveFailures = 0;
  }

  Duration get retryDelay {
    if (_consecutiveFailures == 0) return Duration.zero;
    // Exponential backoff: 2s, 4s, 8s, 16s... up to 1 min
    final seconds = math.min(math.pow(2, _consecutiveFailures).toInt(), 60);
    return Duration(seconds: seconds);
  }

  bool get shouldBackoff {
    if (_lastFailureAt == null) return false;
    // If we had a 429/503 recently, wait.
    return DateTime.now().difference(_lastFailureAt!) < retryDelay;
  }
}
