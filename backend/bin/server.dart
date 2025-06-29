import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/core/di/injector.dart';
import 'package:backend/core/config/env_config.dart';
import 'package:backend/core/utils/logger.dart';

void main() async {
  // Initialize dependencies
  await initializeDependencies();
  
  final envConfig = injector<EnvConfig>();
  final logger = injector<Logger>();
  
  logger.info('Starting Thai Herbal Platform Server');
  logger.info('Environment: ${envConfig.environment}');
  logger.info('Port: ${envConfig.port}');
  
  // Create router
  final router = Router();
  
  // Health check endpoint
  router.get('/health', (Request request) async {
    final healthService = HealthService();
    final status = await healthService.check();
    return Response.ok(jsonEncode(status));
  });
  
  // Start server
  final server = await io.serve(
    const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router),
    InternetAddress.anyIPv4,
    envConfig.port,
  );
  
  logger.info('Server running on ${server.address.host}:${server.port}');
  
  // Handle shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    logger.info('SIGINT received, shutting down');
    await server.close();
    exit(0);
  });
}
