import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/session_storage.dart';
import 'api_result.dart';

typedef OnUnauthorized = void Function();

/// Dio client for `/api/mobile/v1` only.
/// - Attaches Bearer token from secure storage
/// - Does NOT use a cookie jar
class ApiClient {
  ApiClient({
    required SessionStorage sessionStorage,
    OnUnauthorized? onUnauthorized,
    Dio? dio,
  })  : _sessionStorage = sessionStorage,
        _onUnauthorized = onUnauthorized,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: kApiBaseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _sessionStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final data = error.response?.data;
          final code = data is Map ? data['error']?.toString() : null;
          if (status == 401 || code == 'login_required') {
            await _sessionStorage.clearToken();
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStorage _sessionStorage;
  final OnUnauthorized? _onUnauthorized;

  Dio get dio => _dio;

  Future<ApiResult<Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _mapResponse(response);
    } on DioException catch (e) {
      return _mapDioError(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _mapResponse(response);
    } on DioException catch (e) {
      return _mapDioError(e);
    }
  }

  ApiResult<Map<String, dynamic>> _mapResponse(Response<dynamic> response) {
    final status = response.statusCode;
    final body = response.data;
    if (body is Map<String, dynamic>) {
      return parseEnvelope(body, statusCode: status);
    }
    if (body is Map) {
      return parseEnvelope(Map<String, dynamic>.from(body), statusCode: status);
    }
    return ApiFailure(
      error: 'invalid_response',
      statusCode: status,
      message: 'Unexpected response shape',
    );
  }

  ApiResult<Map<String, dynamic>> _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      return parseEnvelope(map, statusCode: status);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiFailure(
        error: 'network_error',
        statusCode: status,
        message: 'Please check your internet connection.',
      );
    }
    return ApiFailure(
      error: 'server_error',
      statusCode: status,
      message: e.message,
    );
  }
}
