/// Result wrapper for eClinicPro mobile API.
/// Envelope is `{ "ok": true, ... }` / `{ "ok": false, "error": "code" }`.
/// There is NO generic `data` key — each endpoint names its own payload keys.
sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.value);
  final T value;
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure({
    required this.error,
    this.statusCode,
    this.message,
  });

  /// Server `error` code, e.g. `login_required`, `invalid_code`.
  final String error;
  final int? statusCode;
  final String? message;

  bool get isLoginRequired =>
      error == 'login_required' || statusCode == 401;
}

/// Parse a JSON map into success/failure without assuming a `data` key.
ApiResult<Map<String, dynamic>> parseEnvelope(Map<String, dynamic> json, {int? statusCode}) {
  final ok = json['ok'] == true;
  if (ok) {
    return ApiSuccess(json);
  }
  return ApiFailure(
    error: (json['error'] ?? 'unknown_error').toString(),
    statusCode: statusCode,
    message: json['message']?.toString(),
  );
}
