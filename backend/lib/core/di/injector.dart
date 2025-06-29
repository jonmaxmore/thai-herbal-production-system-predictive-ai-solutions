import 'package:get_it/get_it.dart';
import 'package:dotenv/dotenv.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/core/database/postgres_repository.dart';
import 'package:backend/core/database/neo4j_repository.dart';
import 'package:backend/core/database/redis_client.dart';
import 'package:backend/core/utils/logger.dart';

final GetIt injector = GetIt.instance;

Future<void> initializeDependencies() async {
  // Load environment variables
  final env = DotEnv(includePlatformEnvironment: true)..load();
  
  // Register env config
  final envConfig = EnvConfig.fromEnv(env);
  envConfig.validate();
  injector.registerSingleton<EnvConfig>(envConfig);
  
  // Logger
  injector.registerSingleton<Logger>(ProductionLogger());
  
  // Databases
  injector.registerLazySingleton<PostgresRepository>(() {
    final repo = PostgresRepository(injector<EnvConfig>());
    repo.connect();
    return repo;
  });
  
  injector.registerLazySingleton<Neo4jRepository>(() {
    final repo = Neo4jRepository(
      injector<EnvConfig>(),
      injector<Logger>(),
    );
    repo.initialize();
    return repo;
  });
  
  injector.registerLazySingleton<RedisClient>(() {
    final client = RedisClient(
      injector<EnvConfig>(),
      injector<Logger>(),
    );
    client.connect();
    return client;
  });
  
  // Shutdown hook
  _registerShutdownHook();
}

void _registerShutdownHook() {
  ProcessSignal.sigint.watch().listen((_) async {
    await _shutdown();
    exit(0);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    await _shutdown();
    exit(0);
  });
}

Future<void> _shutdown() async {
  final logger = injector<Logger>();
  logger.info('Shutting down application...');
  
  try {
    await injector<PostgresRepository>().disconnect();
    await injector<Neo4jRepository>().close();
    await injector<RedisClient>().disconnect();
    logger.info('Resources released successfully');
  } catch (e) {
    logger.error('Error during shutdown', error: e);
  }
}
