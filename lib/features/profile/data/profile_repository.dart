import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../domain/patient_profile.dart';

/// `profile.php` — the logged-in person's own identity row.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<ApiResult<ProfileResult>> get() async {
    final result = await _api.get(
      '/profile.php',
      queryParameters: {'action': 'get'},
    );

    return switch (result) {
      ApiSuccess(:final value) => _parse(value),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  /// Partial save: only the keys passed are written, so a single field can be
  /// updated without resending the whole form.
  ///
  /// `phone` is deliberately absent — it is read-only in v1 and the server
  /// silently ignores it.
  Future<ApiResult<PatientProfile>> save({
    String? name,
    String? email,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? emergencyName,
    String? emergencyPhone,
    String? medicalNotes,
    String? allergies,
    String? vegType,
    String? abhaId,
  }) async {
    final result = await _api.post(
      '/profile.php',
      queryParameters: {'action': 'save'},
      data: {
        'name': ?name,
        'email': ?email,
        'dob': ?dob,
        'gender': ?gender,
        'blood_group': ?bloodGroup,
        'address': ?address,
        'city': ?city,
        'state': ?state,
        'pincode': ?pincode,
        'emergency_name': ?emergencyName,
        'emergency_phone': ?emergencyPhone,
        'medical_notes': ?medicalNotes,
        'allergies': ?allergies,
        'veg_type': ?vegType,
        'abha_id': ?abhaId,
      },
    );

    return switch (result) {
      ApiSuccess(:final value) => _profileOnly(value),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  /// Uploads an avatar. **multipart**, binary part named `file`.
  /// Server limits: 4 MB, JPEG/PNG/WebP.
  Future<ApiResult<Map<String, dynamic>>> uploadPhoto(
    String filePath, {
    String? fileName,
  }) {
    return _api.upload(
      '/profile.php',
      queryParameters: {'action': 'photo'},
      filePath: filePath,
      fileName: fileName,
    );
  }

  /// Fetches the avatar bytes. Authed and not public, so this cannot be an
  /// `Image.network` URL.
  Future<ApiResult<Uint8List>> photo() {
    return _api.bytes(
      '/profile.php',
      queryParameters: {'action': 'photo'},
    );
  }

  Future<ApiResult<bool>> removePhoto() async {
    final result = await _api.post(
      '/profile.php',
      queryParameters: {'action': 'photo_remove'},
    );

    return switch (result) {
      ApiSuccess() => const ApiSuccess(true),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  ApiResult<ProfileResult> _parse(Map<String, dynamic> json) {
    final profile = json['profile'];
    if (profile is! Map) {
      return const ApiFailure(
        error: 'invalid_response',
        message: 'Profile payload was missing.',
      );
    }
    return ApiSuccess(
      ProfileResult(
        profile:
            PatientProfile.fromJson(Map<String, dynamic>.from(profile)),
        options: ProfileOptions.fromJson(
          json['options'] is Map
              ? Map<String, dynamic>.from(json['options'] as Map)
              : null,
        ),
      ),
    );
  }

  ApiResult<PatientProfile> _profileOnly(Map<String, dynamic> json) {
    final profile = json['profile'];
    if (profile is! Map) {
      return const ApiFailure(
        error: 'invalid_response',
        message: 'Profile payload was missing.',
      );
    }
    return ApiSuccess(
      PatientProfile.fromJson(Map<String, dynamic>.from(profile)),
    );
  }
}

class ProfileResult {
  const ProfileResult({required this.profile, required this.options});

  final PatientProfile profile;
  final ProfileOptions options;
}
