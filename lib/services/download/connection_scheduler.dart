import 'dart:async';
import 'dart:collection';

import '../../core/logging/app_logger.dart';

class ConnectionSlot {
  final String taskId;
  final int segmentIndex;
  final String host;
  final DateTime acquiredAt;

  ConnectionSlot({
    required this.taskId,
    required this.segmentIndex,
    required this.host,
  }) : acquiredAt = DateTime.now();
}

class GlobalConnectionScheduler {
  static final GlobalConnectionScheduler instance = GlobalConnectionScheduler._();
  GlobalConnectionScheduler._();

  final _log = AppLogger.get('GlobalConnectionScheduler');

  int _maxGlobalConnections = 16;
  int _maxPerHostConnections = 8;
  int _maxPerDownloadConnections = 8;

  final _activeSlots = <ConnectionSlot>[];
  final _waitingSegments = Queue<(_SegmentRequest, Completer<void>)>();

  void configure({
    int? maxGlobal,
    int? maxPerHost,
    int? maxPerDownload,
  }) {
    if (maxGlobal != null) _maxGlobalConnections = maxGlobal;
    if (maxPerHost != null) _maxPerHostConnections = maxPerHost;
    if (maxPerDownload != null) _maxPerDownloadConnections = maxPerDownload;
    _log.info('Scheduler configured: Global=$_maxGlobalConnections, PerHost=$_maxPerHostConnections, PerDownload=$_maxPerDownloadConnections');
  }

  Future<void> acquireSlot(String taskId, int segmentIndex, String host) async {
    final request = _SegmentRequest(taskId, segmentIndex, host);
    
    if (_canAcquire(request)) {
      _activeSlots.add(ConnectionSlot(taskId: taskId, segmentIndex: segmentIndex, host: host));
      return;
    }

    final completer = Completer<void>();
    _waitingSegments.add((request, completer));
    await completer.future;
  }

  void releaseSlot(String taskId, int segmentIndex) {
    _activeSlots.removeWhere((s) => s.taskId == taskId && s.segmentIndex == segmentIndex);
    _processWaiting();
  }

  void releaseTaskSlots(String taskId) {
    _activeSlots.removeWhere((s) => s.taskId == taskId);
    _processWaiting();
  }

  void reset() {
    _activeSlots.clear();
    _waitingSegments.clear();
  }

  bool _canAcquire(_SegmentRequest req) {
    if (_activeSlots.length >= _maxGlobalConnections) return false;

    // Check per-download limit
    final downloadCount = _activeSlots.where((s) => s.taskId == req.taskId).length;
    if (downloadCount >= _maxPerDownloadConnections) return false;

    // Check per-host limit
    final hostCount = _activeSlots.where((s) => s.host == req.host).length;
    if (hostCount >= _maxPerHostConnections) return false;

    return true; 
  }

  void _processWaiting() {
    while (_waitingSegments.isNotEmpty) {
      final (req, completer) = _waitingSegments.first;
      if (_canAcquire(req)) {
        _waitingSegments.removeFirst();
        _activeSlots.add(ConnectionSlot(taskId: req.taskId, segmentIndex: req.segmentIndex, host: req.host));
        completer.complete();
      } else {
        break;
      }
    }
  }

  int get activeConnectionCount => _activeSlots.length;
  int get waitingQueueLength => _waitingSegments.length;
}

class _SegmentRequest {
  final String taskId;
  final int segmentIndex;
  final String host;

  _SegmentRequest(this.taskId, this.segmentIndex, this.host);
}
