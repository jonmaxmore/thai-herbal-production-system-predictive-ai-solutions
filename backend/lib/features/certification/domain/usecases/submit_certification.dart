import 'package:injectable/injectable.dart';
import 'package:backend/core/errors/failures.dart';
import 'package:backend/features/certification/domain/repositories/certification_repository.dart';
import 'package:backend/features/certification/domain/entities/certification_application.dart';

@injectable
class SubmitCertificationUseCase {
  final CertificationRepository repository;

  SubmitCertificationUseCase(this.repository);

  Future<CertificationApplication> execute(String jsonData) async {
    try {
      final application = CertificationApplication.fromJson(jsonData);
      return await repository.submitApplication(application);
    } catch (e) {
      throw ServerFailure('Failed to submit application: ${e.toString()}');
    }
  }
}
