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

  /// Saved doctors (`doctors.php?action=saved`). Capped at [SavedDoctors.max].
  Future<ApiResult<SavedDoctors>> saved() async {
    final result = await _api.get(
      '/doctors.php',
      queryParameters: {'action': 'saved'},
    );
    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(SavedDoctors.fromJson(value)),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  /// Saves or unsaves; returns the new `in_wishlist` state.
  /// `limit_reached` (409) when saving past the cap.
  Future<ApiResult<bool>> setSaved(int doctorId, {required bool saved}) async {
    final result = await _api.post(
      '/doctors.php',
      queryParameters: {'action': saved ? 'save' : 'unsave'},
      data: {'doctor_id': doctorId},
    );
    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(value['in_wishlist'] == true),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }
}

class SavedDoctors {
  const SavedDoctors({this.items = const [], this.max = 5});

  final List<Doctor> items;
  final int max;

  factory SavedDoctors.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return SavedDoctors(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Doctor.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      max: json['max'] is int ? json['max'] as int : 5,
    );
  }
}
