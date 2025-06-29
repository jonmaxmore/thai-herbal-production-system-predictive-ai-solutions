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

  Future<Session> _getSession() async {
    return _driver.session();
  }

  Future<void> _executeWrite(String query, Map<String, dynamic> params) async {
    final session = await _getSession();
    try {
      await session.writeTransaction((tx) async {
        await tx.run(query, parameters: params);
      });
    } finally {
      await session.close();
    }
  }

  Future<List<Record>> _executeRead(String query, Map<String, dynamic> params) async {
    final session = await _getSession();
    try {
      return await session.readTransaction((tx) async {
        final result = await tx.run(query, parameters: params);
        return result.records;
      });
    } finally {
      await session.close();
    }
  }

  Future<void> createCertificationTrace(CertificationApplication app) async {
    await _executeWrite('''
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
      'status': app.status.toString(),
      'herbIds': app.herbIds,
    });
  }

  Future<void> addCertificationEvent({
    required String certificationId,
    required String eventType,
    required String description,
    required String actor,
  }) async {
    await _executeWrite('''
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
  }

  Future<List<Map<String, dynamic>>> getCertificationTimeline(String certificationId) async {
    final records = await _executeRead('''
      MATCH (cert:Certification {id: $certificationId})-[:HAS_EVENT]->(event:Event)
      RETURN event
      ORDER BY event.timestamp DESC
    ''', {'certificationId': certificationId});

    return records.map((record) {
      final event = record['event'];
      return {
        'timestamp': event['timestamp'],
        'type': event['type'],
        'description': event['description'],
        'actor': event['actor'],
      };
    }).toList();
  }

  Future<void> close() async {
    await _driver.close();
  }
}
