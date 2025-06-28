import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';
import 'package:jwt/jwt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:redis/redis.dart';
import 'package:neo4j_dart/neo4j_dart.dart';

class Server {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  late PostgreSQLConnection pgPool;
  late Commandable redis;
  late GraphDatabase neo4j;
  late Router router;

  Server() {
    _initServices();
  }

  Future<void> _initServices() async {
    await _initPostgreSQL();
    await _initRedis();
    await _initNeo4j();
    _initRoutes();
  }

  Future<void> _initPostgreSQL() async {
    pgPool = PostgreSQLConnection(
      env['PG_HOST'] ?? 'localhost',
      int.tryParse(env['PG_PORT'] ?? '5432') ?? 5432,
      env['PG_DATABASE'] ?? 'gacp',
      username: env['PG_USER'] ?? 'postgres',
      password: env['PG_PASSWORD'] ?? 'postgres',
    );
    await pgPool.open();
    print('✅ PostgreSQL connected');
  }

  Future<void> _initRedis() async {
    final conn = await RedisConnection().connect(
      env['REDIS_HOST'] ?? 'localhost',
      int.tryParse(env['REDIS_PORT'] ?? '6379') ?? 6379,
    );
    redis = conn;
    print('✅ Redis connected');
  }

  Future<void> _initNeo4j() async {
    neo4j = GraphDatabase(
      Uri.parse(env['NEO4J_URI'] ?? 'bolt://localhost:7687'),
      auth: AuthToken.custom(
        principal: env['NEO4J_USER'] ?? 'neo4j',
        credentials: env['NEO4J_PASSWORD'] ?? 'password',
        realm: '',
        scheme: 'basic',
      ),
    );
    await neo4j.verifyConnectivity();
    print('✅ Neo4j connected');
  }

  void _initRoutes() {
    router = Router()
      ..get('/health', _healthHandler)
      ..get('/api/herbs', _getHerbsHandler)
      ..post('/api/auth/login', _loginHandler)
      ..get('/api/track/<batchId>', _trackHandler)
      ..post('/api/quality/assess', _qualityHandler);
  }

  // Health Check Endpoint
  Future<Response> _healthHandler(Request request) async {
    try {
      // Check PostgreSQL
      final pgResult = await pgPool.query('SELECT 1');
      
      // Check Redis
      await redis.send_object(['PING']);
      
      // Check Neo4j
      await neo4j.execute('RETURN 1');
      
      return Response.ok(json.encode({
        'status': 'ok',
        'services': {
          'postgresql': pgResult.isNotEmpty,
          'redis': true,
          'neo4j': true
        }
      }));
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Service unavailable', 'details': e.toString()})
      );
    }
  }

  // Herbs Data Endpoint
  Future<Response> _getHerbsHandler(Request request) async {
    try {
      final results = await pgPool.query('''
        SELECT id, name_th, name_sci, properties, cultivation 
        FROM herbs
        ORDER BY name_th
      ''');
      
      final herbs = results.map((row) {
        return {
          'id': row[0],
          'name_th': row[1],
          'name_sci': row[2],
          'properties': row[3],
          'cultivation': row[4],
        };
      }).toList();
      
      return Response.ok(json.encode(herbs));
    } catch (e) {
      return _handleError(e, 'Failed to fetch herbs');
    }
  }

  // Authentication Endpoint
  Future<Response> _loginHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;
      
      final email = data['email']?.toString();
      final password = data['password']?.toString();
      
      if (email == null || password == null) {
        return Response.badRequest(
          body: json.encode({'error': 'Email and password are required'})
        );
      }
      
      final results = await pgPool.query(
        'SELECT id, password_hash, role FROM users WHERE email = @email',
        substitutionValues: {'email': email}
      );
      
      if (results.isEmpty) {
        return Response.unauthorized(
          json.encode({'error': 'Invalid credentials'})
        );
      }
      
      final user = results.first;
      final storedHash = user[1] as String;
      final inputHash = sha256.convert(utf8.encode(password)).toString();
      
      if (storedHash != inputHash) {
        return Response.unauthorized(
          json.encode({'error': 'Invalid credentials'})
        );
      }
      
      final toke
