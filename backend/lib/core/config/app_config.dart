import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:path/path.dart' as path;

class AppConfig {
  final int port;
  final String mongodbUri;
  final String dbName;
  final String jwtSecret;
  final String jwtIssuer;
  final String jwtAudience;
  final int jwtExpiry;
  final String aiModelPath;
  final String storagePath;
  final String mailerUser;
  final String mailerPass;
  final bool enableVideoProcessing;

  AppConfig({
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
  });

  factory AppConfig.fromEnv(DotEnv env) {
    return AppConfig(
      port: int.tryParse(env['PORT'] ?? '8080') ?? 8080,
      mongodbUri: env['MONGODB_URI'] ?? 'mongodb://localhost:27017',
      dbName: env['DB_NAME'] ?? 'thai_herbal_db',
      jwtSecret: env['JWT_SECRET'] ?? 'default_herbal_secret',
      jwtIssuer: env['JWT_ISSUER'] ?? 'thai-herbal-api',
      jwtAudience: env['JWT_AUDIENCE'] ?? 'herbal-client',
      jwtExpiry: int.tryParse(env['JWT_EXPIRY'] ?? '3600') ?? 3600,
      aiModelPath: env['AI_MODEL_PATH'] ?? 'assets/models',
      storagePath: env['STORAGE_PATH'] ?? 'storage',
      mailerUser: env['MAILER_USER'] ?? '',
      mailerPass: env['MAILER_PASS'] ?? '',
      enableVideoProcessing: env['ENABLE_VIDEO_PROCESSING'] == 'true',
    );
  }

  factory AppConfig.fromFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Config file not found: $filePath');
    }

    final env = DotEnv()..load([filePath]);
    return AppConfig.fromEnv(env);
  }

  @override
  String toString() {
    return '''
AppConfig {
  port: $port,
  mongodbUri: $mongodbUri,
  dbName: $dbName,
  jwtSecret: ${jwtSecret.isEmpty ? '<empty>' : '*****'},
  jwtIssuer: $jwtIssuer,
  jwtAudience: $jwtAudience,
  jwtExpiry: $jwtExpiry seconds,
  aiModelPath: $aiModelPath,
  storagePath: $storagePath,
  mailerUser: $mailerUser,
  mailerPass: ${mailerPass.isEmpty ? '<empty>' : '*****'},
  enableVideoProcessing: $enableVideoProcessing
}
''';
  }
}

class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  late AppConfig _config;
  bool _initialized = false;

  factory ConfigManager() {
    return _instance;
  }

  ConfigManager._internal();

  void initialize({String? envFilePath}) {
    if (_initialized) return;

    final env = DotEnv()..load(envFilePath != null ? [envFilePath] : []);

    // Load environment variables with fallbacks
    _config = AppConfig.fromEnv(env);

    // Create required directories
    _createRequiredDirectories();

    _initialized = true;
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

  AppConfig get config {
    if (!_initialized) {
      throw Exception('ConfigManager not initialized. Call initialize() first.');
    }
    return _config;
  }

  void printConfig() {
    print('Loaded configuration:');
    print(_config.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'port': config.port,
      'mongodbUri': config.mongodbUri,
      'dbName': config.dbName,
      'jwtIssuer': config.jwtIssuer,
      'jwtAudience': config.jwtAudience,
      'jwtExpiry': config.jwtExpiry,
      'aiModelPath': config.aiModelPath,
      'storagePath': config.storagePath,
      'mailerUser': config.mailerUser,
      'enableVideoProcessing': config.enableVideoProcessing,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
}
