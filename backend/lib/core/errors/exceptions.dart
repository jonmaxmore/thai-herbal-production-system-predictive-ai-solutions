// exceptions.dart
class AppException implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  AppException(this.message, {this.code, this.stackTrace});
  
  @override
  String toString() => 'AppException: $message${code != null ? ' ($code)' : ''}';
}

class ConfigValidationException extends AppException {
  final List<String> errors;
  
  ConfigValidationException(String message, {required this.errors})
      : super('$message. Errors: ${errors.join('; ')}');
}

class DatabaseConnectionException extends AppException {
  DatabaseConnectionException(String message, {String? code, StackTrace? st})
      : super(message, code: code, stackTrace: st);
}

class DatabaseQueryException extends AppException {
  DatabaseQueryException(String message, {String? code, StackTrace? st})
      : super(message, code: code, stackTrace: st);
}

class AuthenticationException extends AppException {
  AuthenticationException(String message, {String? code, StackTrace? st})
      : super(message, code: code, stackTrace: st);
}

// failures.dart
abstract class Failure {
  final String message;
  final String? code;
  
  Failure(this.message, {this.code});
}

class DatabaseFailure extends Failure {
  DatabaseFailure(String message, {String? code}) : super(message, code: code);
}

class NetworkFailure extends Failure {
  NetworkFailure(String message, {String? code}) : super(message, code: code);
}

class ValidationFailure extends Failure {
  ValidationFailure(String message, {String? code}) : super(message, code: code);
}

class AuthenticationFailure extends Failure {
  AuthenticationFailure(String message, {String? code}) : super(message, code: code);
}
