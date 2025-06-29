import 'package:backend/core/di/injector.dart';
import 'package:backend/core/database/postgres_repository.dart';
import 'package:backend/core/database/neo4j_repository.dart';
import 'package:backend/core/database/redis_client.dart';
import 'package:backend/core/utils/logger.dart';

class HealthService {
  final PostgresRepository _postgres;
  final Neo4jRepository _neo4j;
  final RedisClient _redis;
  final Logger _logger;

  HealthService()
      : _postgres = injector<PostgresRepository>(),
        _neo4j = injector<Neo4jRepository>(),
        _redis = injector<RedisClient>(),
        _logger = injector<Logger>();

  Future<Map<String, dynamic>> check() async {
    final results = <String, dynamic>{};
    
    try {
      // PostgreSQL health check
      final pgResult = await _postgres.query('SELECT 1');
      results['postgres'] = pgResult.isNotEmpty ? 'healthy' : 'unhealthy';
    } catch (e) {
      results['postgres'] = 'unhealthy';
      _logger.error('PostgreSQL health check failed', error: e);
    }
    
    try {
      // Neo4j health check
      await _neo4j.executeRead('RETURN 1');
      results['neo4j'] = 'healthy';
    } catch (e) {
      results['neo4j'] = 'unhealthy';
      _logger.error('Neo4j health check failed', error: e);
    }
    
    try {
      // Redis health check
      await _redis.get('health-check');
      results['redis'] = 'healthy';
    } catch (e) {
      results['redis'] = 'unhealthy';
      _logger.error('Redis health check failed', error: e);
    }
    
    // Overall status
    results['status'] = results.values.every((v) => v == 'healthy')
        ? 'healthy'
        : 'degraded';
    
    return results;
  }
}
