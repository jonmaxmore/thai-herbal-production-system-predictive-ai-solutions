import 'package:postgres/postgres.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/core/errors/exceptions.dart';
import 'package:backend/core/errors/failures.dart';

class PostgresRepository {
  late PostgreSQLConnection _connection;
  bool _isConnected = false;
  final EnvConfig _config;

  PostgresRepository(this._config);

  Future<void> connect() async {
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
      );
      
      await _connection.open();
      _isConnected = true;
      
      // Verify connection
      await _connection.query('SELECT 1');
    } catch (e) {
      throw DatabaseConnectionException(
        'Failed to connect to PostgreSQL: ${e.toString()}'
      );
    }
  }

  Future<void> disconnect() async {
    if (_isConnected) {
      await _connection.close();
      _isConnected = false;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? parameters,
    Duration? timeout,
  }) async {
    try {
      await _ensureConnected();
      final result = await _connection.query(
        sql,
        substitutionValues: parameters,
        timeoutInSeconds: timeout?.inSeconds,
      );
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      throw DatabaseQueryException(
        'PostgreSQL query failed: $sql\nError: ${e.toString()}'
      );
    }
  }

  Future<int> execute(
    String sql, {
    Map<String, dynamic>? parameters,
    Duration? timeout,
  }) async {
    try {
      await _ensureConnected();
      return await _connection.execute(
        sql,
        substitutionValues: parameters,
        timeoutInSeconds: timeout?.inSeconds,
      );
    } catch (e) {
      throw DatabaseQueryException(
        'PostgreSQL execute failed: $sql\nError: ${e.toString()}'
      );
    }
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    await _ensureConnected();
    return await _connection.transaction(action);
  }

  Future<void> _ensureConnected() async {
    if (!_isConnected) await connect();
  }
}
