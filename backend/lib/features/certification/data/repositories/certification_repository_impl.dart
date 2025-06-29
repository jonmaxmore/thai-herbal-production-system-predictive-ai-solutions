import 'package:injectable/injectable.dart';
import 'package:backend/features/certification/domain/repositories/certification_repository.dart';
import 'package:backend/features/certification/data/datasources/certification_remote_datasource.dart';

@Injectable(as: CertificationRepository)
class CertificationRepositoryImpl implements CertificationRepository {
  final CertificationRemoteDataSource remoteDataSource;

  CertificationRepositoryImpl(this.remoteDataSource);

  @override
  Future<CertificationApplication> submitApplication(
    CertificationApplication application,
  ) async {
    try {
      return await remoteDataSource.submitApplication(application);
    } catch (e) {
      throw Exception('Data source error: $e');
    }
  }
}
