import 'dart:convert';
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

  CertificationStatus _parseStatus(String status) {
    return CertificationStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => CertificationStatus.unknown,
    );
  }

  CertificationApplication _mapToApplication(Map<String, dynamic> data) {
    return CertificationApplication(
      id: data['id'] as String,
      farmerId: data['farmer_id'] as String,
      farmerName: data['farmer_name'] as String,
      status: _parseStatus(data['status'] as String),
      herbIds: List<String>.from(jsonDecode(data['herb_ids'] as String)),
      images: List<String>.from(jsonDecode(data['images'] as String)),
      remoteMeetingDate: data['remote_meeting_date'] != null
          ? DateTime.parse(data['remote_meeting_date'] as String)
          : null,
      inspectionDate: data['inspection_date'] != null
          ? DateTime.parse(data['inspection_date'] as String)
          : null,
      labResults: data['lab_results'] != null
          ? LabResult.fromJson(jsonDecode(data['lab_results'] as String))
          : null,
      certificateUrl: data['certificate_url'] as String?,
      qrCode: data['qr_code'] as String?,
    );
  }

  @override
  Future<CertificationApplication> submitApplication(
    CertificationApplication application,
  ) async {
    try {
      await postgresRepo.insert('certifications', {
        'id': application.id,
        'farmer_id': application.farmerId,
        'farmer_name': application.farmerName,
        'status': application.status.name,
        'herb_ids': jsonEncode(application.herbIds),
        'images': jsonEncode(application.images),
        'submitted_at': DateTime.now().toIso8601String(),
      });

      await neo4jRepo.createCertificationTrace(application);
      await redisClient.cacheCertification(application);
      await redisClient.enqueueAiProcessing(application.id);

      return application;
    } catch (e) {
      throw DatabaseFailure('Failed to submit application: ${e.toString()}');
    }
  }

  @override
  Future<CertificationApplication> getById(String id) async {
    try {
      final cachedStatus = await redisClient.getCertificationStatus(id);
      if (cachedStatus != null && cachedStatus != CertificationStatus.unknown) {
        final data = await postgresRepo.getById('certifications', id);
        if (data != null) {
          return _mapToApplication(data).copyWith(status: cachedStatus);
        }
      }

      final data = await postgresRepo.getById('certifications', id);
      if (data == null) throw NotFoundFailure('Application not found');
      
      final application = _mapToApplication(data);
      await redisClient.cacheCertification(application);
      
      return application;
    } catch (e) {
      throw DatabaseFailure('Failed to get application: ${e.toString()}');
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
      await postgresRepo.update('certifications', id, {'status': status.name});
      
      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'STATUS_UPDATE',
        description: notes ?? 'Status changed to ${status.name}',
        actor: actor ?? 'system',
      );

      final app = await getById(id);
      await redisClient.cacheCertification(app.copyWith(status: status));
    } catch (e) {
      throw DatabaseFailure('Failed to update status: ${e.toString()}');
    }
  }

  @override
  Future<void> scheduleRemoteMeeting(
    String id,
    DateTime meetingDate,
  ) async {
    try {
      await postgresRepo.update(
        'certifications',
        id,
        {'remote_meeting_date': meetingDate.toIso8601String()},
      );

      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'MEETING_SCHEDULED',
        description: 'Meeting scheduled for ${meetingDate.toIso8601String()}',
        actor: 'system',
      );

      await updateStatus(id, CertificationStatus.remoteMeetingScheduled);
    } catch (e) {
      throw DatabaseFailure('Failed to schedule meeting: ${e.toString()}');
    }
  }

  @override
  Future<void> uploadAdditionalImages(
    String id,
    List<String> imageUrls,
  ) async {
    try {
      final app = await getById(id);
      final updatedImages = [...app.images, ...imageUrls];
      
      await postgresRepo.update(
        'certifications',
        id,
        {'images': jsonEncode(updatedImages)},
      );

      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'IMAGES_UPLOADED',
        description: '${imageUrls.length} images uploaded',
        actor: 'farmer',
      );

      await redisClient.cacheCertification(app.copyWith(images: updatedImages));
    } catch (e) {
      throw DatabaseFailure('Failed to upload images: ${e.toString()}');
    }
  }

  @override
  Future<void> uploadLabResults(
    String id,
    LabResult labResults,
  ) async {
    try {
      await postgresRepo.update(
        'certifications',
        id,
        {'lab_results': jsonEncode(labResults.toJson())},
      );

      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'LAB_RESULTS_UPLOADED',
        description: 'Lab results ${labResults.passed ? 'PASSED' : 'FAILED'}',
        actor: 'lab_technician',
      );

      final newStatus = labResults.passed
          ? CertificationStatus.labResultsApproved
          : CertificationStatus.rejected;
          
      await updateStatus(id, newStatus);
    } catch (e) {
      throw DatabaseFailure('Failed to upload lab results: ${e.toString()}');
    }
  }

  @override
  Future<void> issueCertificate(
    String id,
    String certificateUrl,
    String qrCode,
  ) async {
    try {
      final now = DateTime.now().toIso8601String();
      await postgresRepo.update('certifications', id, {
        'certificate_url': certificateUrl,
        'qr_code': qrCode,
        'issued_at': now,
        'status': CertificationStatus.certificateIssued.name,
      });

      await neo4jRepo.addCertificationEvent(
        certificationId: id,
        eventType: 'CERTIFICATE_ISSUED',
        description: 'Certificate issued',
        actor: 'dpm_officer',
      );

      final app = await getById(id);
      await redisClient.cacheCertification(app.copyWith(
        status: CertificationStatus.certificateIssued,
        certificateUrl: certificateUrl,
        qrCode: qrCode,
      ));

      await redisClient.cacheVerificationHash(qrCode, certificateUrl);
    } catch (e) {
      throw DatabaseFailure('Failed to issue certificate: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCertificationTimeline(String id) async {
    try {
      return await neo4jRepo.getCertificationTimeline(id);
    } catch (e) {
      throw DatabaseFailure('Failed to get timeline: ${e.toString()}');
    }
  }

  @override
  Future<String?> getAiProcessingResult(String id) async {
    try {
      return await redisClient.getAiResult(id);
    } catch (e) {
      throw DatabaseFailure('Failed to get AI result: ${e.toString()}');
    }
  }
}
