import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_test/shelf_test.dart';
import 'package:thai_herbal_server/server.dart';
import 'package:dotenv/dotenv.dart';

void main() {
  late Server server;
  late Pipeline pipeline;

  setUpAll(() async {
    final env = DotEnv(includePlatformEnvironment: true)..load();
    env['DB_HOST'] = 'localhost';
    env['DB_PORT'] = '5432';
    env['POSTGRES_DB'] = 'test_db';
    env['POSTGRES_USER'] = 'test_user';
    env['POSTGRES_PASSWORD'] = 'test_pass';
    env['JWT_SECRET'] = 'test_secret';
    
    server = Server();
    await server._initDatabase();
    await server._initRedis();
    
    // Setup test data
    await server.db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL
      )
    ''');
    
    await server.db.execute('''
      INSERT INTO users (email, password) 
      VALUES ('test@example.com', '${sha256.convert(utf8.encode('password123')).toString()}')
    ''');
    
    pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(server.router);
  });

  tearDownAll(() async {
    await server.db.close();
    await server.redis.close();
  });

  test('GET /health returns 200', () async {
    expect(
      await makeRequest(pipeline, 'GET', '/health'),
      isResponse(
        statusCode: 200,
        body: contains('"status":"ok"'),
      ),
    );
  });

  test('POST /auth/login with valid credentials returns token', () async {
    expect(
      await makeRequest(
        pipeline,
        'POST',
        '/auth/login',
        body: json.encode({
          'email': 'test@example.com',
          'password': 'password123'
        }),
        headers: {'Content-Type': 'application/json'},
      ),
      isResponse(
        statusCode: 200,
        body: contains('"token":'),
      ),
    );
  });

  test('POST /auth/login with invalid credentials returns 401', () async {
    expect(
      await makeRequest(
        pipeline,
        'POST',
        '/auth/login',
        body: json.encode({
          'email': 'wrong@example.com',
          'password': 'wrong'
        }),
        headers: {'Content-Type': 'application/json'},
      ),
      isResponse(statusCode: 401),
    );
  });
}
