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

  Future<int> insertCertification(CertificationApplication app) async {
    final result = await _connection.execute('''
      INSERT INTO certifications (
        id, farmer_id, status, submitted_at, herb_ids, images, 
        meeting_date, inspection_date, lab_results, certificate_url
      ) VALUES (
        @id, @farmerId, @status, @submittedAt, @herbIds, @images,
        @meetingDate, @inspectionDate, @labResults, @certificateUrl
      )
    ''', {
      'id': app.id,
      'farmerId': app.farmerId,
      'status': app.status.toString(),
      'submittedAt': DateTime.now(),
      'herbIds': app.herbIds.join(','),
      'images': app.images.join(','),
      'meetingDate': app.remoteMeetingDate,
      'inspectionDate': app.inspectionDate,
      'labResults': app.labResults?.toJson(),
      'certificateUrl': app.certificateUrl,
    });
    
    return result;
  }

  Future<CertificationApplication?> getCertificationById(String id) async {
    final results = await query(
      'SELECT * FROM certifications WHERE id = @id',
      {'id': id},
    );
    
    if (results.isEmpty) return null;
    
    final data = results.first;
    return CertificationApplication(
      id: data['id'],
      farmerId: data['farmer_id'],
      status: CertificationStatus.values.firstWhere(
        (e) => e.toString() == data['status']
      ),
      herbIds: (data['herb_ids'] as String).split(','),
      images: (data['images'] as String).split(','),
      remoteMeetingDate: data['meeting_date'],
      inspectionDate: data['inspection_date'],
      labResults: data['lab_results'] != null 
          ? LabResult.fromJson(data['lab_results'] as Map<String, dynamic>)
          : null,
      certificateUrl: data['certificate_url'],
    );
  }

  Future<void> updateCertificationStatus(String id, CertificationStatus status) async {
    await execute(
      'UPDATE certifications SET status = @status WHERE id = @id',
      {'id': id, 'status': status.toString()},
    );
  }

  Future<void> scheduleInspection(String id, DateTime date) async {
    await execute(
      'UPDATE certifications SET inspection_date = @date WHERE id = @id',
      {'id': id, 'date': date},
    );
  }

  Future<void> uploadLabResults(String id, LabResult results) async {
    await execute(
      'UPDATE certifications SET lab_results = @results WHERE id = @id',
      {'id': id, 'results': results.toJson()},
    );
  }
}
