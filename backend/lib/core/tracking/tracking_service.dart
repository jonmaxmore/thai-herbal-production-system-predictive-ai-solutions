import 'package:thai_herbal_backend/core/database/redis_client.dart';
import 'package:thai_herbal_backend/models/certification.dart';

class TrackingService {
  final RedisClient _redisClient;

  TrackingService(this._redisClient);

  Future<void> enableTracking(CertificationApplication application) async {
    await _redisClient.set(
      'cert:${application.id}',
      json.encode({
        'certificate_id': application.id,
        'farmer_id': application.farmerId,
        'issue_date': DateTime.now().toIso8601String(),
        'valid_until': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        'status': 'active',
        'verification_count': 0,
      }),
    );
  }

  Future<Map<String, dynamic>> verifyCertificate(String qrCode) async {
    final data = await _redisClient.get(qrCode);
    if (data == null) return {'valid': false};
    
    final certData = json.decode(data) as Map<String, dynamic>;
    await _redisClient.set(
      qrCode,
      json.encode({
        ...certData,
        'verification_count': (certData['verification_count'] as int) + 1,
        'last_verified': DateTime.now().toIso8601String(),
      }),
    );
    
    return {
      'valid': true,
      'certificate_id': certData['certificate_id'],
      'farmer_id': certData['farmer_id'],
      'issue_date': certData['issue_date'],
      'valid_until': certData['valid_until'],
    };
  }

  Future<void> revokeCertificate(int certificateId) async {
    await _redisClient.set(
      'cert:$certificateId',
      json.encode({
        'status': 'revoked',
        'revoked_at': DateTime.now().toIso8601String(),
      }),
    );
  }
}
