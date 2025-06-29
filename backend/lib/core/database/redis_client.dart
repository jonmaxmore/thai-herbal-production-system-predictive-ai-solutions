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

  Future<void> cacheCertification(CertificationApplication app) async {
    await _command.send_object([
      'HSET',
      'cert:${app.id}',
      'status', app.status.name,
      'lastUpdated', DateTime.now().toIso8601String(),
    ]);
    await _command.send_object(['EXPIRE', 'cert:${app.id}', _cacheTtl.toString()]);
  }

  Future<CertificationStatus?> getCertificationStatus(String id) async {
    final status = await _command.send_object(['HGET', 'cert:$id', 'status']);
    if (status == null) return null;
    
    try {
      return CertificationStatus.values.firstWhere(
        (e) => e.name == status.toString(),
      );
    } catch (_) {
      return CertificationStatus.unknown;
    }
  }

  Future<void> enqueueAiProcessing(String certificationId) async {
    await _command.send_object(['LPUSH', 'ai-processing', certificationId]);
  }

  Future<String?> getAiResult(String certificationId) async {
    return await _command.send_object(['GET', 'ai-result:$certificationId']) as String?;
  }

  Future<void> cacheVerificationHash(String qrCode, String hash) async {
    await _command.send_object([
      'HSET',
      'verification:hashes',
      qrCode,
      hash,
    ]);
  }

  Future<void> close() async => await _command.get_connection().close();
}
