import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'config.dart';

class EnvLoader {
  static const String _defaultEnvFile = '.env';
  static const String _productionEnvFile = '.env.production';
  static const String _developmentEnvFile = '.env.development';

  static Future<AppConfig> loadConfig({String? environment}) async {
    final env = DotEnv();
    String envFile = _defaultEnvFile;

    // Determine environment file based on current environment
    if (environment != null) {
      envFile = environment == 'production' 
          ? _productionEnvFile 
          : _developmentEnvFile;
    }

    // Check if environment file exists
    if (!await File(envFile).exists()) {
      print('⚠️ Environment file not found: $envFile');
      print('⏳ Loading default configuration...');
      return AppConfig.fromEnv(env);
    }

    // Load environment file
    env.load([envFile]);
    print('✅ Loaded environment from: $envFile');
    return AppConfig.fromEnv(env);
  }

  static String getEnvironment() {
    const String env = String.fromEnvironment('ENV', defaultValue: 'development');
    return env;
  }

  static bool isProduction() {
    return getEnvironment() == 'production';
  }
}
