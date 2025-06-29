import 'package:injectable/injectable.dart';
import 'package:backend/core/database/postgres_repository.dart';
import 'package:backend/core/database/neo4j_repository.dart';
import 'package:backend/core/database/redis_client.dart';
import 'package:backend/features/certification/domain/entities/certification_application.dart';
import 'package:backend/features/certification/domain/repositories/certification_repository.dart';
import 'package:backend/core/errors/failures.dart';

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
  Future<CertificationApplication> submitApplication(
    CertificationApplication application,
  ) async {
    try {
      // 1. บันทึกลง PostgreSQL
      await postgresRepo.insertCertification(application);

      // 2. สร้าง trace ใน Neo4j
      await neo4jRepo.createCertificationTrace(application);

      // 3. บันทึกแคชใน Redis
      await redisClient.cacheCertification(application);

      // 4. เพิ่มในคิวประมวลผล AI
      await redisClient.enqueueAiProcessing(application.id);

      return application;
    } catch (e) {
      throw DatabaseFailure(
        'Failed to submit certification application: ${e.toString()}'
      );
    }
  }

  @override
  Future<CertificationApplication> getById(String id) async {
    try {
      // 1. ตรวจสอบแคชใน Redis
      final cachedStatus = await redisClient.getCertificationStatus(id);
      if (cachedStatus != null && cachedStatus != CertificationStatus.unknown) {
        final app = await postgresRepo.getCertificationById(id);
        if (app != null) {
          return app.copyWith(status: cachedStatus);
        }
      }

      // 2. ดึงข้อมูลจาก PostgreSQL
      final application = await postgresRepo.getCertificationById(id);
      if (application == null) {
        throw NotFoundFailure('Certification application not found');
      }

      // 3. อัปเดตแคชใน Redis
      await redisClient.cacheCertification(application);

      return application;
    } catch (e) {
      throw DatabaseFailure(
        'Failed to get certification by ID: ${e.toString()}'
      );
    }
  }

  @override
  Future<void> updateStatus(
    String id,
    CertificationStatus status, {
    String? actor,
    String? notes,
  }) async {
    try {
      // 1. อัปเดตสถานะใน PostgreSQL
      await postgresRepo.updateCertificationStatus(id, status);

      // 2. บันทึกเหตุการณ์ใน Neo4j
      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'STATUS_UPDATE',
        description: notes ?? 'Status changed to ${status.name}',
        actor: actor ?? 'system',
      );

      // 3. อัปเดตแคชใน Redis
      final currentApp = await getById(id);
      await redisClient.cacheCertification(
        currentApp.copyWith(status: status)
      );
    } catch (e) {
      throw DatabaseFailure(
        'Failed to update certification status: ${e.toString()}'
      );
    }
  }

  @override
  Future<void> scheduleRemoteMeeting(
    String id,
    DateTime meetingDate,
  ) async {
    try {
      // 1. อัปเดตวันที่ประชุมใน PostgreSQL
      await postgresRepo.scheduleRemoteMeeting(id, meetingDate);

      // 2. บันทึกเหตุการณ์ใน Neo4j
      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'MEETING_SCHEDULED',
        description: 'Remote meeting scheduled for ${meetingDate.toIso8601String()}',
        actor: 'system',
      );

      // 3. อัปเดตสถานะเป็น "remoteMeetingScheduled"
      await updateStatus(id, CertificationStatus.remoteMeetingScheduled);
    } catch (e) {
      throw DatabaseFailure(
        'Failed to schedule remote meeting: ${e.toString()}'
      );
    }
  }

  @override
  Future<void> uploadAdditionalImages(
    String id,
    List<String> imageUrls,
  ) async {
    try {
      // 1. ดึงข้อมูลใบสมัครปัจจุบัน
      final application = await getById(id);

      // 2. เพิ่มรูปภาพใหม่
      final updatedApp = application.copyWith(
        images: [...application.images, ...imageUrls]
      );

      // 3. อัปเดตใน PostgreSQL
      await postgresRepo.updateCertificationImages(id, imageUrls);

      // 4. บันทึกเหตุการณ์ใน Neo4j
      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'IMAGES_UPLOADED',
        description: '${imageUrls.length} additional images uploaded',
        actor: 'farmer',
      );

      // 5. อัปเดตแคชใน Redis
      await redisClient.cacheCertification(updatedApp);
    } catch (e) {
      throw DatabaseFailure(
        'Failed to upload additional images: ${e.toString()}'
      );
    }
  }

  @override
  Future<void> uploadLabResults(
    String id,
    LabResult labResults,
  ) async {
    try {
      // 1. อัปเดตผลแล็บใน PostgreSQL
      await postgresRepo.uploadLabResults(id, labResults);

      // 2. บันทึกเหตุการณ์ใน Neo4j
      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'LAB_RESULTS_UPLOADED',
        description: 'Lab results uploaded: ${labResults.passed ? "PASSED" : "FAILED"}',
        actor: 'lab_technician',
      );

      // 3. อัปเดตสถานะ
      final newStatus = labResults.passed
          ? CertificationStatus.labResultsApproved
          : CertificationStatus.rejected;
          
      await updateStatus(id, newStatus);
    } catch (e) {
      throw DatabaseFailure(
        'Failed to upload lab results: ${e.toString()}'
      );
    }
  }

  @override
  Future<void> issueCertificate(
    String id,
    String certificateUrl,
    String qrCode,
  ) async {
    try {
      // 1. อัปเดตข้อมูลใบรับรองใน PostgreSQL
      await postgresRepo.issueCertificate(id, certificateUrl, qrCode);

      // 2. บันทึกเหตุการณ์ใน Neo4j
      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'CERTIFICATE_ISSUED',
        description: 'GACP certificate issued',
        actor: 'dpm_officer',
      );

      // 3. อัปเดตสถานะ
      await updateStatus(id, CertificationStatus.certificateIssued);

      // 4. บันทึก hash สำหรับตรวจสอบ
      await redisClient.cacheVerificationHash(
        qrCode,
        certificateUrl,
      );
    } catch (e) {
      throw DatabaseFailure(
        'Failed to issue certificate: ${e.toString()}'
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCertificationTimeline(String id) async {
    try {
      // ดึงไทม์ไลน์จาก Neo4j
      return await neo4jRepo.getCertificationTimeline(id);
    } catch (e) {
      throw DatabaseFailure(
        'Failed to get certification timeline: ${e.toString()}'
      );
    }
  }

  @override
  Future<String?> getAiProcessingResult(String id) async {
    try {
      // ดึงผลลัพธ์ AI จาก Redis
      return await redisClient.getAiResult(id);
    } catch (e) {
      throw DatabaseFailure(
        'Failed to get AI processing result: ${e.toString()}'
      );
    }
  }
}
