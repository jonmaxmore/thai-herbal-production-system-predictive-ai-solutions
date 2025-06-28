import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';
import 'package:jwt/jwt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class Server {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  late PostgreSQLConnection db;
  late RedisConnection redis;
  late Router router;

  Server() {
    _initDatabase();
    _initRedis();
    _initRoutes();
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
    print('Database connected');
  }

  Future<void> _initRedis() async {
    redis = RedisConnection();
    await redis.connect(env['REDIS_HOST']!, int.parse(env['REDIS_PORT']!));
    print('Redis connected');
  }

  void _initRoutes() {
    router = Router()
      ..get('/health', _healthHandler)
      ..post('/auth/login', _loginHandler)
      ..get('/herbs', _getHerbsHandler)
      ..post('/track', _trackHandler);
  }

  Future<Response> _healthHandler(Request request) async {
    return Response.ok(json.encode({'status': 'ok', 'time': DateTime.now().toIso8601String()}));
  }

  Future<Response> _loginHandler(Request request) async {
    final body = await request.readAsString();
    final data = json.decode(body);
    
    final result = await db.query(
      'SELECT id, password FROM users WHERE email = @email',
      substitutionValues: {'email': data['email']}
    );
    
    if (result.isEmpty) {
      return Response.unauthorized(json.encode({'error': 'Invalid credentials'}));
    }
    
    final user = result.first;
    final hashedPassword = sha256.convert(utf8.encode(data['password'])).toString();
    
    if (user[1] != hashedPassword) {
      return Response.unauthorized(json.encode({'error': 'Invalid credentials'}));
    }
    
    final token = JWT.encode({
      'id': user[0],
      'exp': DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch
    }, env['JWT_SECRET']!);
    
    return Response.ok(json.encode({'token': token}));
  }

  Future<Response> _getHerbsHandler(Request request) async {
    try {
      final herbs = await db.query('SELECT * FROM herbs');
      return Response.ok(json.encode(herbs.map((h) => {
        'id': h[0],
        'name': h[1],
        'scientific_name': h[2],
        'uses': h[3]
      }).toList()));
    } catch (e) {
      return Response.internalServerError(body: json.encode({'error': e.toString()}));
    }
  }

  Future<Response> _trackHandler(Request request) async {
    final body = await request.readAsString();
    final data = json.decode(body);
    
    await redis.sendCommand(['HSET', 'tracking:${data['batch_id']}', 
      'location', data['location'],
      'status', data['status'],
      'timestamp', DateTime.now().toIso8601String()
    ]);
    
    return Response.ok(json.encode({'status': 'tracking_updated'}));
  }

  Future<void> start({int port = 8080}) async {
    final server = await io.serve(router, '0.0.0.0', port);
    print('Server running on port ${server.port}');
  }
}
