import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../models/browser_download_request.dart';
import 'browser_request_handler.dart';

/// Binds a local IPC endpoint and handles incoming browser-extension requests.
///
/// macOS/Linux: Unix domain socket at {appDataDir}/ipc/creator_forge.sock
/// Windows:     TCP loopback on a dynamic port; per-session token guards the
///              connection.  Port + token are written to creator_forge.conn.
class IpcServer {
  final BrowserRequestHandler _handler;
  final _log = AppLogger.get('IpcServer');

  ServerSocket? _server;
  bool _started = false;
  bool _disposed = false;

  String get _ipcDir => p.join(AppConfig.instance.appDataDir, 'ipc');
  String get _socketPath => p.join(_ipcDir, 'creator_forge.sock');
  String get _connFilePath => p.join(_ipcDir, 'creator_forge.conn');

  IpcServer(this._handler);

  bool get isRunning => _started && !_disposed;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    await Directory(_ipcDir).create(recursive: true);

    if (Platform.isMacOS || Platform.isLinux) {
      await _startUnixSocket();
    } else {
      await _startTcpSocket();
    }
  }

  Future<void> _startUnixSocket() async {
    // Remove stale socket file from a prior crash.
    final sockFile = File(_socketPath);
    if (sockFile.existsSync()) sockFile.deleteSync();

    try {
      _server = await ServerSocket.bind(
        InternetAddress(_socketPath, type: InternetAddressType.unix),
        0,
      );
      _log.info('IPC Unix socket listening at $_socketPath');
      _writeConnFile({'version': kIpcProtocolVersion, 'socket': _socketPath});
      _server!.listen(
        _handleSocket,
        onError: _onServerError,
        cancelOnError: false,
      );
    } catch (e) {
      _log.warning('Failed to start IPC Unix socket.', e);
      _started = false;
    }
  }

  Future<void> _startTcpSocket() async {
    try {
      final token = _randomToken();
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = _server!.port;
      _log.info('IPC TCP server listening on port $port');
      _writeConnFile({
        'version': kIpcProtocolVersion,
        'host': '127.0.0.1',
        'port': port,
        'token': token,
      });
      _server!.listen(
        (socket) => _handleSocket(socket, expectedToken: token),
        onError: _onServerError,
        cancelOnError: false,
      );
    } catch (e) {
      _log.warning('Failed to start IPC TCP server.', e);
      _started = false;
    }
  }

  void _onServerError(Object e) {
    _log.warning('IPC server error.', e);
  }

  void _handleSocket(Socket socket, {String? expectedToken}) {
    final conn = _IpcConnection(socket, _handler, expectedToken, _log);
    conn.start();
  }

  void _writeConnFile(Map<String, Object> info) {
    try {
      File(_connFilePath).writeAsStringSync(jsonEncode(info));
    } catch (e) {
      _log.warning('Failed to write IPC conn file.', e);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _server?.close();
    _server = null;
    _cleanUp();
  }

  void _cleanUp() {
    for (final path in [_socketPath, _connFilePath]) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  static String _randomToken() {
    final rng = Random.secure();
    return List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

// ── Per-connection handler ─────────────────────────────────────────────────

class _IpcConnection {
  final Socket _socket;
  final BrowserRequestHandler _handler;
  final String? _expectedToken;
  final Logger _log;

  bool _tokenVerified;
  final _buf = StringBuffer();

  _IpcConnection(this._socket, this._handler, this._expectedToken, this._log)
    // Unix socket connections have no token; TCP connections must send one.
    : _tokenVerified = _expectedToken == null;

  void start() {
    _socket
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          _onData,
          onError: (Object e) => _log.fine('IPC socket error: $e'),
          onDone: () {
            _buf.clear();
            _socket.destroy();
          },
          cancelOnError: false,
        );
  }

  void _onData(String chunk) {
    _buf.write(chunk);
    final full = _buf.toString();
    final lines = full.split('\n');
    // Keep the last (possibly incomplete) line in the buffer.
    _buf
      ..clear()
      ..write(lines.last);

    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) _processLine(line);
    }
  }

  Future<void> _processLine(String line) async {
    // Guard against enormous inputs.
    if (line.length > kMaxMessageBytes) {
      _log.warning('IPC message exceeds size limit; discarding.');
      _sendResponse(
        BrowserResponse.error(requestId: '', error: 'Message too large.'),
      );
      return;
    }

    Map<String, dynamic> json;
    try {
      json = (jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {
      _sendResponse(
        BrowserResponse.error(requestId: '', error: 'Malformed JSON.'),
      );
      return;
    }

    // For TCP connections, the first message must carry the session token.
    if (!_tokenVerified) {
      final tok = json['token'] as String?;
      if (tok != _expectedToken) {
        _log.warning('IPC connection rejected: bad token.');
        await _socket.close();
        return;
      }
      _tokenVerified = true;
      // Respond with ack and continue; the token frame is not a proper message.
      _sendResponse(BrowserResponse.connectionAck(''));
      return;
    }

    final msg = BrowserMessage.fromJson(json);
    if (msg == null) {
      _sendResponse(
        BrowserResponse.error(
          requestId: (json['requestId'] as String?) ?? '',
          error: 'Unknown message type: ${json["type"]}',
        ),
      );
      return;
    }

    try {
      final response = await _handler.handle(msg);
      _sendResponse(response);
    } catch (e) {
      _log.warning('Handler error for ${json["type"]}: $e');
      _sendResponse(
        BrowserResponse.error(requestId: msg.requestId, error: '$e'),
      );
    }
  }

  void _sendResponse(BrowserResponse r) {
    try {
      _socket.write(r.toJsonLine());
    } catch (e) {
      _log.fine('Failed to write IPC response: $e');
    }
  }
}
