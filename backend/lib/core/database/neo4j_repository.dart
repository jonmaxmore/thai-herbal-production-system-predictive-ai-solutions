import 'package:neo4j_dart/neo4j_dart.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/features/certification/domain/entities/certification_application.dart';

class Neo4jRepository {
  late final Driver _driver;

  Neo4jRepository(EnvConfig config) {
    _driver = Driver(
      Uri.parse(config.neo4jUri),
      AuthToken.basic(config.neo4jUsername, config.neo4jPassword),
    );
  }

  Future<void> createCertificationTrace(CertificationApplication app) async {
    final session = _driver.session();
    try {
      await session.writeTransaction((tx) async {
        await tx.run('''
          MERGE (farmer:Farmer {id: $farmerId, name: $farmerName})
          CREATE (cert:Certification {
            id: $certificationId,
            createdAt: datetime(),
            status: $status,
            standard: "GACP"
          })
          CREATE (farmer)-[:HAS_CERTIFICATION]->(cert)
          
          WITH cert
          UNWIND $herbIds AS herbId
          MERGE (herb:Herb {id: herbId})
          CREATE (cert)-[:CERTIFIES]->(herb)
        ''', {
          'farmerId': app.farmerId,
          'farmerName': app.farmerName,
          'certificationId': app.id,
          'status': app.status.name,
          'herbIds': app.herbIds,
        });
      });
    } finally {
      await session.close();
    }
  }

  Future<void> addCertificationEvent({
    required String certificationId,
    required String eventType,
    required String description,
    required String actor,
  }) async {
    final session = _driver.session();
    try {
      await session.writeTransaction((tx) async {
        await tx.run('''
          MATCH (cert:Certification {id: $certificationId})
          CREATE (event:Event {
            timestamp: datetime(),
            type: $eventType,
            description: $description,
            actor: $actor
          })
          CREATE (cert)-[:HAS_EVENT]->(event)
        ''', {
          'certificationId': certificationId,
          'eventType': eventType,
          'description': description,
          'actor': actor,
        });
      });
    } finally {
      await session.close();
    }
  }

  Future<List<Map<String, dynamic>>> getCertificationTimeline(String certificationId) async {
    final session = _driver.session();
    try {
      final result = await session.readTransaction((tx) async {
        return await tx.run('''
          MATCH (cert:Certification {id: $certificationId})-[:HAS_EVENT]->(event:Event)
          RETURN event
          ORDER BY event.timestamp DESC
        ''', {'certificationId': certificationId});
      });

      return result.records.map((record) {
        final event = record['event'];
        return {
          'timestamp': event['timestamp'],
          'type': event['type'],
          'description': event['description'],
          'actor': event['actor'],
        };
      }).toList();
    } finally {
      await session.close();
    }
  }

  Future<void> close() async => await _driver.close();
}
