import 'package:shelf_router/shelf_router.dart';
import 'package:backend/features/certification/presentation/controllers/certification_controller.dart';
import 'package:backend/features/user/presentation/controllers/user_controller.dart';

class MainRouter {
  final Router router = Router();
  
  MainRouter() {
    // Certification routes
    final certController = CertificationController();
    router.mount('/api/certifications/', certController.router);
    
    // User routes
    final userController = UserController();
    router.mount('/api/users/', userController.router);
    
    // Health check
    router.get('/health', (Request request) {
      return Response.ok('Thai Herbal API is running');
    });
  }
}
