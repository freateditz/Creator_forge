sealed class AppException implements Exception {
  final String message;
  final String? technicalDetails;
  final Object? cause;

  const AppException(this.message, {this.technicalDetails, this.cause});

  @override
  String toString() => 'AppException($message)';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.technicalDetails, super.cause});
}

class DownloadException extends AppException {
  const DownloadException(super.message, {super.technicalDetails, super.cause});
}

class MediaException extends AppException {
  const MediaException(super.message, {super.technicalDetails, super.cause});
}

class ProcessingException extends AppException {
  const ProcessingException(
    super.message, {
    super.technicalDetails,
    super.cause,
  });
}

class StorageException extends AppException {
  final bool isInsufficientSpace;

  const StorageException(
    super.message, {
    super.technicalDetails,
    super.cause,
    this.isInsufficientSpace = false,
  });
}

class ValidationException extends AppException {
  final String field;

  const ValidationException(
    super.message, {
    required this.field,
    super.technicalDetails,
  });
}

class DependencyException extends AppException {
  final String dependency;

  const DependencyException(
    super.message, {
    required this.dependency,
    super.technicalDetails,
  });
}

class AuthRequiredException extends AppException {
  const AuthRequiredException(super.message, {super.technicalDetails});
}

class DrmProtectedException extends AppException {
  const DrmProtectedException(super.message, {super.technicalDetails});
}

class CancelledException extends AppException {
  const CancelledException() : super('Operation was cancelled.');
}
