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

  /// Partial save: only the keys in [fields] are written, so a single field
  /// can be updated without resending the whole form. An empty string clears
  /// a field (the server stores it as NULL); `name` can never be blanked.
  ///
  /// Keys must be the DB column names the server whitelists — see
  /// [ProfileFields]. `phone` is deliberately absent: it is read-only in v1
  /// and the server silently ignores it.
  Future<ApiResult<PatientProfile>> save(Map<String, Object> fields) async {
    final result = await _api.post(
      '/profile.php',
      queryParameters: {'action': 'save'},
      data: fields,
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

/// The save keys `ecp_profile_map_fields` accepts. Anything else is dropped
/// without an error, so use these rather than typing keys by hand.
abstract final class ProfileFields {
  static const name = 'name';
  static const email = 'email';
  static const phoneAlt = 'phone_alt';
  static const dob = 'dob';
  static const gender = 'gender';
  static const bloodGroup = 'blood_group';
  static const vegType = 'veg_type';
  static const allergies = 'allergies';
  static const chronicConditions = 'chronic_conditions';
  static const addressLine1 = 'address_line1';
  static const addressLine2 = 'address_line2';
  static const city = 'address_city';
  static const state = 'address_state';
  static const pincode = 'address_postal_code';
  static const emergencyName = 'emergency_contact_name';
  static const emergencyPhone = 'emergency_contact_phone';
  static const emergencyRelation = 'emergency_contact_relation';
  static const abhaId = 'abha_id';

  /// Bool. Stored in the messaging opt-out list, not the profile row.
  static const waOptIn = 'wa_opt_in';
}

class ProfileResult {
  const ProfileResult({required this.profile, required this.options});

  final PatientProfile profile;
  final ProfileOptions options;
}
