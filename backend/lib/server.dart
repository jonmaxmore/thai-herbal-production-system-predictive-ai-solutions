import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/core/di/injector.dart' as di;
import 'package:backend/routes/main_router.dart';

void main() async {
  // เริ่มต้น Dependency Injection
  await di.init();
  
  final appRouter = MainRouter().router;
  
  final server = await io.serve(
    const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(appRouter),
    '0.0.0.0', 
    8080,
  );

  print('Server running on ${server.address.host}:${server.port}');
}
