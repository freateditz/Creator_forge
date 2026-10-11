import '../../models/download_task.dart';
import '../../models/media_info.dart';

abstract interface class DownloadEngine {
  Stream<List<DownloadTask>> get tasksStream;
  List<DownloadTask> get currentTasks;

  Future<MediaInfo> resolveMetadata(String url);

  Future<DownloadTask> enqueue({
    required String url,
    String? formatSelector,
    DownloadType downloadType,
    String? outputDirectory,
    MediaInfo? cachedMetadata,
  });

  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> cancel(String taskId);
  Future<void> retry(String taskId);
  Future<void> remove(String taskId);
  Future<void> clearCompleted();
  Future<void> dispose();
}
