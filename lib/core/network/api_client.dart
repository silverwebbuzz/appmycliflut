import 'dart:convert';
import 'dart:typed_data';

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

  /// Multipart upload. The binary part is named exactly `file`, which is what
  /// prescriptions/lab_reports `add` and profile `photo` require — these are
  /// NOT JSON endpoints.
  ///
  /// [filePath] is optional: prescriptions and lab reports accept metadata
  /// with no attachment.
  Future<ApiResult<Map<String, dynamic>>> upload(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String> fields = const {},
    String? filePath,
    String? fileName,
  }) async {
    try {
      final form = FormData.fromMap({
        ...fields,
        if (filePath != null)
          'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post<dynamic>(
        path,
        data: form,
        queryParameters: queryParameters,
        // Let Dio set the multipart boundary; the JSON default would break it.
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return _mapResponse(response);
    } on DioException catch (e) {
      return _mapDioError(e);
    }
  }

  /// Fetches raw bytes from an authed binary route (`?action=file`,
  /// `?action=photo`).
  ///
  /// These require the Bearer header, so `Image.network` cannot read them —
  /// callers render from memory instead.
  Future<ApiResult<Uint8List>> bytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        return const ApiFailure(
          error: 'empty_file',
          message: 'The server returned no file data.',
        );
      }
      return ApiSuccess(Uint8List.fromList(data));
    } on DioException catch (e) {
      // Error bodies come back as bytes here; decode so the real code shows.
      final body = e.response?.data;
      if (body is List<int>) {
        try {
          final decoded = jsonDecode(utf8.decode(body));
          if (decoded is Map<String, dynamic>) {
            final parsed =
                parseEnvelope(decoded, statusCode: e.response?.statusCode);
            if (parsed is ApiFailure<Map<String, dynamic>>) {
              return ApiFailure(
                error: parsed.error,
                statusCode: parsed.statusCode,
                message: parsed.message,
              );
            }
          }
        } on FormatException {
          // Not JSON — fall through to the generic mapping below.
        }
      }
      final mapped = _mapDioError(e);
      return switch (mapped) {
        ApiFailure(:final error, :final statusCode, :final message) =>
          ApiFailure(error: error, statusCode: statusCode, message: message),
        ApiSuccess() => const ApiFailure(
            error: 'invalid_response',
            message: 'Unexpected response shape',
          ),
      };
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
    // A non-JSON body almost always means the route is missing: Apache
    // strips `.php`, redirects to the extensionless path and the SPA answers
    // with an HTML 404. Name that explicitly so it is not mistaken for a
    // parsing bug in the app.
    final looksLikeHtml =
        body is String && body.trimLeft().toLowerCase().startsWith('<');
    return ApiFailure(
      error: looksLikeHtml ? 'endpoint_not_deployed' : 'invalid_response',
      statusCode: status,
      message: looksLikeHtml
          ? 'Server returned a web page instead of JSON — this endpoint is '
              'probably not deployed yet.'
          : 'Unexpected response shape',
    );
  }

  ApiResult<Map<String, dynamic>> _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      return parseEnvelope(map, statusCode: status);
    }
    if (status != null && status >= 300 && status < 400) {
      return ApiFailure(
        error: 'endpoint_not_deployed',
        statusCode: status,
        message: 'Endpoint redirected instead of answering — it is probably '
            'not deployed yet.',
      );
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
