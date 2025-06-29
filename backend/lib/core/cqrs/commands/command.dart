import 'package:meta/meta.dart';
import 'package:backend/core/errors/failures.dart';
import 'package:backend/core/utils/either.dart';

/// Abstract base class for all commands in the CQRS pattern
///
/// Commands represent intentions to change the state of the system.
/// They should be named in the imperative mood (e.g., CreateHerb, UpdateCertificate).
///
/// [ResultType] is the expected return type of the command execution
/// [Params] are the parameters required to execute the command
abstract class Command<ResultType, Params> {
  const Command();

  /// Executes the command with the provided parameters
  ///
  /// Returns [Either] containing:
  /// - Right(ResultType) on success
  /// - Left(Failure) on failure
  Future<Either<Failure, ResultType>> call(Params params);
}

/// Marker interface for command handlers
///
/// Each command should have a corresponding handler
/// that implements this interface
abstract class CommandHandler {}

/// Special case for commands that don't require parameters
class NoParams {
  const NoParams();
}

/// Base class for command parameters
///
/// Provides validation capabilities for command parameters
abstract class CommandParams {
  const CommandParams();

  /// Validates the parameters and returns a list of validation errors
  ///
  /// Return an empty list if validation passes
  List<String> validate();
}

/// Extension for easy validation of command parameters
extension CommandParamsValidation on CommandParams {
  /// Checks if the parameters are valid
  bool get isValid => validate().isEmpty;

  /// Throws an [InvalidParamsException] if validation fails
  void ensureValid() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw InvalidParamsException(errors);
    }
  }
}

/// Exception thrown when command parameters are invalid
class InvalidParamsException implements Exception {
  final List<String> errors;

  InvalidParamsException(this.errors);

  @override
  String toString() => 'Invalid command parameters: ${errors.join(', ')}';
}

/// Decorator class for command logging
class LoggingCommandDecorator<ResultType, Params> 
    implements Command<ResultType, Params> {
  final Command<ResultType, Params> _decorated;
  final String _commandName;

  LoggingCommandDecorator(this._decorated, {String? commandName})
      : _commandName = commandName ?? _decorated.runtimeType.toString();

  @override
  Future<Either<Failure, ResultType>> call(Params params) async {
    print('[$_commandName] Executing command with params: $params');
    final startTime = DateTime.now();

    try {
      final result = await _decorated(params);
      
      final duration = DateTime.now().difference(startTime);
      print('[$_commandName] Command executed in ${duration.inMilliseconds}ms');
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('[$_commandName] Command failed after ${duration.inMilliseconds}ms: $e');
      rethrow;
    }
  }
}

/// Decorator class for command validation
class ValidatingCommandDecorator<ResultType, Params extends CommandParams> 
    implements Command<ResultType, Params> {
  final Command<ResultType, Params> _decorated;

  ValidatingCommandDecorator(this._decorated);

  @override
  Future<Either<Failure, ResultType>> call(Params params) {
    final errors = params.validate();
    if (errors.isNotEmpty) {
      return Future.value(Left(ValidationFailure(errors)));
    }
    
    return _decorated(params);
  }
}

/// Factory for creating decorated commands
class CommandFactory {
  final Map<Type, CommandHandler> _handlers;

  CommandFactory(this._handlers);

  /// Creates a fully decorated command ready for execution
  Command<ResultType, Params> createCommand<ResultType, Params>(
    Type commandType, {
    bool logging = true,
    bool validation = true,
  }) {
    final command = _handlers[commandType] as Command<ResultType, Params>;

    Command<ResultType, Params> decorated = command;
    
    if (validation && Params != NoParams && Params != dynamic) {
      decorated = ValidatingCommandDecorator(decorated);
    }
    
    if (logging) {
      decorated = LoggingCommandDecorator(
        decorated,
        commandName: commandType.toString(),
      );
    }
    
    return decorated;
  }
}
