import 'package:postgres/postgres.dart';
import 'package:backend/core/config/env_config.dart';

class PostgresRepository {
  late final PostgreSQLConnection _connection;
  bool _isConnected = false;

  PostgresRepository(EnvConfig config) {
    _connection = PostgreSQLConnection(
      config.postgresHost,
      config.postgresPort,
      config.postgresDatabase,
      username: config.postgresUsername,
      password: config.postgresPassword,
      useSSL: config.postgresUseSsl,
      timeoutInSeconds: config.postgresTimeout,
    );
  }

  Future<void> _ensureConnected() async {
    if (!_isConnected) {
      await _connection.open();
      _isConnected = true;
    }
  }

  Future<void> insert(String table, Map<String, dynamic> data) async {
    await _ensureConnected();
    final columns = data.keys.join(', ');
    final values = data.keys.map((k) => '@$k').join(', ');
    
    await _connection.execute(
      'INSERT INTO $table ($columns) VALUES ($values)',
      substitutionValues: data,
    );
  }

  Future<Map<String, dynamic>?> getById(String table, String id) async {
    await _ensureConnected();
    final result = await _connection.query(
      'SELECT * FROM $table WHERE id = @id LIMIT 1',
      substitutionValues: {'id': id},
    );
    
    return result.isNotEmpty ? result.first.toColumnMap() : null;
  }

  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _ensureConnected();
    final setClauses = updates.keys.map((k) => '$k = @$k').join(', ');
    final params = {'id': id, ...updates};
    
    await _connection.execute(
      'UPDATE $table SET $setClauses WHERE id = @id',
      substitutionValues: params,
    );
  }

  Future<void> close() async {
    if (_isConnected) {
      await _connection.close();
      _isConnected = false;
    }
  }
}
