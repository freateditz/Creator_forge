import 'dart:convert';

import 'package:creator_forge/models/bg_removal_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BgRemovalModel', () {
    test('fromId returns correct model', () {
      expect(
        BgRemovalModel.fromId('isnet-general-use'),
        BgRemovalModel.isnetGeneralUse,
      );
      expect(BgRemovalModel.fromId('u2net'), BgRemovalModel.u2net);
      expect(BgRemovalModel.fromId('u2netp'), BgRemovalModel.u2netp);
      expect(BgRemovalModel.fromId('silueta'), BgRemovalModel.silueta);
    });

    test('fromId defaults to isnetGeneralUse for unknown id', () {
      expect(
        BgRemovalModel.fromId('nonexistent'),
        BgRemovalModel.isnetGeneralUse,
      );
    });

    test('all models have non-empty display names and sizes', () {
      for (final m in BgRemovalModel.values) {
        expect(m.displayName.isNotEmpty, isTrue);
        expect(m.sizeLabel.isNotEmpty, isTrue);
        expect(m.id.isNotEmpty, isTrue);
      }
    });
  });

  group('BgRemovalRequest', () {
    test('default values are correct', () {
      const req = BgRemovalRequest(outputDirectory: '/out');
      expect(req.model, BgRemovalModel.isnetGeneralUse);
      expect(req.outputDirectory, '/out');
      expect(req.alphaMatting, isFalse);
      expect(req.alphaMattingFgThreshold, 240);
      expect(req.alphaMattingBgThreshold, 10);
      expect(req.alphaMattingErodeSize, 10);
      expect(req.postProcessMask, isFalse);
    });

    test('copyWith replaces only specified fields', () {
      const orig = BgRemovalRequest(outputDirectory: '/a');
      final copy = orig.copyWith(
        model: BgRemovalModel.u2net,
        alphaMatting: true,
        outputDirectory: '/b',
      );
      expect(copy.model, BgRemovalModel.u2net);
      expect(copy.outputDirectory, '/b');
      expect(copy.alphaMatting, isTrue);
      expect(copy.alphaMattingFgThreshold, orig.alphaMattingFgThreshold);
    });

    test('toJson / fromJson round-trip', () {
      const req = BgRemovalRequest(
        model: BgRemovalModel.u2netp,
        outputDirectory: '/tmp/out',
        alphaMatting: true,
        alphaMattingFgThreshold: 230,
        alphaMattingBgThreshold: 5,
        alphaMattingErodeSize: 15,
        postProcessMask: true,
      );
      final json = req.toJson();
      final restored = BgRemovalRequest.fromJson(json);
      expect(restored.model, req.model);
      expect(restored.outputDirectory, req.outputDirectory);
      expect(restored.alphaMatting, req.alphaMatting);
      expect(restored.alphaMattingFgThreshold, req.alphaMattingFgThreshold);
      expect(restored.alphaMattingBgThreshold, req.alphaMattingBgThreshold);
      expect(restored.alphaMattingErodeSize, req.alphaMattingErodeSize);
      expect(restored.postProcessMask, req.postProcessMask);
    });

    test('toJson encodes valid JSON string', () {
      const req = BgRemovalRequest(outputDirectory: '/tmp');
      final str = req.toJsonString();
      expect(() => jsonDecode(str), returnsNormally);
    });

    test('equality and hash consistency', () {
      const a = BgRemovalRequest(outputDirectory: '/out');
      const b = BgRemovalRequest(outputDirectory: '/out');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      final c = a.copyWith(alphaMatting: true);
      expect(a, isNot(equals(c)));
    });

    test('fromJson handles missing fields gracefully', () {
      final req = BgRemovalRequest.fromJson({});
      expect(req.model, BgRemovalModel.isnetGeneralUse);
      expect(req.outputDirectory, isEmpty);
      expect(req.alphaMatting, isFalse);
    });
  });
}
