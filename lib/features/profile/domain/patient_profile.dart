/// The logged-in person's own `patient_identities` row, from `profile.php`.
///
/// Everything is optional except `name`, which can be updated but never
/// blanked. The primary phone is read-only here: it is the verified account
/// key, and changing it runs through an OTP flow that v1 does not expose.
/// Sending `phone` to `save` is silently ignored by the server.
class PatientProfile {
  const PatientProfile({
    required this.name,
    this.initials,
    this.phone,
    this.email,
    this.dob,
    this.age,
    this.gender,
    this.bloodGroup,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.emergencyName,
    this.emergencyPhone,
    this.medicalNotes,
    this.allergies,
    this.vegType,
    this.abhaId,
    this.hasPhoto = false,
    this.photoUrl,
    this.photoTag,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.phoneEditable = false,
  });

  final String name;
  final String? initials;

  /// Read-only in v1 — see [phoneEditable].
  final String? phone;
  final String? email;
  final String? dob;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? medicalNotes;
  final String? allergies;

  /// `veg` | `nonveg` | `vegan` | `eggetarian`.
  final String? vegType;
  final String? abhaId;

  final bool hasPhoto;

  /// Relative, authed path — needs the Bearer header, so it cannot go to
  /// `Image.network`.
  final String? photoUrl;

  /// Cache-buster; append it so a replaced avatar actually refreshes.
  final String? photoTag;

  final bool phoneVerified;
  final bool emailVerified;
  final bool phoneEditable;

  static int? _asInt(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static String? _asString(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      name: _asString(json['name']) ?? '',
      initials: _asString(json['initials']),
      phone: _asString(json['phone']),
      email: _asString(json['email']),
      dob: _asString(json['dob']),
      age: _asInt(json['age']),
      gender: _asString(json['gender']),
      bloodGroup: _asString(json['blood_group']),
      address: _asString(json['address']),
      city: _asString(json['city']),
      state: _asString(json['state']),
      pincode: _asString(json['pincode']),
      emergencyName: _asString(json['emergency_name']),
      emergencyPhone: _asString(json['emergency_phone']),
      medicalNotes: _asString(json['medical_notes']),
      allergies: _asString(json['allergies']),
      vegType: _asString(json['veg_type']),
      abhaId: _asString(json['abha_id']),
      hasPhoto: json['has_photo'] == true,
      photoUrl: _asString(json['photo_url']),
      photoTag: _asString(json['photo_tag']),
      phoneVerified: json['phone_verified'] == true,
      emailVerified: json['email_verified'] == true,
      phoneEditable: json['phone_editable'] == true,
    );
  }
}

/// Choice lists from `profile.php`'s `options`.
class ProfileOptions {
  const ProfileOptions({
    this.genders = const [],
    this.bloodGroups = const [],
    this.vegTypes = const [],
  });

  final List<String> genders;
  final List<String> bloodGroups;
  final List<String> vegTypes;

  static List<String> _list(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  factory ProfileOptions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProfileOptions();
    return ProfileOptions(
      genders: _list(json['genders']),
      bloodGroups: _list(json['blood_groups']),
      vegTypes: _list(json['veg_types']),
    );
  }
}
