import 'package:thai_herbal_backend/core/config/app_config.dart';
import 'package:thai_herbal_backend/core/utils/logger.dart';
import 'package:thai_herbal_backend/core/security/encryption_service.dart';
import '../clients/fda_client.dart';
import '../models/fda_product.dart';

class FDAService {
  final FdaClient _client;
  final EncryptionService _encryptionService;
  final String _apiKey;

  FDAService(AppConfig config, this._encryptionService)
      : _client = FdaClient(config.fdaApiUrl),
        _apiKey = config.fdaApiKey;

  Future<FDAProductRegistrationResponse> registerProduct(
    FDAProductRegistrationRequest request,
  ) async {
    try {
      // Encrypt sensitive data
      final encryptedRequest = request.copyWith(
        manufacturerDetails: _encryptData(request.manufacturerDetails),
        ingredientList: request.ingredientList.map(_encryptData).toList(),
      );

      final response = await _client.registerProduct(
        encryptedRequest,
        apiKey: _apiKey,
      );

      // Decrypt response if needed
      return response.copyWith(
        registrationId: _decryptData(response.registrationId),
        certificateUrl: _decryptData(response.certificateUrl),
      );
    } catch (e) {
      Logger.error('FDA product registration failed: $e');
      rethrow;
    }
  }

  Future<FDACertificateStatus> checkCertificateStatus(
    String certificateId,
  ) async {
    try {
      final encryptedId = _encryptData(certificateId);
      final status = await _client.getCertificateStatus(
        encryptedId,
        apiKey: _apiKey,
      );
      
      return status.copyWith(
        certificateId: _decryptData(status.certificateId),
      );
    } catch (e) {
      Logger.error('FDA certificate check failed: $e');
      rethrow;
    }
  }

  String _encryptData(String data) {
    return _encryptionService.encrypt(data);
  }

  String _decryptData(String encryptedData) {
    return _encryptionService.decrypt(encryptedData);
  }
}
