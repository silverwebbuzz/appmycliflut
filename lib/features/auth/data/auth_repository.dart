import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/patient.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SessionStorage sessionStorage,
  })  : _api = apiClient,
        _session = sessionStorage;

  final ApiClient _api;
  final SessionStorage _session;

  Future<ApiResult<Patient?>> me() async {
    final result = await _api.get('/auth.php', queryParameters: {'action': 'me'});
    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(
          value['patient'] == null
              ? null
              : Patient.fromJson(Map<String, dynamic>.from(value['patient'] as Map)),
        ),
      ApiFailure(
        :final error,
        :final statusCode,
        :final message,
      ) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<ApiResult<SendOtpResult>> sendOtp({
    required String phone,
    String? intent,
  }) async {
    final body = <String, dynamic>{'phone': phone};
    if (intent != null && intent.isNotEmpty) {
      body['intent'] = intent;
    }
    final result = await _api.post(
      '/auth.php',
      queryParameters: {'action': 'send_otp'},
      data: body,
    );
    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(SendOtpResult.fromJson(value)),
      ApiFailure(
        :final error,
        :final statusCode,
        :final message,
      ) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<ApiResult<VerifyOtpResult>> verifyOtp({
    required String phone,
    required String code,
    String? name,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'code': code,
    };
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }
    // Refer & Earn: only for a brand-new account, and only when given. The
    // server silently ignores an invalid code, so it never blocks sign-up.
    if (referralCode != null && referralCode.isNotEmpty) {
      body['referral_code'] = referralCode;
    }
    final result = await _api.post(
      '/auth.php',
      queryParameters: {'action': 'verify_otp'},
      data: body,
    );
    switch (result) {
      case ApiSuccess(:final value):
        final parsed = VerifyOtpResult.fromJson(value);
        await _session.saveToken(parsed.token);
        return ApiSuccess(parsed);
      case ApiFailure(:final error, :final statusCode, :final message):
        return ApiFailure(error: error, statusCode: statusCode, message: message);
    }
  }

  Future<ApiResult<void>> logout() async {
    final result = await _api.post(
      '/auth.php',
      queryParameters: {'action': 'logout'},
    );
    await _session.clearToken();
    return switch (result) {
      ApiSuccess() => const ApiSuccess(null),
      ApiFailure(
        :final error,
        :final statusCode,
        :final message,
      ) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<void> clearLocalSession() => _session.clearAllSession();
}

class SendOtpResult {
  const SendOtpResult({
    required this.phone,
    required this.mode,
    required this.exists,
    this.nameHint,
    this.devCode,
  });

  final String phone;
  final String mode;
  final bool exists;
  final String? nameHint;
  final String? devCode;

  factory SendOtpResult.fromJson(Map<String, dynamic> json) {
    return SendOtpResult(
      phone: (json['phone'] ?? '').toString(),
      mode: (json['mode'] ?? 'live').toString(),
      exists: json['exists'] == true,
      nameHint: json['name_hint']?.toString(),
      devCode: json['dev_code']?.toString(),
    );
  }
}

class VerifyOtpResult {
  const VerifyOtpResult({
    required this.token,
    required this.isNew,
    required this.patient,
  });

  final String token;
  final bool isNew;
  final Patient patient;

  factory VerifyOtpResult.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResult(
      token: (json['token'] ?? '').toString(),
      isNew: json['is_new'] == true,
      patient: Patient.fromJson(Map<String, dynamic>.from(json['patient'] as Map)),
    );
  }
}
