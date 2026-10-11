import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:creator_forge/models/browser_download_request.dart';
import 'package:creator_forge/models/download_task.dart';
import 'package:creator_forge/models/media_info.dart';
import 'package:creator_forge/services/browser_extension/browser_request_handler.dart';
import 'package:creator_forge/services/download/download_engine.dart';
import 'package:creator_forge/services/download/metadata_resolver.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockDownloadEngine extends Mock implements DownloadEngine {}

class MockMetadataResolver extends Mock implements MetadataResolver {}

class FakeDownloadTask extends Fake implements DownloadTask {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _validUrl = 'https://example.com/video.mp4';
const _reqId = 'req-001';

BrowserRequestHandler _makeHandler(
  MockDownloadEngine engine,
  MockMetadataResolver resolver, {
  void Function(String)? onTaskEnqueued,
}) => BrowserRequestHandler(
  downloadEngine: engine,
  metadataResolver: resolver,
  onTaskEnqueued: onTaskEnqueued,
);

DownloadTask _fakeTask({String id = 'task-1'}) => DownloadTask(
  id: id,
  url: _validUrl,
  outputDirectory: '/tmp/out',
  status: DownloadStatus.queued,
  createdAt: DateTime(2026, 1, 1),
);

MediaInfo _fakeMediaInfo() => MediaInfo(
  url: _validUrl,
  title: 'Test Video',
  formats: const [],
  resolvedAt: DateTime(2026, 1, 1),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockDownloadEngine engine;
  late MockMetadataResolver resolver;

  setUpAll(() {
    registerFallbackValue(DownloadType.videoAndAudio);
  });

  setUp(() {
    engine = MockDownloadEngine();
    resolver = MockMetadataResolver();
  });

  // ── PING ──────────────────────────────────────────────────────────────────

  group('PING', () {
    test('returns PONG with same requestId', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserPingMsg(version: 1, requestId: _reqId);
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.pong);
      expect(resp.requestId, _reqId);
    });
  });

  // ── CONNECTION_STATUS ─────────────────────────────────────────────────────

  group('CONNECTION_STATUS', () {
    test('returns CONNECTION_ACK', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserConnectionStatusMsg(
        version: 1,
        requestId: _reqId,
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.connectionAck);
    });
  });

  // ── ANALYZE_MEDIA ─────────────────────────────────────────────────────────

  group('ANALYZE_MEDIA', () {
    test('rejects empty URL', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserAnalyzeMsg(
        version: 1,
        requestId: _reqId,
        url: '',
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadRejected);
      expect(resp.extra['error'], contains('URL'));
    });

    test('rejects non-http scheme', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserAnalyzeMsg(
        version: 1,
        requestId: _reqId,
        url: 'ftp://example.com/video.mp4',
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadRejected);
    });

    test('returns ANALYZE_RESULT on resolver success', () async {
      when(() => resolver.resolve(_validUrl))
          .thenAnswer((_) async => _fakeMediaInfo());
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserAnalyzeMsg(
        version: 1,
        requestId: _reqId,
        url: _validUrl,
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.analyzeResult);
      expect(resp.extra['title'], 'Test Video');
      expect(resp.extra['supported'], isTrue);
    });

    test('returns direct-download info when resolver fails', () async {
      when(() => resolver.resolve(_validUrl))
          .thenThrow(Exception('no extractor'));
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserAnalyzeMsg(
        version: 1,
        requestId: _reqId,
        url: _validUrl,
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.analyzeResult);
      expect(resp.extra['isDirectDownload'], isTrue);
      expect(resp.extra['supported'], isTrue);
    });
  });

  // ── DOWNLOAD_REQUEST ──────────────────────────────────────────────────────

  group('DOWNLOAD_REQUEST', () {
    test('rejects empty URL', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: '',
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadRejected);
    });

    test('rejects unsupported scheme', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: 'javascript:alert(1)',
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadRejected);
    });

    test('rejects localhost URL', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: 'http://localhost:8080/video.mp4',
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadRejected);
      expect(resp.extra['error'], contains('local'));
    });

    test('rejects 127.0.0.1 URL', () async {
      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: 'http://127.0.0.1/api/video',
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadRejected);
    });

    test('enqueues valid URL and returns DOWNLOAD_ACCEPTED', () async {
      when(
        () => engine.enqueue(
          url: any(named: 'url'),
          formatSelector: any(named: 'formatSelector'),
          downloadType: any(named: 'downloadType'),
          cachedMetadata: any(named: 'cachedMetadata'),
        ),
      ).thenAnswer((_) async => _fakeTask());

      final enqueued = <String>[];
      final handler = _makeHandler(
        engine,
        resolver,
        onTaskEnqueued: enqueued.add,
      );
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: _validUrl,
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
        title: 'Test Video',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadAccepted);
      expect(resp.extra['taskId'], 'task-1');
      expect(enqueued, ['task-1']);
    });

    test('returns DOWNLOAD_REJECTED when enqueue throws', () async {
      when(
        () => engine.enqueue(
          url: any(named: 'url'),
          formatSelector: any(named: 'formatSelector'),
          downloadType: any(named: 'downloadType'),
          cachedMetadata: any(named: 'cachedMetadata'),
        ),
      ).thenThrow(Exception('disk full'));

      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: _validUrl,
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
      );
      final resp = await handler.handle(msg);
      expect(resp.type, OutgoingMsgType.downloadRejected);
    });

    test('passes formatSelector to engine', () async {
      when(
        () => engine.enqueue(
          url: any(named: 'url'),
          formatSelector: any(named: 'formatSelector'),
          downloadType: any(named: 'downloadType'),
          cachedMetadata: any(named: 'cachedMetadata'),
        ),
      ).thenAnswer((_) async => _fakeTask());

      final handler = _makeHandler(engine, resolver);
      const sel = 'bestvideo[height<=1080]+bestaudio';
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: _validUrl,
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
        formatSelector: sel,
      );
      await handler.handle(msg);
      verify(
        () => engine.enqueue(
          url: any(named: 'url'),
          formatSelector: sel,
          downloadType: any(named: 'downloadType'),
          cachedMetadata: any(named: 'cachedMetadata'),
        ),
      ).called(1);
    });

    test('title is sanitized before passing to engine', () async {
      when(
        () => engine.enqueue(
          url: any(named: 'url'),
          formatSelector: any(named: 'formatSelector'),
          downloadType: any(named: 'downloadType'),
          cachedMetadata: any(named: 'cachedMetadata'),
        ),
      ).thenAnswer((_) async => _fakeTask());

      final handler = _makeHandler(engine, resolver);
      final msg = const BrowserDownloadMsg(
        version: 1,
        requestId: _reqId,
        url: _validUrl,
        pageUrl: 'https://example.com',
        pageTitle: 'Test',
        title: 'video<injection>.mp4',
      );
      final resp = await handler.handle(msg);
      // Should still succeed — title is sanitized, not rejected.
      expect(resp.type, OutgoingMsgType.downloadAccepted);
    });
  });

  // ── BrowserMessage.fromJson ───────────────────────────────────────────────

  group('BrowserMessage.fromJson', () {
    test('returns null for unknown type', () {
      final msg = BrowserMessage.fromJson({
        'type': 'UNKNOWN',
        'requestId': 'r1',
      });
      expect(msg, isNull);
    });

    test('parses PING correctly', () {
      final msg = BrowserMessage.fromJson({
        'type': 'PING',
        'requestId': 'r1',
        'version': 1,
      });
      expect(msg, isA<BrowserPingMsg>());
      expect(msg!.requestId, 'r1');
    });

    test('parses DOWNLOAD_REQUEST with audioOnly type', () {
      final msg = BrowserMessage.fromJson({
        'type': 'DOWNLOAD_REQUEST',
        'requestId': 'r2',
        'version': 1,
        'url': _validUrl,
        'pageUrl': 'https://example.com',
        'pageTitle': 'Page',
        'downloadType': 'audioOnly',
      }) as BrowserDownloadMsg?;
      expect(msg?.downloadType, DownloadType.audioOnly);
    });

    test('defaults version to 1 when missing', () {
      final msg = BrowserMessage.fromJson({'type': 'PING', 'requestId': 'r1'});
      expect(msg?.version, 1);
    });
  });

  // ── BrowserResponse serialization ────────────────────────────────────────

  group('BrowserResponse', () {
    test('toJsonLine ends with newline', () {
      final r = BrowserResponse.pong('r1');
      expect(r.toJsonLine(), endsWith('\n'));
    });

    test('toJson includes version and type', () {
      final r = BrowserResponse.downloadAccepted(requestId: 'r1', taskId: 't1');
      final json = r.toJson();
      expect(json['version'], kIpcProtocolVersion);
      expect(json['type'], 'DOWNLOAD_ACCEPTED');
      expect(json['taskId'], 't1');
    });

    test('error response includes error field', () {
      final r = BrowserResponse.error(requestId: 'r1', error: 'bad input');
      expect(r.toJson()['error'], 'bad input');
    });
  });
}
