/// The logged-in person's own `patient_identities` row, from `profile.php`.
///
/// Everything is optional except `name`, which can be updated but never
/// blanked. The primary phone is read-only here: it is the verified account
/// key, and changing it runs through an OTP flow that v1 does not expose.
/// Sending `phone` to `save` is silently ignored by the server.
///
/// Field names mirror the DB columns exactly (`address_city`,
/// `emergency_contact_name`, …). The server's save whitelist
/// (`ecp_profile_map_fields`) silently drops any other key, so a guessed
/// name would "save" successfully and change nothing.
class PatientProfile {
  const PatientProfile({
    required this.name,
    this.initials,
    this.phone,
    this.phoneAlt,
    this.email,
    this.dob,
    this.age,
    this.gender,
    this.bloodGroup,
    this.vegType,
    this.allergies,
    this.chronicConditions,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.emergencyName,
    this.emergencyPhone,
    this.emergencyRelation,
    this.abhaId,
    this.hasPhoto = false,
    this.photoUrl,
    this.photoTag,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.phoneEditable = false,
    this.waOptIn = true,
  });

  final String name;
  final String? initials;

  /// Read-only in v1 — see [phoneEditable].
  final String? phone;
  final String? phoneAlt;
  final String? email;
  final String? dob;
  final int? age;

  /// `M` | `F` | `Other`.
  final String? gender;
  final String? bloodGroup;

  /// `veg` | `nonveg` | `vegan` | `eggetarian`.
  final String? vegType;
  final String? allergies;
  final String? chronicConditions;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelation;
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

  /// "WhatsApp updates" switch. Applies to the login number: off stops all
  /// WhatsApp messages (reminders, booking and order updates) but never the
  /// OTP. Defaults to on.
  final bool waOptIn;

  /// "29 · B+ · Ahmedabad" — whichever parts exist.
  String get summary {
    final parts = <String>[
      if (age != null) '$age yrs',
      ?bloodGroup,
      ?city,
    ];
    return parts.join(' · ');
  }

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
      phoneAlt: _asString(json['phone_alt']),
      email: _asString(json['email']),
      // The DB can hold a zero date; treat it as unset.
      dob: (_asString(json['dob'])?.startsWith('0000') ?? false)
          ? null
          : _asString(json['dob']),
      age: _asInt(json['age']),
      gender: _asString(json['gender']),
      bloodGroup: _asString(json['blood_group']),
      vegType: _asString(json['veg_type']),
      allergies: _asString(json['allergies']),
      chronicConditions: _asString(json['chronic_conditions']),
      addressLine1: _asString(json['address_line1']),
      addressLine2: _asString(json['address_line2']),
      city: _asString(json['address_city']),
      state: _asString(json['address_state']),
      pincode: _asString(json['address_postal_code']),
      emergencyName: _asString(json['emergency_contact_name']),
      emergencyPhone: _asString(json['emergency_contact_phone']),
      emergencyRelation: _asString(json['emergency_contact_relation']),
      abhaId: _asString(json['abha_id']),
      hasPhoto: json['has_photo'] == true,
      photoUrl: _asString(json['photo_url']),
      photoTag: _asString(json['photo_tag']),
      phoneVerified: json['phone_verified'] == true,
      emailVerified: json['email_verified'] == true,
      phoneEditable: json['phone_editable'] == true,
      waOptIn: json['wa_opt_in'] != false,
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

/// Human labels for the profile/family enums.
String genderLabel(String g) => switch (g) {
      'M' => 'Male',
      'F' => 'Female',
      _ => g,
    };

String vegLabel(String v) => switch (v) {
      'veg' => 'Vegetarian',
      'nonveg' => 'Non-veg',
      'vegan' => 'Vegan',
      'eggetarian' => 'Eggetarian',
      _ => v,
    };
