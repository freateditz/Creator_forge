import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:creator_forge/models/separation_request.dart';

void main() {
  group('SeparationRequest', () {
    test('default values', () {
      const req = SeparationRequest(outputDirectory: '/tmp/out');
      expect(req.modelName, 'htdemucs');
      expect(req.mode, SeparationMode.voicePlusInstrumental);
      expect(req.device, SeparationDevice.auto);
      expect(req.outputDirectory, '/tmp/out');
    });

    test('toJson / fromJson round-trips correctly', () {
      const original = SeparationRequest(
        modelName: 'htdemucs',
        mode: SeparationMode.allStems,
        device: SeparationDevice.mps,
        outputDirectory: '/Users/test/music',
      );
      final json = original.toJson();
      final restored = SeparationRequest.fromJson(json);

      expect(restored.modelName, original.modelName);
      expect(restored.mode, original.mode);
      expect(restored.device, original.device);
      expect(restored.outputDirectory, original.outputDirectory);
    });

    test('toJsonString produces valid JSON', () {
      const req = SeparationRequest(outputDirectory: '/tmp/out');
      final str = req.toJsonString();
      expect(() => jsonDecode(str), returnsNormally);
      final m = jsonDecode(str) as Map<String, dynamic>;
      expect(m['outputDirectory'], '/tmp/out');
    });

    test('fromJson uses defaults for unknown enum values', () {
      final req = SeparationRequest.fromJson({
        'modelName': 'htdemucs',
        'mode': 'nonExistentMode',
        'device': 'nonExistentDevice',
        'outputDirectory': '/tmp',
      });
      expect(req.mode, SeparationMode.voicePlusInstrumental);
      expect(req.device, SeparationDevice.auto);
    });

    test('copyWith replaces only specified fields', () {
      const original = SeparationRequest(
        modelName: 'htdemucs',
        mode: SeparationMode.voicePlusInstrumental,
        device: SeparationDevice.auto,
        outputDirectory: '/original',
      );
      final changed = original.copyWith(device: SeparationDevice.cpu);
      expect(changed.device, SeparationDevice.cpu);
      expect(changed.modelName, original.modelName);
      expect(changed.mode, original.mode);
      expect(changed.outputDirectory, original.outputDirectory);
    });

    test('equality is value-based', () {
      const a = SeparationRequest(outputDirectory: '/out');
      const b = SeparationRequest(outputDirectory: '/out');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('inequality when field differs', () {
      const a = SeparationRequest(outputDirectory: '/out');
      const b = SeparationRequest(
        outputDirectory: '/out',
        device: SeparationDevice.cpu,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
