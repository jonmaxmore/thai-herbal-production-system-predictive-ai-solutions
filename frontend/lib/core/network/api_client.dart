import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thai_herbal_app/core/constants/api_endpoints.dart';
import 'package:thai_herbal_app/core/di/service_locator.dart';
import 'package:thai_herbal_app/core/security/token_manager.dart';

class ApiClient {
  final Dio _dio;
  final Ref _ref;

  ApiClient(this._ref) : _dio = Dio() {
    _dio.options.baseUrl = ApiEndpoints.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.interceptors.add(AuthInterceptor(_ref));
    _dio.interceptors.add(LoggingInterceptor());
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    try {
      return await _dio.get(
        path,
        queryParameters: params,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> post(String path, dynamic data) async {
    try {
      return await _dio.post(
        path,
        data: jsonEncode(data),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  void _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      
      if (statusCode == 401) {
        sl<TokenManager>().clearTokens();
        // Trigger logout flow
      }
      
      throw ApiException(
        statusCode: statusCode,
        message: data['message'] ?? 'Unknown error',
        errorCode: data['errorCode'] ?? 'UNKNOWN_ERROR',
      );
    } else {
      throw ApiException(
        statusCode: 500,
        message: 'Network error: ${e.message}',
        errorCode: 'NETWORK_ERROR',
      );
    }
  }
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String errorCode;

  ApiException({
    this.statusCode,
    required this.message,
    required this.errorCode,
  });

  @override
  String toString() => 'ApiException: $errorCode - $message';
}

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _ref.read(tokenManagerProvider).getAccessToken();
    
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Attempt token refresh
      final tokenManager = _ref.read(tokenManagerProvider);
      final refreshed = await tokenManager.refreshTokens();
      
      if (refreshed) {
        final newToken = await tokenManager.getAccessToken();
        final request = err.requestOptions;
        request.headers['Authorization'] = 'Bearer $newToken';
        
        // Repeat request with new token
        final response = await _ref.read(apiClientProvider).dio.fetch(request);
        return handler.resolve(response);
      }
    }
    handler.next(err);
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('REQUEST[${options.method}] => PATH: ${options.path}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      'ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}',
    );
    super.onError(err, handler);
  }
}
