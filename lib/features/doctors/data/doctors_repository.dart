import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../domain/doctor.dart';

class DoctorsRepository {
  DoctorsRepository(this._api);

  final ApiClient _api;

  Future<ApiResult<DoctorSearchResult>> search({
    String? q,
    String? city,
    String? spec,
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _api.get(
      '/doctors.php',
      queryParameters: {
        'action': 'search',
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (spec != null && spec.trim().isNotEmpty) 'spec': spec.trim(),
        'page': page,
        'per_page': perPage,
      },
    );

    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(DoctorSearchResult.fromJson(value)),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<ApiResult<Doctor>> detail(int id) async {
    final result = await _api.get(
      '/doctors.php',
      queryParameters: {
        'action': 'detail',
        'id': id,
      },
    );

    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(
          Doctor.fromJson(Map<String, dynamic>.from(value['doctor'] as Map)),
        ),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<ApiResult<void>> trackView(int doctorId) async {
    final result = await _api.post(
      '/appointments.php',
      queryParameters: {'action': 'track'},
      data: {'doctor_id': doctorId, 'type': 'view'},
    );
    return switch (result) {
      ApiSuccess() => const ApiSuccess(null),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }
}
