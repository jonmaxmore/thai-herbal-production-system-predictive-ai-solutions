import 'package:neo4j_dart/neo4j_dart.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/core/errors/exceptions.dart';
import 'package:backend/core/utils/logger.dart';

class Neo4jRepository {
  late final Driver _driver;
  final EnvConfig _config;
  final Logger _logger;

  Neo4jRepository(this._config, this._logger);

  Future<void> initialize() async {
    try {
      _driver = Driver(
        Uri.parse(_config.neo4jUri),
        AuthToken.basic(_config.neo4jUsername, _config.neo4jPassword),
      );
      
      // Test connection
      final session = _driver.session();
      await session.run('RETURN 1');
      await session.close();
    } catch (e) {
      throw DatabaseConnectionException(
        'Failed to connect to Neo4j: ${e.toString()}'
      );
    }
  }

  Future<Session> getSession() {
    return _driver.session();
  }

  Future<List<Record>> executeRead(
    String query, {
    Map<String, dynamic> parameters = const {},
    Duration? timeout,
  }) async {
    final session = getSession();
    try {
      return await session.readTransaction((tx) async {
        final result = await tx.run(query, parameters: parameters);
        return result.records;
      });
    } catch (e) {
      _logger.error('Neo4j read query failed: $query', error: e);
      throw DatabaseQueryException('Neo4j query failed: ${e.toString()}');
    } finally {
      await session.close();
    }
  }

  Future<void> executeWrite(
    String query, {
    Map<String, dynamic> parameters = const {},
    Duration? timeout,
  }) async {
    final session = getSession();
    try {
      await session.writeTransaction((tx) async {
        await tx.run(query, parameters: parameters);
      });
    } catch (e) {
      _logger.error('Neo4j write query failed: $query', error: e);
      throw DatabaseQueryException('Neo4j write failed: ${e.toString()}');
    } finally {
      await session.close();
    }
  }

  Future<void> close() async {
    await _driver.close();
  }
}
