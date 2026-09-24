import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../domain/queue_status.dart';

/// `queue.php` — live token status for today's visit.
class QueueRepository {
  QueueRepository(this._api);

  final ApiClient _api;

  /// Status for [appointmentId], or the soonest upcoming appointment when it
  /// is omitted. A foreign appointment id returns `404 not_found`.
  Future<ApiResult<QueueStatus>> status({int? appointmentId}) async {
    final result = await _api.get(
      '/queue.php',
      queryParameters: {
        'action': 'status',
        'appointment_id': ?appointmentId,
      },
    );

    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(QueueStatus.fromJson(value)),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }
}
