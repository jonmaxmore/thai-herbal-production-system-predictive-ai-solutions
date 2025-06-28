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
      
      final token = _generateJWT(user[0] as int, user[2] as String);
      
      return Response.ok(json.encode({
        'token': token,
        'user_id': user[0],
        'role': user[2]
      }));
    } catch (e) {
      return _handleError(e, 'Login failed');
    }
  }

  // Track & Trace Endpoint
  Future<Response> _trackHandler(Request request, String batchId) async {
    try {
      final trackingData = await redis.send_object(['HGETALL', 'tracking:$batchId']);
      
      if (trackingData is! List || trackingData.isEmpty) {
        return Response.notFound(
          json.encode({'error': 'Batch not found'})
        );
      }
      
      // Convert Redis response to Map
      final Map<String, dynamic> data = {};
      for (int i = 0; i < trackingData.length; i += 2) {
        data[trackingData[i].toString()] = trackingData[i+1].toString();
      }
      
      return Response.ok(json.encode(data));
    } catch (e) {
      return _handleError(e, 'Tracking failed');
    }
  }

  // Quality Assessment Endpoint
  Future<Response> _qualityHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;
      
      final imageData = data['image'] as String?;
      if (imageData == null || !imageData.startsWith('data:image')) {
        return Response.badRequest(
          body: json.encode({'error': 'Invalid image data'})
        );
      }
      
      // Call AI Service
      final aiResponse = await _callAIService(imageData);
      
      // Store in knowledge graph
      await _storeInKnowledgeGraph(aiResponse);
      
      return Response.ok(json.encode(aiResponse));
    } catch (e) {
      return _handleError(e, 'Quality assessment failed');
    }
  }

  Future<Map<String, dynamic>> _callAIService(String imageData) async {
    // In production, call actual AI service
    return {
      'status': 'success',
      'quality_score': 0.92,
      'defects': [
        {'type': 'discoloration', 'confidence': 0.87, 'location': 'top-right'},
        {'type': 'size_variation', 'confidence': 0.78, 'location': 'center'}
      ],
      'herb_type': 'ฟ้าทะลายโจร',
      'recommendations': ['ปรับปรุงการตากแห้ง', 'ลดความชื้นในการเก็บรักษา']
    };
  }

  Future<void> _storeInKnowledgeGraph(Map<String, dynamic> data) async {
    await neo4j.execute('''
      CREATE (q:QualityAssessment {
        herbType: $herbType,
        qualityScore: $qualityScore,
        timestamp: datetime(),
        defects: $defects
      })
    ''', {
      'herbType': data['herb_type'],
      'qualityScore': data['quality_score'],
      'defects': data['defects']
    });
  }

  String _generateJWT(int userId, String role) {
    final claims = JwtClaims({
      'sub': userId.toString(),
      'role': role,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': (DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch ~/ 1000
    }, issuer: 'thai-herbal-api');
    
    return JWT.encode(claims, env['JWT_SECRET']!, algorithm: JWTAlgorithm.HS256);
  }

  Response _handleError(dynamic error, String message) {
    print('⚠️ ERROR: $message - ${error.toString()}');
    return Response.internalServerError(
      body: json.encode({
        'error': message,
        'details': error.toString()
      })
    );
  }

  Future<void> start({int port = 8080}) async {
    final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router);
    
    final server = await io.serve(handler, '0.0.0.0', port);
    print('🚀 Server running on port ${server.port}');
  }
}
