import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

class EventStore {
  final DotEnv env;
  late PostgreSQLConnection db;

  EventStore(this.env) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    db = PostgreSQLConnection(
      env['DB_HOST']!,
      int.parse(env['DB_PORT']!),
      env['POSTGRES_DB']!,
      username: env['POSTGRES_USER']!,
      password: env['POSTGRES_PASSWORD']!,
    );
    await db.open();
    await _createTables();
  }

  Future<void> _createTables() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id SERIAL PRIMARY KEY,
        aggregate_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_data JSONB NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_aggregate_id ON events (aggregate_id)
    ''');
  }

  Future<void> append(String aggregateId, String eventType, Map<String, dynamic> eventData) async {
    await db.execute('''
      INSERT INTO events (aggregate_id, event_type, event_data)
      VALUES (@aggregateId, @eventType, @eventData)
    ''', substitutionValues: {
      'aggregateId': aggregateId,
      'eventType': eventType,
      'eventData': json.encode(eventData),
    });
  }

  Future<List<Map<String, dynamic>>> getEvents(String aggregateId) async {
    final result = await db.query('''
      SELECT event_type, event_data, timestamp 
      FROM events 
      WHERE aggregate_id = @aggregateId
      ORDER BY timestamp ASC
    ''', substitutionValues: {'aggregateId': aggregateId});
    
    return result.map((row) {
      return {
        'type': row[0],
        'data': json.decode(row[1]),
        'timestamp': row[2].toIso8601String(),
      };
    }).toList();
  }

  Future<void> close() async {
    await db.close();
  }
}
