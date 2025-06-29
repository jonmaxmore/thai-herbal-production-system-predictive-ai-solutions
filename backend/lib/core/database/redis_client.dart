import 'package:redis/redis.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/features/certification/domain/entities/certification_application.dart';

class RedisClient {
  late final Command _command;
  final int _cacheTtl;

  RedisClient(EnvConfig config) : _cacheTtl = config.redisCacheTtl {
    final conn = RedisConnection();
    _command = conn.connect(config.redisHost, config.redisPort);
  }

  Future<void> _sendCommand(List<Object> command) async {
    await _command.send_object(command);
  }

  Future<Object?> _sendCommandWithReply(List<Object> command) async {
    return await _command.send_object(command);
  }

  Future<void> cacheCertification(CertificationApplication app) async {
    await _sendCommand([
      'HSET',
      'cert:${app.id}',
      'status', app.status.toString(),
      'farmerId', app.farmerId,
      'lastUpdated', DateTime.now().toIso8601String(),
    ]);
    await _sendCommand(['EXPIRE', 'cert:${app.id}', _cacheTtl.toString()]);
  }

  Future<CertificationStatus?> getCertificationStatus(String id) async {
    final status = await _sendCommandWithReply(['HGET', 'cert:$id', 'status']);
    if (status == null) return null;
    
    return CertificationStatus.values.firstWhere(
      (e) => e.toString() == status,
      orElse: () => CertificationStatus.unknown,
    );
  }

  Future<void> enqueueAiProcessing(String certificationId) async {
    await _sendCommand(['LPUSH', 'ai-processing', certificationId]);
  }

  Future<String?> dequeueAiProcessing() async {
    return await _sendCommandWithReply(['RPOP', 'ai-processing']) as String?;
  }

  Future<void> cacheAiResult(String certificationId, String result) async {
    await _sendCommand([
      'SETEX', 
      'ai-result:$certificationId', 
      (_cacheTtl ~/ 2).toString(), // ครึ่งเวลาของ cache หลัก
      result
    ]);
  }

  Future<String?> getAiResult(String certificationId) async {
    return await _sendCommandWithReply(['GET', 'ai-result:$certificationId']) as String?;
  }

  Future<void> close() async {
    await _command.get_connection().close();
  }
}
