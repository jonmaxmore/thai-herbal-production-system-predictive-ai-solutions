import 'package:postgres/postgres.dart';
import 'package:backend/core/config/env_config.dart';

class PostgresRepository {
  late final PostgreSQLConnection _connection;

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

  Future<void> open() async {
    await _connection.open();
  }

  Future<void> close() async {
    await _connection.close();
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, [
    Map<String, dynamic>? parameters,
  ]) async {
    final result = await _connection.query(sql, substitutionValues: parameters);
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<int> execute(String sql, [Map<String, dynamic>? parameters]) async {
    return await _connection.execute(sql, substitutionValues: parameters);
  }

  Future<int> insertCertificationApplication(Map<String, dynamic> application) async {
    final result = await _connection.execute('''
      INSERT INTO certification_applications (
        id, farmer_id, status, submitted_at, images
      ) VALUES (
        @id, @farmer_id, @status, @submitted_at, @images
      )
    ''', application);
    
    return result;
  }

  Future<Map<String, dynamic>?> getCertificationById(String id) async {
    final results = await query(
      'SELECT * FROM certification_applications WHERE id = @id',
      {'id': id},
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateCertificationStatus(String id, String status) async {
    await execute(
      'UPDATE certification_applications SET status = @status WHERE id = @id',
      {'id': id, 'status': status},
    );
  }
}
