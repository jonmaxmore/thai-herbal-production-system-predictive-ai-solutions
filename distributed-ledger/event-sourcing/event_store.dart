import 'package:postgres/postgres.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:thai_herbal_backend/core/config/app_config.dart';
import 'package:thai_herbal_backend/core/utils/logger.dart';

class EventStore {
  final PostgreSQLConnection _db;
  final String _secretKey;

  EventStore(PostgreSQLConnection db, String secretKey)
      : _db = db,
        _secretKey = secretKey;

  factory EventStore.create(AppConfig config) {
    final db = PostgreSQLConnection(
      config.dbHost,
      config.dbPort,
      config.dbName,
      username: config.dbUser,
      password: config.dbPassword,
    );
    return EventStore(db, config.eventStoreSecret);
  }

  Future<void> init() async {
    await _db.open();
    await _createTables();
  }

  Future<void> _createTables() async {
    try {
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS events (
          id BIGSERIAL PRIMARY KEY,
          aggregate_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          event_data JSONB NOT NULL,
          event_hash TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          signature TEXT
        );
      ''');
      
      await _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_events_aggregate_id ON events (aggregate_id);
      ''');
      
      await _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_events_created_at ON events (created_at);
      ''');
      
      Logger.info('Event store tables created');
    } catch (e) {
      Logger.error('Failed to create event store tables: $e');
      rethrow;
    }
  }

  Future<void> appendEvent({
    required String aggregateId,
    required String eventType,
    required Map<String, dynamic> eventData,
    String? signature,
  }) async {
    try {
      final jsonData = json.encode(eventData);
      final hash = _generateHash(jsonData);
      
      await _db.execute('''
        INSERT INTO events (
          aggregate_id, 
          event_type, 
          event_data, 
          event_hash,
          signature
        )
        VALUES (
          @aggregateId, 
          @eventType, 
          @eventData::jsonb, 
          @hash,
          @signature
        )
      ''', substitutionValues: {
        'aggregateId': aggregateId,
        'eventType': eventType,
        'eventData': jsonData,
        'hash': hash,
        'signature': signature,
      });
      
      Logger.info('Event appended: $eventType for $aggregateId');
    } catch (e) {
      Logger.error('Failed to append event: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEvents(
    String aggregateId, {
    DateTime? fromDate,
    int limit = 100,
  }) async {
    try {
      final result = await _db.query('''
        SELECT id, event_type, event_data, created_at, signature
        FROM events
        WHERE aggregate_id = @aggregateId
        ${fromDate != null ? 'AND created_at >= @fromDate' : ''}
        ORDER BY created_at ASC
        LIMIT @limit
      ''', substitutionValues: {
        'aggregateId': aggregateId,
        'fromDate': fromDate,
        'limit': limit,
      });
      
      return result.map((row) {
        return {
          'id': row[0],
          'type': row[1],
          'data': json.decode(row[2]),
          'timestamp': row[3],
          'signature': row[4],
        };
      }).toList();
    } catch (e) {
      Logger.error('Failed to get events: $e');
      rethrow;
    }
  }

  Future<bool> verifyEventIntegrity(int eventId) async {
    try {
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
    } catch (e) {
      Logger.error('Failed to verify event integrity: $e');
      return false;
    }
  }

  String _generateHash(String data) {
    final bytes = utf8.encode(data + _secretKey);
    return sha256.convert(bytes).toString();
  }

  Future<void> close() async {
    await _db.close();
  }
}
