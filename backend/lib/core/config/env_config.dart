import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:path/path.dart' as path;
import 'package:meta/meta.dart';
import 'package:backend/core/errors/exceptions.dart';

class EnvConfig {
  final int port;
  final String mongodbUri;
  final String dbName;
  final String jwtSecret;
  final String jwtIssuer;
  final String jwtAudience;
  final Duration jwtExpiry;
  final String aiModelPath;
  final String storagePath;
  final String mailerUser;
  final String mailerPass;
  final bool enableVideoProcessing;
  final bool isProduction;
  final String environment;
  final String neo4jUri;
  final String neo4jUsername;
  final String neo4jPassword;
  final String neo4jDatabase;
  final int neo4jPoolSize;
  final int neo4jTimeout;
  final bool neo4jEncrypted;

  EnvConfig._({
    required this.port,
    required this.mongodbUri,
    required this.dbName,
    required this.jwtSecret,
    required this.jwtIssuer,
    required this.jwtAudience,
    required this.jwtExpiry,
    required this.aiModelPath,
    required this.storagePath,
    required this.mailerUser,
    required this.mailerPass,
    required this.enableVideoProcessing,
    required this.isProduction,
    required this.environment,
  });

  factory EnvConfig.fromEnv(DotEnv env) {
    final environment = _determineEnvironment(env);
    final isProduction = environment == 'production';

    return EnvConfig._(
      port: int.tryParse(env['PORT'] ?? '8080') ?? 8080,
      mongodbUri: env['MONGODB_URI'] ?? 'mongodb://localhost:27017',
      dbName: env['DB_NAME'] ?? 'thai_herbal_db',
      jwtSecret: env['JWT_SECRET'] ?? 'default_herbal_secret',
      jwtIssuer: env['JWT_ISSUER'] ?? 'thai-herbal-api',
      jwtAudience: env['JWT_AUDIENCE'] ?? 'herbal-client',
      jwtExpiry: Duration(
        seconds: int.tryParse(env['JWT_EXPIRY'] ?? '3600') ?? 3600,
      ),
      aiModelPath: env['AI_MODEL_PATH'] ?? 'assets/models',
      storagePath: env['STORAGE_PATH'] ?? 'storage',
      mailerUser: env['MAILER_USER'] ?? '',
      mailerPass: env['MAILER_PASS'] ?? '',
      enableVideoProcessing: env['ENABLE_VIDEO_PROCESSING'] == 'true',
      isProduction: isProduction,
      environment: environment,
    );
  }

  static String _determineEnvironment(DotEnv env) {
    return env['ENVIRONMENT'] ??
        const String.fromEnvironment('ENV', defaultValue: 'development');
  }

  @override
  String toString() {
    return '''
EnvConfig {
  environment: $environment,
  port: $port,
  mongodbUri: $mongodbUri,
  dbName: $dbName,
  jwtSecret: ${jwtSecret.isEmpty ? '<empty>' : '*****'},
  jwtIssuer: $jwtIssuer,
  jwtAudience: $jwtAudience,
  jwtExpiry: ${jwtExpiry.inSeconds} seconds,
  aiModelPath: $aiModelPath,
  storagePath: $storagePath,
  mailerUser: $mailerUser,
  mailerPass: ${mailerPass.isEmpty ? '<empty>' : '*****'},
  enableVideoProcessing: $enableVideoProcessing,
  isProduction: $isProduction
}
''';
  }
}

class EnvConfigManager {
  static final EnvConfigManager _instance = EnvConfigManager._internal();
  late EnvConfig _config;
  bool _initialized = false;

  factory EnvConfigManager() {
    return _instance;
  }

  EnvConfigManager._internal();

  @visibleForTesting
  static void reset() {
    _instance._initialized = false;
  }

  void initialize({String? envFilePath}) {
    if (_initialized) return;

    final env = DotEnv()..load(envFilePath != null ? [envFilePath] : []);
    _config = EnvConfig.fromEnv(env);
    _validateConfig();
    _createRequiredDirectories();

    _initialized = true;
  }

  void _validateConfig() {
    final errors = <String>[];

    if (_config.jwtSecret.isEmpty || _config.jwtSecret == 'default_herbal_secret') {
      errors.add('JWT_SECRET must be set and secure');
    }
    
    if (_config.mongodbUri.isEmpty || !_config.mongodbUri.startsWith('mongodb://')) {
      errors.add('MONGODB_URI must be a valid MongoDB connection string');
    }
    
    if (_config.dbName.isEmpty) {
      errors.add('DB_NAME must be set');
    }
    
    if (_config.aiModelPath.isEmpty) {
      errors.add('AI_MODEL_PATH must be set');
    } else {
      final dir = Directory(_config.aiModelPath);
      if (!dir.existsSync()) {
        errors.add('AI_MODEL_PATH directory does not exist: ${_config.aiModelPath}');
      }
    }
    
    if (_config.storagePath.isEmpty) {
      errors.add('STORAGE_PATH must be set');
    }

    if (errors.isNotEmpty) {
      throw ConfigValidationException(
        'Configuration validation failed',
        errors: errors,
      );
    }
  }

  void _createRequiredDirectories() {
    final dirsToCreate = [
      _config.storagePath,
      path.join(_config.storagePath, 'uploads'),
      path.join(_config.storagePath, 'certificates'),
      _config.aiModelPath,
    ];

    for (final dir in dirsToCreate) {
      final directory = Directory(dir);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
        print('Created directory: $dir');
      }
    }
  }

  EnvConfig get config {
    if (!_initialized) {
      throw ConfigNotInitializedException(
        'EnvConfigManager not initialized. Call initialize() first.'
      );
    }
    return _config;
  }

  void printConfig() {
    print('Loaded environment configuration:');
    print(_config.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'environment': config.environment,
      'port': config.port,
      'mongodbUri': config.mongodbUri,
      'dbName': config.dbName,
      'jwtIssuer': config.jwtIssuer,
      'jwtAudience': config.jwtAudience,
      'jwtExpiry': config.jwtExpiry.inSeconds,
      'aiModelPath': config.aiModelPath,
      'storagePath': config.storagePath,
      'mailerUser': config.mailerUser,
      'enableVideoProcessing': config.enableVideoProcessing,
      'isProduction': config.isProduction,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
}

class ConfigNotInitializedException implements Exception {
  final String message;
  ConfigNotInitializedException(this.message);
  
  @override
  String toString() => 'ConfigNotInitializedException: $message';
}

class ConfigValidationException implements Exception {
  final String message;
  final List<String> errors;
  
  ConfigValidationException(this.message, {required this.errors});
  
  @override
  String toString() => 'ConfigValidationException: $message\nErrors:\n${errors.join('\n')}';
}
  
    // Neo4j parameters
    required this.neo4jUri,
    required this.neo4jUsername,
    required this.neo4jPassword,
    this.neo4jDatabase = 'neo4j',
    this.neo4jPoolSize = 10,
    this.neo4jTimeout = 30,
    this.neo4jEncrypted = true,
  });

  factory EnvConfig.fromEnv(DotEnv env) {
    return EnvConfig._(
      // ... existing assignments ...

      // Neo4j assignments
      neo4jUri: env['NEO4J_URI'] ?? 'neo4j://localhost:7687',
      neo4jUsername: env['NEO4J_USER'] ?? 'neo4j',
      neo4jPassword: env['NEO4J_PASSWORD'] ?? 'password',
      neo4jDatabase: env['NEO4J_DATABASE'] ?? 'neo4j',
      neo4jPoolSize: int.tryParse(env['NEO4J_POOL_SIZE'] ?? '10') ?? 10,
      neo4jTimeout: int.tryParse(env['NEO4J_TIMEOUT'] ?? '30') ?? 30,
      neo4jEncrypted: env['NEO4J_ENCRYPTED'] != 'false',
    );
  }
}
