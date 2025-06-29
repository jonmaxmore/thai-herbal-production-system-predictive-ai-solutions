import 'package:injectable/injectable.dart';
import 'package:backend/core/database/neo4j_repository.dart';
import 'package:backend/core/database/postgres_repository.dart';
import 'package:backend/core/database/redis_client.dart';
import 'package:backend/features/certification/domain/repositories/certification_repository.dart';

@Injectable(as: CertificationRepository)
class CertificationRepositoryImpl implements CertificationRepository {
  final PostgresRepository postgresRepo;
  final Neo4jRepository neo4jRepo;
  final RedisClient redisClient;

  CertificationRepositoryImpl(
    this.postgresRepo,
    this.neo4jRepo,
    this.redisClient,
  );

  @override
  Future<CertificationApplication> submit(CertificationApplication app) async {
    // บันทึกลง PostgreSQL
    await postgresRepo.insertCertification(app);
    
    // สร้าง trace ใน Neo4j
    await neo4jRepo.createCertificationTrace(app);
    
    // บันทึกแคชใน Redis
    await redisClient.cacheCertification(app);
    
    // เพิ่มในคิว AI
    await redisClient.enqueueAiProcessing(app.id);
    
    return app;
  }

  @override
  Future<void> updateStatus(String id, CertificationStatus status) async {
    // อัปเดต PostgreSQL
    await postgresRepo.updateCertificationStatus(id, status);
    
    // บันทึกเหตุการณ์ใน Neo4j
    await neo4jRepo.addCertificationEvent(
      certificationId: id,
      eventType: 'STATUS_CHANGE',
      description: 'Status changed to ${status.toString()}',
      actor: 'system',
    );
    
    // อัปเดตแคช Redis
    final app = await getById(id);
    await redisClient.cacheCertification(app);
  }

  @override
  Future<CertificationApplication> getById(String id) async {
    // ตรวจสอบแคชใน Redis
    final cachedStatus = await redisClient.getCertificationStatus(id);
    if (cachedStatus != null) {
      // ดึงข้อมูลบางส่วนจากแคช
      final app = await postgresRepo.getCertificationById(id);
      return app!.copyWith(status: cachedStatus);
    }
    
    // ดึงข้อมูลจาก PostgreSQL
    final app = await postgresRepo.getCertificationById(id);
    if (app == null) throw Exception('Certification not found');
    
    // บันทึกแคช
    await redisClient.cacheCertification(app);
    
    return app;
  }

  @override
  Future<List<Map<String, dynamic>>> getTimeline(String id) async {
    // ดึงไทม์ไลน์จาก Neo4j
    return await neo4jRepo.getCertificationTimeline(id);
  }
}
