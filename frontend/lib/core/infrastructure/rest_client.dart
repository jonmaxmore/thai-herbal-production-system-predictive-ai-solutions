// lib/core/infrastructure/rest_client.dart
class RestClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  RestClient()
      : _dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL'),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        )),
        _storage = const FlutterSecureStorage() {
        
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _handleTokenExpiration();
        }
        return handler.next(error);
      },
    ));
  }

  Future<Response> authenticatedPost(String path, dynamic data) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw ApiFailure.fromDioError(e);
    }
  }

  void _handleTokenExpiration() {
    // Token refresh logic
  }
}
