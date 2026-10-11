import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/download_task.dart';
import '../../providers/app_providers.dart';
import '../../providers/browser_integration_provider.dart';
import '../../services/browser_extension/native_host_service.dart';
import '../downloads/widgets/download_task_tile.dart';

/// Browser Integration wizard + live download queue.
///
/// On Windows: shows a step-by-step wizard that detects browsers, registers
///             the native host, and confirms a live end-to-end connection.
/// On macOS:   shows the IPC server status and manual setup instructions.
class BrowserDownloadsScreen extends ConsumerStatefulWidget {
  const BrowserDownloadsScreen({super.key});

  @override
  ConsumerState<BrowserDownloadsScreen> createState() =>
      _BrowserDownloadsScreenState();
}

class _BrowserDownloadsScreenState
    extends ConsumerState<BrowserDownloadsScreen> {
  final _extensionIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Kick off browser detection on first load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(browserIntegrationProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _extensionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ipc = ref.watch(ipcServerProvider);
    final browserIds = ref.watch(browserTaskIdsProvider);
    final allTasksAsync = ref.watch(downloadTasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Header(ipcRunning: ipc.isRunning),
          const SizedBox(height: 16),
          if (Platform.isWindows) ...[
            const _WindowsWizard(),
          ] else ...[
            _MacOsInstructions(ipcRunning: ipc.isRunning),
          ],
          const SizedBox(height: 24),
          allTasksAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (tasks) {
              final browserTasks = tasks
                  .where((t) => browserIds.contains(t.id))
                  .toList();
              if (browserTasks.isEmpty) return const SizedBox.shrink();
              return _BrowserQueue(
                tasks: browserTasks,
                onClearCompleted:
                    browserTasks.any(
                      (t) =>
                          t.status == DownloadStatus.completed ||
                          t.status == DownloadStatus.cancelled,
                    )
                    ? () => ref.read(downloadEngineProvider).clearCompleted()
                    : null,
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool ipcRunning;
  const _Header({required this.ipcRunning});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.extension_outlined,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Browser Integration', style: AppTextStyles.headingLarge),
              Text(
                'Download media from any page via the browser extension',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        _IpcBadge(running: ipcRunning),
      ],
    );
  }
}

class _IpcBadge extends StatelessWidget {
  final bool running;
  const _IpcBadge({required this.running});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: running ? AppColors.successSurface : AppColors.errorSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: running
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: running ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            running ? 'IPC Running' : 'IPC Stopped',
            style: AppTextStyles.caption.copyWith(
              color: running ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Windows wizard ────────────────────────────────────────────────────────────

class _WindowsWizard extends ConsumerWidget {
  const _WindowsWizard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browserIntegrationProvider);
    final notifier = ref.read(browserIntegrationProvider.notifier);

    return switch (state.stage) {
      BrowserSetupStage.initial || BrowserSetupStage.detecting =>
        const _LoadingCard(label: 'Detecting installed browsers…'),
      BrowserSetupStage.noBrowserFound => _NoBrowserCard(
        onRefresh: notifier.initialize,
      ),
      BrowserSetupStage.idle => _BrowserSelectionCard(
        state: state,
        onSelectBrowser: notifier.selectBrowser,
        onBeginSetup: () => _showExtensionIdDialog(context, ref, state),
        onOpenExtensionsPage: notifier.openExtensionsPage,
      ),
      BrowserSetupStage.registering => const _LoadingCard(
        label: 'Registering native host…',
      ),
      BrowserSetupStage.waitingForConnection => _WaitingCard(
        state: state,
        onTimeout: () => notifier.waitForConnection(),
        onOpenExtensionsPage: notifier.openExtensionsPage,
      ),
      BrowserSetupStage.connected => _ConnectedCard(
        state: state,
        onRepair: notifier.repair,
        onCopyDiagnostics: () =>
            _copyReport(context, notifier.buildDiagnosticsReport()),
      ),
      BrowserSetupStage.error => _ErrorCard(
        state: state,
        onRepair: notifier.repair,
        onRetry: () => _showExtensionIdDialog(context, ref, state),
        onCopyDiagnostics: () =>
            _copyReport(context, notifier.buildDiagnosticsReport()),
      ),
    };
  }

  void _showExtensionIdDialog(
    BuildContext context,
    WidgetRef ref,
    BrowserIntegrationState state,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _ExtensionIdDialog(
        browserState: state,
        notifier: ref.read(browserIntegrationProvider.notifier),
      ),
    );
  }

  void _copyReport(BuildContext context, String report) {
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ── Wizard cards ──────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _NoBrowserCard extends StatelessWidget {
  final VoidCallback onRefresh;
  const _NoBrowserCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.browser_not_supported_outlined,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'No supported browser detected',
                style: AppTextStyles.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'CreatorForge browser integration requires Google Chrome, '
            'Microsoft Edge, or Brave Browser.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            children: [
              _LinkChip(
                label: 'Get Chrome',
                url: 'https://www.google.com/chrome/',
              ),
              _LinkChip(
                label: 'Get Edge',
                url: 'https://www.microsoft.com/en-us/edge',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _BrowserSelectionCard extends StatelessWidget {
  final BrowserIntegrationState state;
  final void Function(String) onSelectBrowser;
  final VoidCallback onBeginSetup;
  final Future<void> Function() onOpenExtensionsPage;

  const _BrowserSelectionCard({
    required this.state,
    required this.onSelectBrowser,
    required this.onBeginSetup,
    required this.onOpenExtensionsPage,
  });

  @override
  Widget build(BuildContext context) {
    final diag = state.diagnostics;
    final isConfigured = diag?.isHealthy ?? false;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browser Integration Setup', style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          Text(
            isConfigured
                ? 'The native host is registered. '
                      'To verify the connection, open the extension popup.'
                : 'Select a browser and follow the steps to connect '
                      'CreatorForge to your browser extension.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 14),
          // Browser selector
          ...state.browsers
              .where((b) => b.isInstalled)
              .map(
                (b) => _BrowserTile(
                  browser: b,
                  isSelected: state.selectedBrowserId == b.id,
                  diagnostics: state.selectedBrowserId == b.id ? diag : null,
                  onTap: () => onSelectBrowser(b.id),
                ),
              ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              if (!isConfigured)
                FilledButton.icon(
                  onPressed: onBeginSetup,
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Set Up Extension'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: onOpenExtensionsPage,
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text('Open Extensions Page'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onBeginSetup,
                  icon: const Icon(Icons.build_outlined, size: 16),
                  label: const Text('Reconfigure'),
                ),
              ],
            ],
          ),
          if (diag != null) ...[
            const SizedBox(height: 12),
            _DiagnosticsSummary(diag: diag),
          ],
        ],
      ),
    );
  }
}

class _BrowserTile extends StatelessWidget {
  final BrowserInfo browser;
  final bool isSelected;
  final NativeHostDiagnostics? diagnostics;
  final VoidCallback onTap;

  const _BrowserTile({
    required this.browser,
    required this.isSelected,
    required this.diagnostics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final healthy = diagnostics?.isHealthy ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.web,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textMedium,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(browser.name, style: AppTextStyles.bodyMedium),
            ),
            if (healthy)
              const _StatusDot(color: AppColors.success, label: 'Registered')
            else
              const _StatusDot(
                color: AppColors.textLow,
                label: 'Not configured',
              ),
          ],
        ),
      ),
    );
  }
}

class _WaitingCard extends ConsumerWidget {
  final BrowserIntegrationState state;
  final VoidCallback onTimeout;
  final Future<void> Function() onOpenExtensionsPage;

  const _WaitingCard({
    required this.state,
    required this.onTimeout,
    required this.onOpenExtensionsPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-start waiting when card is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(browserIntegrationProvider.notifier).waitForConnection();
    });

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Waiting for extension…', style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Open your browser, then click the CreatorForge extension icon. '
            'The extension will automatically connect to the desktop app.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onOpenExtensionsPage,
                icon: const Icon(Icons.open_in_browser, size: 16),
                label: const Text('Open Browser'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final BrowserIntegrationState state;
  final VoidCallback onRepair;
  final VoidCallback onCopyDiagnostics;

  const _ConnectedCard({
    required this.state,
    required this.onRepair,
    required this.onCopyDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      borderColor: AppColors.success.withValues(alpha: 0.4),
      backgroundColor: AppColors.successSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Connected',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.success,
                ),
              ),
              const Spacer(),
              if (state.lastPingAt != null)
                Text(
                  'Last ping: ${_formatTime(state.lastPingAt!)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The browser extension is communicating with CreatorForge. '
            'Open any page in your browser and click the extension icon '
            'to start downloading media.',
            style: AppTextStyles.bodySmall,
          ),
          if (state.diagnostics != null) ...[
            const SizedBox(height: 10),
            _DiagnosticsSummary(diag: state.diagnostics!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onRepair,
                icon: const Icon(Icons.build_outlined, size: 16),
                label: const Text('Repair Connection'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onCopyDiagnostics,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _ErrorCard extends StatelessWidget {
  final BrowserIntegrationState state;
  final VoidCallback onRepair;
  final VoidCallback onRetry;
  final VoidCallback onCopyDiagnostics;

  const _ErrorCard({
    required this.state,
    required this.onRepair,
    required this.onRetry,
    required this.onCopyDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      borderColor: AppColors.error.withValues(alpha: 0.4),
      backgroundColor: AppColors.errorSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Text(
                'Setup error',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.error ?? 'An unknown error occurred.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
          if (state.diagnostics != null) ...[
            const SizedBox(height: 10),
            _DiagnosticsSummary(diag: state.diagnostics!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              ),
              OutlinedButton.icon(
                onPressed: onRepair,
                icon: const Icon(Icons.build_outlined, size: 16),
                label: const Text('Repair'),
              ),
              TextButton.icon(
                onPressed: onCopyDiagnostics,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Extension ID dialog ───────────────────────────────────────────────────────

class _ExtensionIdDialog extends ConsumerStatefulWidget {
  final BrowserIntegrationState browserState;
  final BrowserIntegrationNotifier notifier;

  const _ExtensionIdDialog({
    required this.browserState,
    required this.notifier,
  });

  @override
  ConsumerState<_ExtensionIdDialog> createState() => _ExtensionIdDialogState();
}

class _ExtensionIdDialogState extends ConsumerState<_ExtensionIdDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = widget.browserState.selectedBrowser;
    final nativeSvc = ref.read(nativeHostServiceProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Enter Extension ID', style: AppTextStyles.headingSmall),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CreatorForge can register automatically once you give it '
              'the extension ID from your browser.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            // Step 1 — open extensions page
            _DialogStep(
              number: '1',
              title: 'Open the extensions page',
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: browser != null
                        ? () => nativeSvc.openExtensionsPage(browser)
                        : null,
                    icon: const Icon(Icons.open_in_browser, size: 14),
                    label: const Text('Open chrome://extensions/'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Step 2 — enable Developer mode + Load unpacked
            _DialogStep(
              number: '2',
              title: 'Load the unpacked extension',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toggle on Developer mode (top-right). '
                    'Click Load unpacked and select the '
                    'browser-extension/dist/ folder.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Reveal the dist/ folder in Explorer.
                      // Use the path relative to the app install dir.
                      const distRelPath = r'browser-extension\dist';
                      final appDir = _pDirname(Platform.resolvedExecutable);
                      final distPath = '$appDir\\$distRelPath';
                      nativeSvc.revealFolder(distPath);
                    },
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: const Text('Open extension folder'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Step 3 — copy extension ID
            _DialogStep(
              number: '3',
              title: 'Copy the Extension ID and paste it here',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The ID is 32 lowercase letters shown under the '
                    'extension name.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    onChanged: (_) => setState(() => _error = null),
                    decoration: InputDecoration(
                      hintText: 'e.g. abcdefghijklmnopqrstuvwxyzabcdef',
                      errorText: _error,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    style: AppTextStyles.mono,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Register & Connect'),
        ),
      ],
    );
  }

  void _submit() {
    final id = _ctrl.text.trim();
    final err = NativeHostService.validateExtensionId(id);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
    widget.notifier.submitExtensionId(id);
  }
}

// Returns dirname of a path (avoids importing path package in UI file).
String _pDirname(String path) {
  final idx = path.lastIndexOfAny([r'\', '/']);
  return idx >= 0 ? path.substring(0, idx) : path;
}

extension _StringX on String {
  int lastIndexOfAny(List<String> chars) {
    var result = -1;
    for (final c in chars) {
      final idx = lastIndexOf(c);
      if (idx > result) result = idx;
    }
    return result;
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? backgroundColor;

  const _Card({required this.child, this.borderColor, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _DiagnosticsSummary extends StatelessWidget {
  final NativeHostDiagnostics diag;
  const _DiagnosticsSummary({required this.diag});

  @override
  Widget build(BuildContext context) {
    final checks = [
      (label: 'Registry key', ok: diag.registryKeyPresent),
      (label: 'Manifest file', ok: diag.manifestFilePresent),
      (
        label: 'Manifest valid',
        ok: diag.manifestNameCorrect && diag.manifestTypeCorrect,
      ),
      (label: 'Host executable', ok: diag.hostExecPresent),
      (label: 'Extension ID set', ok: diag.allowedOrigins.isNotEmpty),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: checks
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.ok ? AppColors.successSurface : AppColors.errorSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c.ok ? Icons.check : Icons.close,
                    size: 11,
                    color: c.ok ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    c.label,
                    style: AppTextStyles.caption.copyWith(
                      color: c.ok ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DialogStep extends StatelessWidget {
  final String number;
  final String title;
  final Widget child;
  const _DialogStep({
    required this.number,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  final String label;
  final String url;
  const _LinkChip({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: AppTextStyles.caption),
      avatar: const Icon(Icons.open_in_new, size: 13),
      onPressed: () {
        // On Windows, open the URL in the default browser.
        if (Platform.isWindows) {
          Process.start('rundll32', [
            'url.dll,FileProtocolHandler',
            url,
          ], mode: ProcessStartMode.detached).ignore();
        }
      },
    );
  }
}

// ── macOS / manual setup ──────────────────────────────────────────────────────

class _MacOsInstructions extends StatefulWidget {
  final bool ipcRunning;
  const _MacOsInstructions({required this.ipcRunning});

  @override
  State<_MacOsInstructions> createState() => _MacOsInstructionsState();
}

class _MacOsInstructionsState extends State<_MacOsInstructions> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.ipcRunning
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: widget.ipcRunning ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.ipcRunning
                      ? 'CreatorForge is ready for browser connections'
                      : 'IPC server could not start — restart CreatorForge',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Text(
                  'Manual setup instructions',
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: AppColors.textMedium,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _ManualStep(
              number: '1',
              title: 'Register the native messaging host',
              description: Platform.isMacOS
                  ? 'Run: native-host/scripts/install_macos.sh <ExtensionId>'
                  : 'Run: native-host\\scripts\\install_windows.ps1 <ExtensionId>',
              copyText: Platform.isMacOS
                  ? 'bash native-host/scripts/install_macos.sh'
                  : r'powershell -ExecutionPolicy Bypass -File native-host\scripts\install_windows.ps1',
            ),
            const SizedBox(height: 10),
            const _ManualStep(
              number: '2',
              title: 'Load the browser extension',
              description: 'Open Chrome or Edge → chrome://extensions/ → Enable Developer mode → Load unpacked → select browser-extension/dist/',
            ),
            const SizedBox(height: 10),
            const _ManualStep(
              number: '3',
              title: 'Register the extension ID',
              description: 'Copy the 32-character ID shown under the extension and re-run the install script with that ID.',
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final String? copyText;

  const _ManualStep({
    required this.number,
    required this.title,
    required this.description,
    this.copyText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMedium),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.caption),
              if (copyText != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: copyText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            copyText!,
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Browser-initiated download queue ─────────────────────────────────────────

class _BrowserQueue extends ConsumerWidget {
  final List<DownloadTask> tasks;
  final VoidCallback? onClearCompleted;

  const _BrowserQueue({required this.tasks, this.onClearCompleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Browser Downloads', style: AppTextStyles.headingSmall),
            Text(' · ${tasks.length}', style: AppTextStyles.bodySmall),
            const Spacer(),
            if (onClearCompleted != null)
              TextButton(
                onPressed: onClearCompleted,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMedium,
                  textStyle: AppTextStyles.labelSmall,
                ),
                child: const Text('Clear completed'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final task in tasks)
          Padding(
            key: ValueKey(task.id),
            padding: const EdgeInsets.only(bottom: 8),
            child: DownloadTaskTile(task: task),
          ),
      ],
    );
  }
}
