import 'package:injectable/injectable.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:neo4j_dart/neo4j_dart.dart';

@module
abstract class RegisterModule {
  @singleton
  DotEnv env() => DotEnv()..load();
  
  @singleton
  EnvConfig envConfig(DotEnv env) => EnvConfig.fromEnv(env);
  
  @singleton
  Driver neo4jDriver(EnvConfig config) => Driver(
    Uri.parse(config.neo4jUri),
    AuthToken.basic(config.neo4jUsername, config.neo4jPassword),
  );
}
