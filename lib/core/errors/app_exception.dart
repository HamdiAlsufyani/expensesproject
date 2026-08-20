class AppException implements Exception {
  const AppException(this.code, {this.cause});
  final String code;
  final Object? cause;

  @override
  String toString() => 'AppException($code)';
}

class ValidationException extends AppException {
  const ValidationException(super.code, {super.cause});
}

class DatabaseException extends AppException {
  const DatabaseException(super.code, {super.cause});
}

class BackupException extends AppException {
  const BackupException(super.code, {super.cause});
}

class DriveException extends AppException {
  const DriveException(super.code, {super.cause});
}
