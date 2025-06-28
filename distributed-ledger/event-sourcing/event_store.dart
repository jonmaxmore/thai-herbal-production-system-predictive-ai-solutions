import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';
import 'package:crypto/crypto.dart';

class EventStore {
  final PostgreSQLConnection _db;
  final String _secretKey;

  EventStore(PostgreSQLConnection db, String secretKey)
      : _db = db,
        _secretKey = secretKey;

  factory EventStore.create(DotEnv env) {
    final db = PostgreSQLConnection(
      env['PG_HOST']!,
      int.parse(env['PG_PORT']!),
      env['PG_DATABASE']!,
      username: env['PG_USER']!,
      password: env['PG_PASSWORD']!,
    );
    return EventStore(db, env['EVENTSTORE_SECRET']!);
  }

  Future<void> init() async {
    await _db.open();
    await _createTables();
  }

  Future<void> _createTables() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id BIGSERIAL PRIMARY KEY,
        aggregate_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_data JSONB NOT NULL,
        event_hash TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    ''');
    
    await _db.execute('''
      CREATE INDEX idx_aggregate_id ON events (aggregate_id);
    ''');
    
    await _db.execute('''
      CREATE INDEX idx_event_type ON events (event_type);
    ''');
  }

  Future<void> appendEvent({
    required String aggregateId,
    required String eventType,
    required Map<String, dynamic> eventData,
  }) async {
    final jsonData = json.encode(eventData);
    final hash = _generateHash(jsonData);
    
    await _db.execute('''
      INSERT INTO events (aggregate_id, event_type, event_data, event_hash)
      VALUES (@aggregateId, @eventType, @eventData::jsonb, @hash)
    ''', substitutionValues: {
      'aggregateId': aggregateId,
      'eventType': eventType,
      'eventData': jsonData,
      'hash': hash,
    });
  }

  Future<List<Map<String, dynamic>>> getEvents(String aggregateId) async {
    final results = await _db.query('''
      SELECT event_type, event_data, created_at
      FROM events
      WHERE aggregate_id = @aggregateId
      ORDER BY created_at ASC
    ''', substitutionValues: {
      'aggregateId': aggregateId,
    });
    
    return results.map((row) {
      return {
        'type': row[0],
        'data': json.decode(row[1]),
        'timestamp': row[2].toIso8601String(),
      };
    }).toList();
  }

  Future<bool> verifyEventIntegrity(int eventId) async {
    final result = await _db.query('''
      SELECT event_data, event_hash
      FROM events
      WHERE id = @id
    ''', substitutionValues: {
      'id': eventId,
    });
    
    if (result.isEmpty) return false;
    
    final eventData = result[0][0].toString();
    final storedHash = result[0][1] as String;
    final calculatedHash = _generateHash(eventData);
    
    return storedHash == calculatedHash;
  }

  String _generateHash(String data) {
    final bytes = utf8.encode(data + _secretKey);
    return sha256.convert(bytes).toString();
  }

  Future<void> close() async {
    await _db.close();
  }
}
