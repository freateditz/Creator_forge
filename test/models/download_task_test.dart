import 'package:creator_forge/models/download_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadTask', () {
    final task = DownloadTask(
      id: 'test-1',
      url: 'https://example.com/video',
      outputDirectory: '/downloads',
      createdAt: DateTime(2026, 1, 1),
    );

    test('has default status queued', () {
      expect(task.status, DownloadStatus.queued);
    });

    test('has default type videoAndAudio', () {
      expect(task.downloadType, DownloadType.videoAndAudio);
    });

    test('copyWith updates status', () {
      final updated = task.copyWith(status: DownloadStatus.downloading);
      expect(updated.status, DownloadStatus.downloading);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = task.copyWith(status: DownloadStatus.downloading);
      expect(updated.id, task.id);
      expect(updated.url, task.url);
      expect(updated.outputDirectory, task.outputDirectory);
    });

    test('equality based on props', () {
      final same = task.copyWith();
      expect(task, equals(same));
    });

    test('different status means not equal', () {
      final diff = task.copyWith(status: DownloadStatus.completed);
      expect(task, isNot(equals(diff)));
    });
  });
}
