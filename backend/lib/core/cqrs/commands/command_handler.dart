import 'package:meta/meta.dart';
import 'package:backend/core/cqrs/commands/command.dart';
import 'package:backend/core/utils/either.dart';
import 'package:backend/core/errors/failures.dart';

/// Abstract base class for all command handlers
///
/// [CommandType] is the specific command this handler can execute
/// [ResultType] is the expected return type of the command
/// [Params] are the parameters required to execute the command
abstract class CommandHandler<CommandType extends Command<ResultType, Params>, 
                              ResultType, 
                              Params> {
  
  /// Executes the command and returns the result
  ///
  /// This method should contain the core business logic
  /// for processing the command
  Future<Either<Failure, ResultType>> execute(Params params);
  
  /// Creates a concrete command instance that will use this handler
  CommandType createCommand() {
    return _CommandWrapper(this) as CommandType;
  }
}

/// Internal wrapper class that bridges the command and its handler
class _CommandWrapper<ResultType, Params> 
    implements Command<ResultType, Params> {
  final CommandHandler<Command<ResultType, Params>, ResultType, Params> _handler;

  _CommandWrapper(this._handler);

  @override
  Future<Either<Failure, ResultType>> call(Params params) async {
    return _handler.execute(params);
  }
}

/// Specialized handler for commands without parameters
abstract class NoParamsCommandHandler<CommandType extends Command<ResultType, NoParams>, 
                                      ResultType> 
    extends CommandHandler<CommandType, ResultType, NoParams> {
  
  @override
  Future<Either<Failure, ResultType>> execute(NoParams params);
  
  Future<Either<Failure, ResultType>> executeWithoutParams() {
    return execute(const NoParams());
  }
}

/// Composite command handler for executing multiple commands sequentially
class SequentialCommandHandler implements CommandHandler<Command<void, void>, void, void> {
  final List<Command<dynamic, dynamic>> commands;

  SequentialCommandHandler(this.commands);

  @override
  Future<Either<Failure, void>> execute(void _) async {
    for (final command in commands) {
      final result = await command.call(_);
      if (result.isLeft()) {
        return Left((result as Left).value);
      }
    }
    return const Right(null);
  }
}

/// Composite command handler for executing multiple commands in parallel
class ParallelCommandHandler implements CommandHandler<Command<void, void>, void, void> {
  final List<Command<dynamic, dynamic>> commands;

  ParallelCommandHandler(this.commands);

  @override
  Future<Either<Failure, void>> execute(void _) async {
    final results = await Future.wait(
      commands.map((cmd) => cmd.call(_)),
    );

    for (final result in results) {
      if (result.isLeft()) {
        return Left((result as Left).value);
      }
    }
    
    return const Right(null);
  }
}

/// Command handler with built-in retry mechanism
class RetryCommandHandler<CommandType extends Command<ResultType, Params>, 
                          ResultType, 
                          Params> 
    extends CommandHandler<CommandType, ResultType, Params> {
  final CommandHandler<CommandType, ResultType, Params> _innerHandler;
  final int maxRetries;
  final Duration delay;

  RetryCommandHandler(
    this._innerHandler, {
    this.maxRetries = 3,
    this.delay = const Duration(seconds: 1),
  });

  @override
  Future<Either<Failure, ResultType>> execute(Params params) async {
    int attempt = 0;
    while (true) {
      attempt++;
      final result = await _innerHandler.execute(params);
      
      if (result.isRight() || attempt >= maxRetries) {
        return result;
      }
      
      // Log warning and retry
      final failure = (result as Left).value;
      print('⚠️ Command failed (attempt $attempt/$maxRetries): ${failure.message}');
      print('⏳ Retrying in ${delay.inMilliseconds}ms...');
      
      await Future.delayed(delay);
    }
  }
}

/// Command handler with transaction support
class TransactionalCommandHandler<CommandType extends Command<ResultType, Params>, 
                                  ResultType, 
                                  Params> 
    extends CommandHandler<CommandType, ResultType, Params> {
  final CommandHandler<CommandType, ResultType, Params> _innerHandler;
  final Future<void> Function() beginTransaction;
  final Future<void> Function() commitTransaction;
  final Future<void> Function() rollbackTransaction;

  TransactionalCommandHandler(
    this._innerHandler, {
    required this.beginTransaction,
    required this.commitTransaction,
    required this.rollbackTransaction,
  });

  @override
  Future<Either<Failure, ResultType>> execute(Params params) async {
    try {
      await beginTransaction();
      final result = await _innerHandler.execute(params);
      
      if (result.isLeft()) {
        await rollbackTransaction();
        return result;
      }
      
      await commitTransaction();
      return result;
    } catch (e) {
      await rollbackTransaction();
      return Left(TransactionFailure('Transaction failed: $e'));
    }
  }
}

/// Factory for creating command handlers with decorators
class CommandHandlerFactory {
  final Map<Type, CommandHandler<dynamic, dynamic, dynamic>> _handlers;

  CommandHandlerFactory(this._handlers);

  /// Creates a command handler with optional decorators
  CommandHandler<CommandType, ResultType, Params> createHandler<CommandType, ResultType, Params>(
    Type handlerType, {
    bool transactional = false,
    bool retryable = false,
    int maxRetries = 3,
  }) {
    final baseHandler = _handlers[handlerType] 
        as CommandHandler<CommandType, ResultType, Params>;
    
    CommandHandler<CommandType, ResultType, Params> handler = baseHandler;
    
    if (retryable) {
      handler = RetryCommandHandler(
        handler,
        maxRetries: maxRetries,
      ) as CommandHandler<CommandType, ResultType, Params>;
    }
    
    if (transactional) {
      // In a real application, these would be injected dependencies
      handler = TransactionalCommandHandler(
        handler,
        beginTransaction: () async => print('Beginning transaction'),
        commitTransaction: () async => print('Committing transaction'),
        rollbackTransaction: () async => print('Rolling back transaction'),
      ) as CommandHandler<CommandType, ResultType, Params>;
    }
    
    return handler;
  }
}
