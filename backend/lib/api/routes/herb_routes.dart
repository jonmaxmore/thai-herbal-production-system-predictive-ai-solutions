import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_middleware_validate/shelf_middleware_validate.dart';
import 'package:thai_herbal_backend/core/security/jwt_service.dart';
import 'package:thai_herbal_backend/api/middleware/auth_middleware.dart';
import 'package:thai_herbal_backend/api/validators/herb_validators.dart';
import 'package:thai_herbal_backend/services/herb_service.dart';
import 'package:thai_herbal_backend/core/utils/response_utils.dart';

class HerbRoutes {
  final HerbService herbService;
  final JwtService jwtService;

  HerbRoutes(this.herbService, this.jwtService);

  Router get router {
    final app = Router();

    // Apply JWT authentication middleware to all routes
    final authMiddleware = AuthMiddleware(jwtService);

    // Get all herbs
    app.get(
      '/',
      (Request request) async {
        try {
          final herbs = await herbService.getAllHerbs();
          return ResponseUtils.successResponse(herbs);
        } catch (e) {
          return ResponseUtils.errorResponse(e);
        }
      },
    );

    // Create new herb
    app.post(
      '/',
      (Request request) async {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body) as Map<String, dynamic>;
          
          final herb = await herbService.createHerb(data);
          return ResponseUtils.createdResponse(herb);
        } catch (e) {
          return ResponseUtils.errorResponse(e);
        }
      },
      middleware: [
        validate(HerbValidators.createHerbSchema),
        authMiddleware.requireRole('admin')
      ],
    );

    // Herb details
    app.get(
      '/<id>',
      (Request request, String id) async {
        try {
          final herb = await herbService.getHerbById(id);
          return herb != null
              ? ResponseUtils.successResponse(herb)
              : ResponseUtils.notFoundResponse('Herb not found');
        } catch (e) {
          return ResponseUtils.errorResponse(e);
        }
      },
    );

    // Update herb
    app.put(
      '/<id>',
      (Request request, String id) async {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body) as Map<String, dynamic>;
          
          final updatedHerb = await herbService.updateHerb(id, data);
          return ResponseUtils.successResponse(updatedHerb);
        } catch (e) {
          return ResponseUtils.errorResponse(e);
        }
      },
      middleware: [
        validate(HerbValidators.updateHerbSchema),
        authMiddleware.requireRole('admin')
      ],
    );

    // Herb quality assessment
    app.post(
      '/<id>/quality-assessment',
      (Request request, String id) async {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body) as Map<String, dynamic>;
          
          final assessment = await herbService.addQualityAssessment(id, data);
          return ResponseUtils.createdResponse(assessment);
        } catch (e) {
          return ResponseUtils.errorResponse(e);
        }
      },
      middleware: [
        validate(HerbValidators.qualityAssessmentSchema),
        authMiddleware.requireRole('quality-inspector')
      ],
    );

    return app;
  }
}
