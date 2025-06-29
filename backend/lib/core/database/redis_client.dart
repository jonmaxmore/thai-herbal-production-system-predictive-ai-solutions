import 'package:redis/redis.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/core/errors/exceptions.dart';
import 'package:backend/core/utils/logger.dart';

class RedisClient {
  final EnvConfig _config;
  final Logger _logger;
  late Command _command;
  bool _isConnected = false;

  RedisClient(this._config, this._logger);

  Future<void> connect() async {
    if (_isConnected) return;
    
    try {
      final conn = RedisConnection();
      _command = await conn.connect(_config.redisHost, _config.redisPort);
      _isConnected = true;
      
      // Test connection
      await _command.send_object(['PING']);
    } catch (e) {
      throw DatabaseConnectionException(
        'Failed to connect to Redis: ${e.toString()}'
      );
    }
  }

  Future<void> disconnect() async {
    if (_isConnected) {
      await _command.get_connection().close();
      _isConnected = false;
    }
  }

  Future<T> _withConnection<T>(Future<T> Function() action) async {
    if (!_isConnected) await connect();
    
    try {
      return await action();
    } catch (e) {
      _logger.error('Redis operation failed', error: e);
      throw DatabaseQueryException('Redis operation failed: ${e.toString()}');
    }
  }

  Future<void> set(String key, String value, [int? ttl]) async {
    await _withConnection(() async {
      await _command.send_object(['SET', key, value]);
      if (ttl != null) {
        await _command.send_object(['EXPIRE', key, ttl.toString()]);
      }
    });
  }

  Future<String?> get(String key) async {
    return await _withConnection(() async {
      return await _command.send_object(['GET', key]) as String?;
    });
  }

  Future<void> hset(String key, Map<String, String> fields) async {
    await _withConnection(() async {
      final args = ['HSET', key];
      fields.forEach((field, value) {
        args.add(field);
        args.add(value);
      });
      await _command.send_object(args);
    });
  }

  Future<Map<String, String>> hgetall(String key) async {
    return await _withConnection(() async {
      final result = await _command.send_object(['HGETALL', key]);
      final Map<String, String> map = {};
      
      if (result is List) {
        for (var i = 0; i < result.length; i += 2) {
          map[result[i].toString()] = result[i + 1].toString();
        }
      }
      
      return map;
    });
  }

  Future<void> enqueue(String queueName, String value) async {
    await _withConnection(() async {
      await _command.send_object(['LPUSH', queueName, value]);
    });
  }

  Future<String?> dequeue(String queueName) async {
    return await _withConnection(() async {
      return await _command.send_object(['RPOP', queueName]) as String?;
    });
  }
}
