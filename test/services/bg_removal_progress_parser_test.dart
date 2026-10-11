import 'package:creator_forge/services/bg_removal/bg_removal_progress_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BgRemovalProgressParser parser;

  setUp(() => parser = BgRemovalProgressParser());

  group('BgRemovalProgressParser - null / non-JSON lines', () {
    test('blank line returns null', () {
      expect(parser.parseLine(''), isNull);
    });

    test('whitespace-only line returns null', () {
      expect(parser.parseLine('   \t  '), isNull);
    });

    test('plain text returns null', () {
      expect(parser.parseLine('Starting inference...'), isNull);
    });

    test('non-object JSON returns null', () {
      expect(parser.parseLine('"just a string"'), isNull);
    });
  });

  group('BgStageEvent', () {
    test('parses basic stage event', () {
      final event = parser.parseLine(
        '{"type":"stage","stage":"generating_mask"}',
      );
      expect(event, isA<BgStageEvent>());
      final e = event as BgStageEvent;
      expect(e.stage, 'generating_mask');
      expect(e.model, isNull);
    });

    test('parses stage event with model', () {
      final event = parser.parseLine(
        '{"type":"stage","stage":"loading_model","model":"isnet-general-use"}',
      );
      final e = event as BgStageEvent;
      expect(e.stage, 'loading_model');
      expect(e.model, 'isnet-general-use');
    });

    test('all expected stages parse correctly', () {
      for (final stage in [
        'analyzing_image',
        'loading_model',
        'generating_mask',
        'refining_edges',
        'exporting',
        'verifying',
        'downloading_model',
      ]) {
        final e = parser.parseLine('{"type":"stage","stage":"$stage"}');
        expect(e, isA<BgStageEvent>(), reason: 'Failed for stage: $stage');
      }
    });
  });

  group('BgImageInfoEvent', () {
    test('parses image info correctly', () {
      final event = parser.parseLine(
        '{"type":"image_info","width":1920,"height":1080,'
        '"mode":"RGB","has_existing_alpha":false}',
      );
      expect(event, isA<BgImageInfoEvent>());
      final e = event as BgImageInfoEvent;
      expect(e.width, 1920);
      expect(e.height, 1080);
      expect(e.mode, 'RGB');
      expect(e.hasExistingAlpha, isFalse);
    });

    test('parses image with existing alpha', () {
      final event = parser.parseLine(
        '{"type":"image_info","width":800,"height":600,'
        '"mode":"RGBA","has_existing_alpha":true}',
      );
      final e = event as BgImageInfoEvent;
      expect(e.hasExistingAlpha, isTrue);
      expect(e.mode, 'RGBA');
    });
  });

  group('BgRuntimeInfoEvent', () {
    test('parses runtime info with CoreML provider', () {
      final event = parser.parseLine(
        '{"type":"runtime_info","rembg_version":"2.0.85",'
        '"ort_version":"1.31.0","model_name":"isnet-general-use",'
        '"model_cached":true,'
        '"providers":["CoreMLExecutionProvider","CPUExecutionProvider"]}',
      );
      expect(event, isA<BgRuntimeInfoEvent>());
      final e = event as BgRuntimeInfoEvent;
      expect(e.rembgVersion, '2.0.85');
      expect(e.ortVersion, '1.31.0');
      expect(e.modelName, 'isnet-general-use');
      expect(e.modelCached, isTrue);
      expect(e.hasCoreML, isTrue);
      expect(e.hasCuda, isFalse);
    });

    test('detects CUDA provider', () {
      final event = parser.parseLine(
        '{"type":"runtime_info","rembg_version":"2.0.85",'
        '"ort_version":"1.31.0","model_name":"u2net",'
        '"model_cached":false,'
        '"providers":["CUDAExecutionProvider","CPUExecutionProvider"]}',
      );
      final e = event as BgRuntimeInfoEvent;
      expect(e.hasCuda, isTrue);
      expect(e.hasCoreML, isFalse);
      expect(e.modelCached, isFalse);
    });

    test('handles empty providers list', () {
      final event = parser.parseLine(
        '{"type":"runtime_info","rembg_version":"x","ort_version":"y",'
        '"model_name":"u2net","model_cached":false,"providers":[]}',
      );
      final e = event as BgRuntimeInfoEvent;
      expect(e.providers, isEmpty);
      expect(e.hasCoreML, isFalse);
      expect(e.hasCuda, isFalse);
    });
  });

  group('BgCompleteEvent', () {
    test('parses full removal completion event', () {
      final event = parser.parseLine(
        '{"type":"complete","output_path":"/out/img_nobg.png",'
        '"width":1920,"height":1080,"has_alpha":true,"file_size":524288}',
      );
      expect(event, isA<BgCompleteEvent>());
      final e = event as BgCompleteEvent;
      expect(e.outputPath, '/out/img_nobg.png');
      expect(e.width, 1920);
      expect(e.height, 1080);
      expect(e.hasAlpha, isTrue);
      expect(e.fileSize, 524288);
      expect(e.model, isNull);
    });

    test('parses download completion event', () {
      final event = parser.parseLine(
        '{"type":"complete","model":"isnet-general-use","cached":true}',
      );
      final e = event as BgCompleteEvent;
      expect(e.model, 'isnet-general-use');
      expect(e.outputPath, isNull);
    });

    test('has_alpha defaults to false when missing', () {
      final e = parser.parseLine(
        '{"type":"complete","output_path":"/out/x.png"}',
      ) as BgCompleteEvent;
      expect(e.hasAlpha, isFalse);
    });
  });

  group('BgErrorEvent', () {
    test('parses error with traceback', () {
      final event = parser.parseLine(
        '{"type":"error","message":"Inference failed",'
        '"traceback":"Traceback..."}',
      );
      expect(event, isA<BgErrorEvent>());
      final e = event as BgErrorEvent;
      expect(e.message, 'Inference failed');
      expect(e.tracebackText, 'Traceback...');
    });

    test('defaults message when missing', () {
      final e = parser.parseLine('{"type":"error"}') as BgErrorEvent;
      expect(e.message, 'Unknown error');
    });
  });

  group('BgInfoEvent', () {
    test('parses info message', () {
      final e = parser.parseLine(
        '{"type":"info","message":"Large image detected"}',
      ) as BgInfoEvent;
      expect(e.message, 'Large image detected');
    });
  });

  group('BgUnknownEvent', () {
    test('parses unknown type into BgUnknownEvent', () {
      final e = parser.parseLine(
        '{"type":"custom_event","data":"x"}',
      ) as BgUnknownEvent;
      expect(e.raw['type'], 'custom_event');
    });

    test('parses event with no type field', () {
      final e = parser.parseLine('{"foo":"bar"}') as BgUnknownEvent;
      expect(e.raw['foo'], 'bar');
    });
  });
}
