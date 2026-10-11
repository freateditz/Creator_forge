import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:creator_forge/services/browser_extension/native_host_service.dart';

void main() {
  group('NativeHostService.validateExtensionId', () {
    test('accepts a valid 32-char lowercase ID', () {
      expect(
        NativeHostService.validateExtensionId('abcdefghijklmnopqrstuvwxyzabcdef'),
        isNull,
      );
    });

    test('rejects an ID that is too short', () {
      expect(
        NativeHostService.validateExtensionId('abcdef'),
        isNotNull,
      );
    });

    test('rejects an ID that is too long', () {
      expect(
        NativeHostService.validateExtensionId('a' * 33),
        isNotNull,
      );
    });

    test('rejects an ID containing uppercase letters', () {
      expect(
        NativeHostService.validateExtensionId('ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEF'),
        isNotNull,
      );
    });

    test('rejects an ID containing digits', () {
      expect(
        NativeHostService.validateExtensionId('abcdefghijklmnopqrstuvwxyz123456'),
        isNotNull,
      );
    });

    test('rejects an empty string', () {
      expect(NativeHostService.validateExtensionId(''), isNotNull);
    });
  });

  group('NativeHostDiagnostics', () {
    const healthy = NativeHostDiagnostics(
      browserId: 'chrome',
      registryKeyPresent: true,
      registryManifestPath: r'C:\AppData\CreatorForge\NativeHost\com.creatorforge.native_host.json',
      manifestFilePresent: true,
      manifestNameCorrect: true,
      manifestTypeCorrect: true,
      manifestHostExecPath: r'C:\Program Files\CreatorForge\NativeHost\creator_forge_native_host.exe',
      hostExecPresent: true,
      allowedOrigins: ['chrome-extension://abcdefghijklmnopqrstuvwxyzabcdef/'],
    );

    test('isHealthy returns true when all checks pass', () {
      expect(healthy.isHealthy, isTrue);
    });

    test('isHealthy returns false when registry key is missing', () {
      const d = NativeHostDiagnostics(
        browserId: 'chrome',
        registryKeyPresent: false,
        manifestFilePresent: false,
        manifestNameCorrect: false,
        manifestTypeCorrect: false,
        hostExecPresent: false,
        allowedOrigins: [],
      );
      expect(d.isHealthy, isFalse);
    });

    test('isHealthy returns false when manifest file is missing', () {
      final d = NativeHostDiagnostics(
        browserId: 'chrome',
        registryKeyPresent: true,
        registryManifestPath: healthy.registryManifestPath,
        manifestFilePresent: false,
        manifestNameCorrect: false,
        manifestTypeCorrect: false,
        hostExecPresent: false,
        allowedOrigins: const [],
      );
      expect(d.isHealthy, isFalse);
    });

    test('isHealthy returns false when manifest name is wrong', () {
      final d = NativeHostDiagnostics(
        browserId: 'chrome',
        registryKeyPresent: true,
        registryManifestPath: healthy.registryManifestPath,
        manifestFilePresent: true,
        manifestNameCorrect: false,   // wrong name
        manifestTypeCorrect: true,
        hostExecPresent: true,
        allowedOrigins: const ['chrome-extension://abcdefghijklmnopqrstuvwxyzabcdef/'],
      );
      expect(d.isHealthy, isFalse);
    });

    test('isHealthy returns false when no allowed origins are set', () {
      const d = NativeHostDiagnostics(
        browserId: 'chrome',
        registryKeyPresent: true,
        manifestFilePresent: true,
        manifestNameCorrect: true,
        manifestTypeCorrect: true,
        hostExecPresent: true,
        allowedOrigins: [],    // no extension ID set
      );
      expect(d.isHealthy, isFalse);
    });

    test('containsOrigin detects correct extension ID', () {
      expect(
        healthy.containsOrigin('abcdefghijklmnopqrstuvwxyzabcdef'),
        isTrue,
      );
    });

    test('containsOrigin returns false for a different ID', () {
      expect(
        healthy.containsOrigin('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
        isFalse,
      );
    });

    test('toTextReport includes all field names', () {
      final report = healthy.toTextReport();
      expect(report, contains('Browser:'));
      expect(report, contains('Registry key present:'));
      expect(report, contains('Manifest file present:'));
      expect(report, contains('Host exec present:'));
      expect(report, contains('Allowed origins:'));
    });
  });

  group('kNativeHostName', () {
    test('constant equals the canonical host name', () {
      expect(kNativeHostName, equals('com.creatorforge.native_host'));
    });
  });

  group('NativeHostService.nativeHostDir', () {
    test('returns empty string on non-Windows', () {
      // On macOS/Linux the dir is not applicable.
      if (!Platform.isWindows) {
        expect(NativeHostService.nativeHostDir, isEmpty);
      }
    });

    test('manifestPath ends with canonical manifest filename', () {
      if (!Platform.isWindows) return;
      expect(
        p.basename(NativeHostService.manifestPath),
        equals('$kNativeHostName.json'),
      );
    });
  });

  group('NativeHostService.findHostExecutable', () {
    test('returns null on non-Windows (no bat/exe exists there)', () {
      if (!Platform.isWindows) {
        final svc = NativeHostService();
        expect(svc.findHostExecutable(), isNull);
      }
    });
  });

  group('NativeHostService.diagnose (non-Windows)', () {
    test('returns not-registered state with explanatory error on macOS', () async {
      if (Platform.isWindows) return;
      final svc = NativeHostService();
      final diag = await svc.diagnose('chrome');
      expect(diag.isHealthy, isFalse);
      expect(diag.parseError, isNotNull);
      expect(diag.registryKeyPresent, isFalse);
    });
  });

  group('NativeHostService.registerHost (non-Windows)', () {
    test('returns failure with explanation on macOS', () async {
      if (Platform.isWindows) return;
      final svc = NativeHostService();
      final result = await svc.registerHost(
        browserId: 'chrome',
        extensionId: 'abcdefghijklmnopqrstuvwxyzabcdef',
      );
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
