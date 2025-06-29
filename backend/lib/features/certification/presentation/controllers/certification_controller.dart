import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/core/di/injector.dart';
import 'package:backend/features/certification/domain/usecases/submit_certification.dart';

class CertificationController {
  final SubmitCertificationUseCase _submitUseCase;

  CertificationController() 
      : _submitUseCase = injector.get<SubmitCertificationUseCase>();

  Router get router {
    final router = Router();

    // ส่งใบสมัครรับรองมาตรฐาน
    router.post('/submit', (Request request) async {
      final data = await request.readAsString();
      final result = await _submitUseCase.execute(data);
      return Response.ok(jsonEncode(result.toJson()));
    });

    // จัดตารางประชุมออนไลน์
    router.put('/<id>/schedule-remote', (Request request, String id) async {
      final data = await request.readAsString();
      // ... ทำงานกับข้อมูล ...
      return Response.ok('Scheduled remote meeting');
    });

    // ... endpoints อื่นๆ ...

    return router;
  }
}
