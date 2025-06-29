import 'package:postgres/postgres.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/core/errors/exceptions.dart';
import 'package:backend/core/errors/failures.dart';
import 'package:backend/core/utils/either.dart';
import 'package:backend/core/utils/logger.dart';

/// Abstract base class for PostgreSQL repositories
abstract class PostgresRepository {
  Future<Either<Failure, List<Map<String, dynamic>>>> query(
    String sql, {
    Map<String, dynamic>? parameters,
  });
  
  Future<Either<Failure, int>> execute(
    String sql, {
    Map<String, dynamic>? parameters,
  });
  
  Future<Either<Failure, T>> transaction<T>(
    Future<Either<Failure, T>> Function(PostgreSQLExecutionContext) fn,
  );
}

/// Implementation of PostgreSQL repository
class PostgresRepositoryImpl implements PostgresRepository {
  final EnvConfig _config;
  late PostgreSQLConnection _connection;
  bool _isConnected = false;

  PostgresRepositoryImpl(this._config);

  /// Initialize and connect to the PostgreSQL database
  Future<void> _connect() async {
    if (_isConnected) return;

    try {
      _connection = PostgreSQLConnection(
        _config.postgresHost,
        _config.postgresPort,
        _config.postgresDatabase,
        username: _config.postgresUsername,
        password: _config.postgresPassword,
        useSSL: _config.postgresUseSsl,
        timeoutInSeconds: _config.postgresTimeout,
        queryTimeoutInSeconds: _config.postgresQueryTimeout,
      );

      await _connection.open();
      _isConnected = true;
      
      // Test connection
      final result = await _connection.query('SELECT 1');
      if (result.isEmpty) throw PostgresConnectionException('Connection test failed');
      
      Logger.info('✅ Successfully connected to PostgreSQL database');
    } catch (e) {
      _isConnected = false;
      throw PostgresConnectionException('Failed to connect to PostgreSQL: $e');
    }
  }

  /// Execute a SQL query and return the results
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> query(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      if (!_isConnected) await _connect();
      
      final results = await _connection.query(
        sql,
        substitutionValues: parameters,
      );
      
      return Right(_convertResultsToMap(results));
    } on PostgreSQLException catch (e) {
      Logger.error('PostgreSQL query error: ${e.message}');
      return Left(PostgresFailure('Query failed: ${e.message}'));
    } catch (e) {
      Logger.error('Unexpected error during PostgreSQL query: $e');
      return Left(UnhandledFailure('Unexpected error: $e'));
    }
  }

  /// Execute a SQL command and return the number of affected rows
  @override
  Future<Either<Failure, int>> execute(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      if (!_isConnected) await _connect();
      
      final result = await _connection.execute(
        sql,
        substitutionValues: parameters,
      );
      
      return Right(result);
    } on PostgreSQLException catch (e) {
      Logger.error('PostgreSQL execute error: ${e.message}');
      return Left(PostgresFailure('Execute failed: ${e.message}'));
    } catch (e) {
      Logger.error('Unexpected error during PostgreSQL execute: $e');
      return Left(UnhandledFailure('Unexpected error: $e'));
    }
  }

  /// Execute operations within a transaction
  @override
  Future<Either<Failure, T>> transaction<T>(
    Future<Either<Failure, T>> Function(PostgreSQLExecutionContext) fn,
  ) async {
    try {
      if (!_isConnected) await _connect();
      
      return await _connection.transaction((ctx) async {
        final result = await fn(ctx);
        return result.fold(
          (failure) => throw PostgresTransactionException(failure.message),
          (success) => success,
        );
      }).then((value) => Right(value)).catchError((e) {
        if (e is PostgresTransactionException) {
          return Left(PostgresFailure(e.message));
        }
        return Left(UnhandledFailure('Transaction failed: $e'));
      });
    } on PostgreSQLException catch (e) {
      Logger.error('PostgreSQL transaction error: ${e.message}');
      return Left(PostgresFailure('Transaction failed: ${e.message}'));
    } catch (e) {
      Logger.error('Unexpected error during PostgreSQL transaction: $e');
      return Left(UnhandledFailure('Unexpected error: $e'));
    }
  }

  /// Convert PostgreSQL results to list of maps
  List<Map<String, dynamic>> _convertResultsToMap(List<List<dynamic>> results) {
    return results.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < row.length; i++) {
        final columnName = _connection.lastQuery!.columnDescriptions[i].columnName;
        map[columnName] = row[i];
      }
      return map;
    }).toList();
  }

  /// Close the database connection
  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      await _connection.close();
      _isConnected = false;
      Logger.info('🔌 Disconnected from PostgreSQL database');
    } catch (e) {
      Logger.error('Failed to disconnect from PostgreSQL: $e');
    }
  }
}

/// Extension for query building
extension PostgresQueryBuilder on String {
  /// Generate SELECT query
  String select({
    required String table,
    List<String> columns = const ['*'],
    String? where,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final cols = columns.join(', ');
    var query = 'SELECT $cols FROM $table';
    
    if (where != null && where.isNotEmpty) {
      query += ' WHERE $where';
    }
    
    if (orderBy != null && orderBy.isNotEmpty) {
      query += ' ORDER BY $orderBy';
    }
    
    if (limit != null) {
      query += ' LIMIT $limit';
    }
    
    if (offset != null) {
      query += ' OFFSET $offset';
    }
    
    return query;
  }

  /// Generate INSERT query
  String insert({
    required String table,
    required Map<String, dynamic> values,
    String? returning,
  }) {
    final columns = values.keys.join(', ');
    final placeholders = values.keys.map((key) => '@$key').join(', ');
    
    var query = 'INSERT INTO $table ($columns) VALUES ($placeholders)';
    
    if (returning != null && returning.isNotEmpty) {
      query += ' RETURNING $returning';
    }
    
    return query;
  }

  /// Generate UPDATE query
  String update({
    required String table,
    required Map<String, dynamic> setValues,
    required String where,
    String? returning,
  }) {
    final setClause = setValues.keys
        .map((key) => '$key = @$key')
        .join(', ');
    
    var query = 'UPDATE $table SET $setClause WHERE $where';
    
    if (returning != null && returning.isNotEmpty) {
      query += ' RETURNING $returning';
    }
    
    return query;
  }

  /// Generate DELETE query
  String delete({
    required String table,
    required String where,
    String? returning,
  }) {
    var query = 'DELETE FROM $table WHERE $where';
    
    if (returning != null && returning.isNotEmpty) {
      query += ' RETURNING $returning';
    }
    
    return query;
  }
}

/// Extension for handling common data types
extension PostgresTypeHandling on Map<String, dynamic> {
  /// Convert Dart DateTime to PostgreSQL timestamp
  void convertDatesToPgTimestamps() {
    forEach((key, value) {
      if (value is DateTime) {
        this[key] = value.toUtc();
      }
    });
  }

  /// Handle list values for PostgreSQL arrays
  void convertListsToPgArrays() {
    forEach((key, value) {
      if (value is List) {
        this[key] = PostgreSQLArray(value);
      }
    });
  }

  /// Prepare parameters for PostgreSQL queries
  void prepareForPgQuery() {
    convertDatesToPgTimestamps();
    convertListsToPgArrays();
  }
}
