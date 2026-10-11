import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/browser_extension/ipc_server.dart';
import '../services/browser_extension/native_host_service.dart';
import 'app_providers.dart';

// ── Setup stages ─────────────────────────────────────────────────────────────

enum BrowserSetupStage {
  /// Haven't run any detection yet.
  initial,

  /// Currently detecting installed browsers.
  detecting,

  /// No supported browser found on this machine.
  noBrowserFound,

  /// Browsers detected; user needs to select one and begin setup.
  idle,

  /// Running registration (writing manifest + registry).
  registering,

  /// Manifest + registry are written; waiting for the extension to send a PING.
  waitingForConnection,

  /// A real PING was received from the extension — full handshake confirmed.
  connected,

  /// Something went wrong; [BrowserIntegrationState.error] explains.
  error,
}

// ── State ─────────────────────────────────────────────────────────────────────

class BrowserIntegrationState {
  final BrowserSetupStage stage;
  final List<BrowserInfo> browsers;
  final String? selectedBrowserId;
  final NativeHostDiagnostics? diagnostics;
  final String? error;
  final DateTime? lastPingAt;

  const BrowserIntegrationState({
    this.stage = BrowserSetupStage.initial,
    this.browsers = const [],
    this.selectedBrowserId,
    this.diagnostics,
    this.error,
    this.lastPingAt,
  });

  BrowserIntegrationState copyWith({
    BrowserSetupStage? stage,
    List<BrowserInfo>? browsers,
    String? selectedBrowserId,
    NativeHostDiagnostics? diagnostics,
    String? error,
    DateTime? lastPingAt,
    bool clearError = false,
    bool clearDiagnostics = false,
    bool clearSelectedBrowser = false,
  }) =>
      BrowserIntegrationState(
        stage: stage ?? this.stage,
        browsers: browsers ?? this.browsers,
        selectedBrowserId: clearSelectedBrowser
            ? null
            : (selectedBrowserId ?? this.selectedBrowserId),
        diagnostics:
            clearDiagnostics ? null : (diagnostics ?? this.diagnostics),
        error: clearError ? null : (error ?? this.error),
        lastPingAt: lastPingAt ?? this.lastPingAt,
      );

  BrowserInfo? get selectedBrowser => browsers.firstWhere(
        (b) => b.id == selectedBrowserId,
        orElse: () => browsers.firstWhere(
          (b) => b.isInstalled,
          orElse: () => const BrowserInfo(id: '', name: ''),
        ),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BrowserIntegrationNotifier
    extends Notifier<BrowserIntegrationState> {
  late NativeHostService _svc;
  late IpcServer _ipc;
  StreamSubscription<DateTime>? _pingSub;

  @override
  BrowserIntegrationState build() {
    _svc = ref.watch(nativeHostServiceProvider);
    _ipc = ref.watch(ipcServerProvider);
    ref.onDispose(() => _pingSub?.cancel());
    return const BrowserIntegrationState();
  }

  // ── Public actions ───────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (state.stage != BrowserSetupStage.initial) return;

    if (!Platform.isWindows) {
      // macOS / Linux — IPC server runs, but NM registration is not automated.
      state = state.copyWith(stage: BrowserSetupStage.idle);
      return;
    }

    state = state.copyWith(stage: BrowserSetupStage.detecting, clearError: true);
    final browsers = await _svc.detectBrowsers();

    if (browsers.every((b) => !b.isInstalled)) {
      state = state.copyWith(
        stage: BrowserSetupStage.noBrowserFound,
        browsers: browsers,
      );
      return;
    }

    // Auto-select the first installed browser.
    final firstInstalled = browsers.firstWhere((b) => b.isInstalled);

    // Run diagnostics to surface existing registration.
    final diag = await _svc.diagnose(firstInstalled.id);
    final stage = diag.isHealthy
        ? BrowserSetupStage.idle
        : BrowserSetupStage.idle;

    state = state.copyWith(
      stage: stage,
      browsers: browsers,
      selectedBrowserId: firstInstalled.id,
      diagnostics: diag,
    );

    // If already healthy, listen for pings to keep the connected badge live.
    if (diag.isHealthy) _subscribeToPings();
  }

  void selectBrowser(String browserId) {
    state = state.copyWith(
      selectedBrowserId: browserId,
      clearDiagnostics: true,
      clearError: true,
    );
    // Re-diagnose in background.
    unawaited(_rediagnose(browserId));
  }

  Future<void> openExtensionsPage() async {
    final browser = state.selectedBrowser;
    if (browser == null || !browser.isInstalled) return;
    await _svc.openExtensionsPage(browser);
  }

  Future<void> revealExtensionFolder(String folderPath) async {
    await _svc.revealFolder(folderPath);
  }

  /// Validates [extensionId] and, if valid, writes the manifest + registry key.
  Future<void> submitExtensionId(String extensionId) async {
    final browser = state.selectedBrowser;
    if (browser == null || !browser.isInstalled) return;

    final validationError = NativeHostService.validateExtensionId(extensionId);
    if (validationError != null) {
      state = state.copyWith(
        stage: BrowserSetupStage.error,
        error: validationError,
      );
      return;
    }

    state = state.copyWith(
      stage: BrowserSetupStage.registering,
      clearError: true,
    );

    final result = await _svc.registerHost(
      browserId: browser.id,
      extensionId: extensionId,
    );

    if (!result.success) {
      state = state.copyWith(
        stage: BrowserSetupStage.error,
        error: result.error,
        diagnostics: result.diagnostics,
      );
      return;
    }

    state = state.copyWith(
      stage: BrowserSetupStage.waitingForConnection,
      diagnostics: result.diagnostics,
      clearError: true,
    );

    _subscribeToPings();
  }

  /// Waits up to [timeout] for a PING from the extension, then updates state.
  Future<void> waitForConnection({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (state.lastPingAt != null) {
      // Already received a ping.
      state = state.copyWith(stage: BrowserSetupStage.connected);
      return;
    }

    try {
      await _ipc.pingStream.first.timeout(timeout);
      state = state.copyWith(
        stage: BrowserSetupStage.connected,
        lastPingAt: DateTime.now(),
      );
    } on TimeoutException {
      state = state.copyWith(
        stage: BrowserSetupStage.error,
        error:
            'Connection timed out after ${timeout.inSeconds} seconds. '
            'Make sure the extension is loaded and the native host is registered, '
            'then click Retry.',
      );
    } catch (e) {
      state = state.copyWith(
        stage: BrowserSetupStage.error,
        error: 'Connection test failed: $e',
      );
    }
  }

  Future<void> recheckConnection() async {
    state = state.copyWith(
      stage: BrowserSetupStage.waitingForConnection,
      clearError: true,
    );
    await waitForConnection();
  }

  Future<void> repair() async {
    final browser = state.selectedBrowser;
    if (browser == null || !browser.isInstalled) return;

    // Re-diagnose to get the current extension ID if one was registered before.
    final diag = await _svc.diagnose(browser.id);
    String? existingId;
    if (diag.allowedOrigins.isNotEmpty) {
      final origin = diag.allowedOrigins.first;
      // Strip 'chrome-extension://' prefix and trailing '/'.
      existingId =
          origin.replaceFirst('chrome-extension://', '').replaceAll('/', '');
    }

    state = state.copyWith(
      stage: BrowserSetupStage.idle,
      diagnostics: diag,
      clearError: true,
    );

    if (existingId != null &&
        NativeHostService.validateExtensionId(existingId) == null) {
      await submitExtensionId(existingId);
    }
  }

  String buildDiagnosticsReport() {
    final diag = state.diagnostics;
    if (diag == null) return 'No diagnostics available.';
    final lines = [
      diag.toTextReport(),
      '',
      'IPC server running: ${_ipc.isRunning}',
      'Last PING received: ${state.lastPingAt ?? "(none)"}',
      'Platform: ${Platform.operatingSystem}',
    ];
    return lines.join('\n');
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  void _subscribeToPings() {
    _pingSub?.cancel();
    _pingSub = _ipc.pingStream.listen((time) {
      state = state.copyWith(
        lastPingAt: time,
        stage: BrowserSetupStage.connected,
      );
    });
  }

  Future<void> _rediagnose(String browserId) async {
    final diag = await _svc.diagnose(browserId);
    if (state.selectedBrowserId == browserId) {
      state = state.copyWith(diagnostics: diag);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final browserIntegrationProvider = NotifierProvider<BrowserIntegrationNotifier,
    BrowserIntegrationState>(BrowserIntegrationNotifier.new);
