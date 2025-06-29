import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:meta/meta.dart';
import 'package:backend/core/errors/exceptions.dart';

class EnvConfig {
  // Server configuration
  final int port;
  final String environment;
  final bool isProduction;

  // Database configurations
  final String mongodbUri;
  final String postgresHost;
  final int postgresPort;
  final String postgresDatabase;
  final String postgresUsername;
  final String postgresPassword;
  final bool postgresUseSsl;
  final int postgresTimeout;
  final String neo4jUri;
  final String neo4jUsername;
  final String neo4jPassword;
  final String redisHost;
  final int redisPort;
  final int redisCacheTtl;

  // Application-specific
  final String jwtSecret;
  final String storagePath;
  final String aiModelPath;
  final String gacpCertificationPath;
  final String traceabilityApiKey;

  EnvConfig._({
    required this.port,
    required this.environment,
    required this.isProduction,
    required this.mongodbUri,
    required this.postgresHost,
    required this.postgresPort,
    required this.postgresDatabase,
    required this.postgresUsername,
    required this.postgresPassword,
    required this.postgresUseSsl,
    required this.postgresTimeout,
    required this.neo4jUri,
    required this.neo4jUsername,
    required this.neo4jPassword,
    required this.redisHost,
    required this.redisPort,
    required this.redisCacheTtl,
    required this.jwtSecret,
    required this.storagePath,
    required this.aiModelPath,
    required this.gacpCertificationPath,
    required this.traceabilityApiKey,
  });

  factory EnvConfig.fromEnv(DotEnv env) {
    final environment = env['ENVIRONMENT'] ?? 'development';
    final isProduction = environment == 'production';

    return EnvConfig._(
      port: _parseInt(env['PORT'], 8080),
      environment: environment,
      isProduction: isProduction,
      mongodbUri: env['MONGODB_URI'] ?? 'mongodb://localhost:27017',
      postgresHost: env['POSTGRES_HOST'] ?? 'localhost',
      postgresPort: _parseInt(env['POSTGRES_PORT'], 5432),
      postgresDatabase: env['POSTGRES_DB'] ?? 'thai_herbal',
      postgresUsername: env['POSTGRES_USER'] ?? 'postgres',
      postgresPassword: env['POSTGRES_PASSWORD'] ?? 'postgres',
      postgresUseSsl: env['POSTGRES_USE_SSL'] == 'true',
      postgresTimeout: _parseInt(env['POSTGRES_TIMEOUT'], 30),
      neo4jUri: env['NEO4J_URI'] ?? 'neo4j://localhost:7687',
      neo4jUsername: env['NEO4J_USER'] ?? 'neo4j',
      neo4jPassword: env['NEO4J_PASSWORD'] ?? 'password',
      redisHost: env['REDIS_HOST'] ?? 'localhost',
      redisPort: _parseInt(env['REDIS_PORT'], 6379),
      redisCacheTtl: _parseInt(env['REDIS_CACHE_TTL'], 3600),
      jwtSecret: env['JWT_SECRET'] ?? 'default_secret_key',
      storagePath: env['STORAGE_PATH'] ?? 'storage',
      aiModelPath: env['AI_MODEL_PATH'] ?? 'ai_models',
      gacpCertificationPath: env['GACP_CERT_PATH'] ?? 'certifications',
      traceabilityApiKey: env['TRACEABILITY_API_KEY'] ?? '',
    );
  }

  static int _parseInt(String? value, int defaultValue) {
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  void validate() {
    final errors = <String>[];
    
    if (jwtSecret.isEmpty || jwtSecret == 'default_secret_key') {
      errors.add('JWT_SECRET must be set and secure');
    }
    
    if (traceabilityApiKey.isEmpty) {
      errors.add('TRACEABILITY_API_KEY is required');
    }
    
    if (isProduction) {
      if (postgresPassword.isEmpty || postgresPassword == 'postgres') {
        errors.add('POSTGRES_PASSWORD must be secure in production');
      }
      
      if (neo4jPassword.isEmpty || neo4jPassword == 'password') {
        errors.add('NEO4J_PASSWORD must be secure in production');
      }
    }
    
    if (errors.isNotEmpty) {
      throw ConfigValidationException(
        'Environment configuration validation failed',
        errors: errors,
      );
    }
  }

  @override
  String toString() {
    return '''
EnvConfig {
  environment: $environment,
  port: $port,
  isProduction: $isProduction,
  
  // Databases
  postgresHost: $postgresHost,
  postgresPort: $postgresPort,
  neo4jUri: $neo4jUri,
  redisHost: $redisHost,
  
  // Security
  jwtSecret: ${jwtSecret.isEmpty ? '<empty>' : '*****'},
  traceabilityApiKey: ${traceabilityApiKey.isEmpty ? '<empty>' : '*****'},
  
  // Paths
  storagePath: $storagePath,
  aiModelPath: $aiModelPath,
  gacpCertificationPath: $gacpCertificationPath
}
''';
  }
}
