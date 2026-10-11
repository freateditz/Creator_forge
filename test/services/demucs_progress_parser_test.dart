import 'package:flutter_test/flutter_test.dart';

import 'package:creator_forge/services/separation/demucs_progress_parser.dart';

void main() {
  late DemucsProgressParser parser;

  setUp(() => parser = DemucsProgressParser());

  group('DemucsProgressParser', () {
    test('returns null for blank lines', () {
      expect(parser.parseLine(''), isNull);
      expect(parser.parseLine('   '), isNull);
    });

    test('returns null for non-JSON', () {
      expect(parser.parseLine('not json at all'), isNull);
    });

    test('returns null for JSON that is not a map', () {
      expect(parser.parseLine('[1,2,3]'), isNull);
    });

    test('parses stage event', () {
      final event = parser.parseLine(
        '{"type":"stage","stage":"loading_model","model":"htdemucs","device":"mps"}',
      );
      expect(event, isA<StageEvent>());
      final s = event as StageEvent;
      expect(s.stage, 'loading_model');
      expect(s.model, 'htdemucs');
      expect(s.device, 'mps');
    });

    test('parses stage event with no optional fields', () {
      final event = parser.parseLine('{"type":"stage","stage":"separating"}');
      expect(event, isA<StageEvent>());
      final s = event as StageEvent;
      expect(s.stage, 'separating');
      expect(s.model, isNull);
      expect(s.device, isNull);
    });

    test('parses progress event', () {
      final event = parser.parseLine(
        '{"type":"progress","stage":"separating","percent":42.5}',
      );
      expect(event, isA<ProgressEvent>());
      final p = event as ProgressEvent;
      expect(p.stage, 'separating');
      expect(p.percent, closeTo(42.5, 0.001));
    });

    test('parses complete event with stems', () {
      final event = parser.parseLine(
        '{"type":"complete","stems":{"vocals":"/out/Vocals.wav","instrumental":"/out/Instrumental.wav"}}',
      );
      expect(event, isA<CompleteEvent>());
      final c = event as CompleteEvent;
      expect(c.stems['vocals'], '/out/Vocals.wav');
      expect(c.stems['instrumental'], '/out/Instrumental.wav');
    });

    test('parses complete event with model name (download_model action)', () {
      final event = parser.parseLine('{"type":"complete","model":"htdemucs"}');
      expect(event, isA<CompleteEvent>());
      final c = event as CompleteEvent;
      expect(c.model, 'htdemucs');
      expect(c.stems, isEmpty);
    });

    test('parses error event', () {
      final event = parser.parseLine(
        '{"type":"error","message":"File not found","traceback":"...trace..."}',
      );
      expect(event, isA<ErrorEvent>());
      final e = event as ErrorEvent;
      expect(e.message, 'File not found');
      expect(e.tracebackText, '...trace...');
    });

    test('parses runtime_info event', () {
      final event = parser.parseLine(
        '{"type":"runtime_info","demucs_version":"4.1.0","torch_version":"2.1.0",'
        '"mps_available":true,"cuda_available":false,"cuda_device_count":0}',
      );
      expect(event, isA<RuntimeInfoEvent>());
      final r = event as RuntimeInfoEvent;
      expect(r.demucsVersion, '4.1.0');
      expect(r.torchVersion, '2.1.0');
      expect(r.mpsAvailable, isTrue);
      expect(r.cudaAvailable, isFalse);
      expect(r.cudaDeviceCount, 0);
    });

    test('parses info event', () {
      final event = parser.parseLine(
        '{"type":"info","message":"Resampling 44100 → 44100 Hz"}',
      );
      expect(event, isA<InfoEvent>());
      expect((event as InfoEvent).message, contains('Resampling'));
    });

    test('returns UnknownEvent for unrecognised type', () {
      final event = parser.parseLine('{"type":"mystery","foo":"bar"}');
      expect(event, isA<UnknownEvent>());
    });

    test('handles missing percent in progress gracefully', () {
      final event = parser.parseLine(
        '{"type":"progress","stage":"separating"}',
      );
      expect(event, isA<ProgressEvent>());
      expect((event as ProgressEvent).percent, 0.0);
    });

    test('handles non-map stems value gracefully', () {
      final event = parser.parseLine('{"type":"complete","stems":"bad"}');
      expect(event, isA<CompleteEvent>());
      expect((event as CompleteEvent).stems, isEmpty);
    });

    test('handles error with no message', () {
      final event = parser.parseLine('{"type":"error"}');
      expect(event, isA<ErrorEvent>());
      expect((event as ErrorEvent).message, 'Unknown error');
    });

    test('stateless — two parsers produce identical results', () {
      final a = DemucsProgressParser();
      final b = DemucsProgressParser();
      const line = '{"type":"progress","stage":"separating","percent":10.0}';
      expect(a.parseLine(line).runtimeType, b.parseLine(line).runtimeType);
    });
  });
}
