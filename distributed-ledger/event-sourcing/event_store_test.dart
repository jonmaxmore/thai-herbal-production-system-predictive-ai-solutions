import 'package:test/test.dart';
import 'package:dotenv/dotenv.dart';
import 'event_store.dart';

void main() {
  late EventStore eventStore;
  final testAggregateId = 'test_aggregate_123';

  setUpAll(() async {
    final env = DotEnv(includePlatformEnvironment: true)..load();
    env['DB_HOST'] = 'localhost';
    env['DB_PORT'] = '5432';
    env['POSTGRES_DB'] = 'test_db';
    env['POSTGRES_USER'] = 'test_user';
    env['POSTGRES_PASSWORD'] = 'test_pass';
    
    eventStore = EventStore(env);
    await eventStore._initDatabase();
  });

  tearDownAll(() async {
    await eventStore.close();
  });

  test('Append and retrieve events', () async {
    // Clear any previous events
    await eventStore.db.execute('DELETE FROM events WHERE aggregate_id = @id', 
      substitutionValues: {'id': testAggregateId});
    
    // Add events
    await eventStore.append(testAggregateId, 'HerbPlanted', {
      'herb_id': 'herb_001',
      'location': 'Farm A',
      'planted_at': DateTime.now().toIso8601String()
    });
    
    await eventStore.append(testAggregateId, 'HerbHarvested', {
      'harvested_at': DateTime.now().toIso8601String(),
      'weight': 5.2
    });
    
    // Retrieve events
    final events = await eventStore.getEvents(testAggregateId);
    
    expect(events.length, 2);
    expect(events[0]['type'], 'HerbPlanted');
    expect(events[1]['type'], 'HerbHarvested');
    expect(events[0]['data']['herb_id'], 'herb_001');
  });
}
