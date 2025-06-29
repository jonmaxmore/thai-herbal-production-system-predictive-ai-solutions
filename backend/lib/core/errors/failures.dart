abstract class Failure implements Exception {
  final String message;
  Failure(this.message);
}

class DatabaseFailure extends Failure {
  DatabaseFailure(super.message);
}

class NotFoundFailure extends Failure {
  NotFoundFailure(super.message);
}

class ValidationFailure extends Failure {
  ValidationFailure(super.message);
}
