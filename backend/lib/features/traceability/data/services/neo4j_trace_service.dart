import 'package:neo4j_dart/neo4j_dart.dart';
import 'package:backend/core/di/injector.dart';
import 'package:backend/features/traceability/domain/repositories/trace_repository.dart';

class Neo4jTraceService implements TraceRepository {
  final Driver _driver = injector.get<Driver>();

  @override
  Future<void> recordCertificationProcess({
    required String certificationId,
    required String farmerId,
    required List<String> herbIds,
  }) async {
    final session = _driver.session();
    try {
      await session.writeTransaction((tx) async {
        await tx.run('''
          MATCH (farmer:Farmer {id: $farmerId})
          CREATE (cert:Certification {
            id: $certificationId,
            createdAt: datetime(),
            status: "SUBMITTED"
          })
          CREATE (farmer)-[:HAS_CERTIFICATION]->(cert)
          
          WITH cert
          UNWIND $herbIds AS herbId
          MATCH (herb:Herb {id: herbId})
          CREATE (cert)-[:CERTIFIES]->(herb)
        ''', parameters: {
          'farmerId': farmerId,
          'certificationId': certificationId,
          'herbIds': herbIds,
        });
      });
    } finally {
      await session.close();
    }
  }
}
