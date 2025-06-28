import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';
import '../lib/fda_connector.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  group('FdaConnector', () {
    late FdaConnector connector;
    late MockClient mockClient;
    final env = DotEnv()..load();
    
    setUp(() {
      mockClient = MockClient();
      connector = FdaConnector(env);
    });
    
    test('getHerbalProductInfo success', () async {
      when(mockClient.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response(
          '{"product": {"id": "P123", "name": "Herbal Tea"}}', 
          200
        ));
      
      final result = await connector.getHerbalProductInfo('P123');
      expect(result['product']['id'], 'P123');
      expect(result['product']['name'], 'Herbal Tea');
    });
    
    test('submitProductRegistration success', () async {
      when(mockClient.post(any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')))
        .thenAnswer((_) async => http.Response('', 201));
      
      final success = await connector.submitProductRegistration({
        'name': 'New Herbal Product',
        'ingredients': ['Herb A', 'Herb B']
      });
      
      expect(success, true);
    });
  });
}
