import 'package:creator_forge/core/errors/app_exception.dart';
import 'package:creator_forge/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.validateUrl', () {
    test('accepts valid https url', () {
      final uri = Validators.validateUrl('https://www.example.com/video');
      expect(uri.host, 'www.example.com');
    });

    test('accepts valid http url', () {
      final uri = Validators.validateUrl('http://example.com');
      expect(uri.scheme, 'http');
    });

    test('throws on empty string', () {
      expect(
        () => Validators.validateUrl(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws on ftp scheme', () {
      expect(
        () => Validators.validateUrl('ftp://example.com/file'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws on missing host', () {
      expect(
        () => Validators.validateUrl('https://'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('trims whitespace before validating', () {
      final uri = Validators.validateUrl('  https://example.com  ');
      expect(uri.host, 'example.com');
    });
  });

  group('Validators.sanitizeFilename', () {
    test('replaces forbidden chars', () {
      final result = Validators.sanitizeFilename('my:video<name>');
      expect(result.contains(':'), isFalse);
      expect(result.contains('<'), isFalse);
    });

    test('handles empty string', () {
      expect(Validators.sanitizeFilename(''), 'untitled');
    });

    test('preserves normal filenames', () {
      expect(Validators.sanitizeFilename('my video.mp4'), 'my video.mp4');
    });
  });
}
