import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class UserController {
  Router get router {
    final router = Router();

    // Farmer registration
    router.post('/farmers/register', (Request request) {
      return Response.ok('Farmer registered');
    });

    // DPM Officer login
    router.post('/dpm/login', (Request request) {
      return Response.ok('DPM Officer logged in');
    });

    return router;
  }
}
