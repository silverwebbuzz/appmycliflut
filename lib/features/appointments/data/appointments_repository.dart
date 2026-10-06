import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../domain/appointment.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(apiClientProvider));
});

/// `appointments.php` list and the `home.php` dashboard aggregate.
class AppointmentsRepository {
  AppointmentsRepository(this._api);

  final ApiClient _api;

  Future<ApiResult<AppointmentList>> list() async {
    final result = await _api.get(
      '/appointments.php',
      queryParameters: {'action': 'list'},
    );
    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(AppointmentList.fromJson(value)),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<ApiResult<HomeSummary>> home() async {
    final result = await _api.get('/home.php');
    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(HomeSummary.fromJson(value)),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }
}
