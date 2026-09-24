/// A row from `family.php`.
///
/// A `self` row is auto-created on the first `list` call, cannot be removed,
/// and has its relation pinned to `self`. The cap is 6 members including self.
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    this.initials,
    this.relation,
    this.isSelf = false,
    this.dob,
    this.age,
    this.gender,
    this.bloodGroup,
    this.abhaId,
  });

  final int id;
  final String name;

  /// Derived server-side so every client shows the same letters.
  final String? initials;

  /// Raw DB enum value, e.g. `spouse`, `mother`, `self`.
  final String? relation;
  final bool isSelf;
  final String? dob;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final String? abhaId;

  /// "Spouse · 34" — whichever parts exist.
  String? get subtitle {
    final parts = <String>[
      if (relation != null) FamilyRelations.label(relation!),
      if (age != null) '$age',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static int? _asInt(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static String? _asString(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']) ?? 'Unnamed',
      initials: _asString(json['initials']),
      relation: _asString(json['relation']),
      isSelf: json['is_self'] == true,
      dob: _asString(json['dob']),
      age: _asInt(json['age']),
      gender: _asString(json['gender']),
      bloodGroup: _asString(json['blood_group']),
      abhaId: _asString(json['abha_id']),
    );
  }
}

/// The choices `family.php` offers, as returned in `options`.
///
/// These are rendered from the server response rather than hardcoded, because
/// the design and the database disagree: the design shows Husband/Wife chips,
/// but the DB enum only has `spouse`. Unrecognised values store as `other`.
class FamilyOptions {
  const FamilyOptions({
    this.relations = const [],
    this.genders = const [],
    this.bloodGroups = const [],
  });

  final List<String> relations;
  final List<String> genders;
  final List<String> bloodGroups;

  static List<String> _list(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  factory FamilyOptions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FamilyOptions();
    return FamilyOptions(
      relations: _list(json['relations']),
      genders: _list(json['genders']),
      bloodGroups: _list(json['blood_groups']),
    );
  }
}

/// Maps between the DB's relation enum and what a person should read.
class FamilyRelations {
  const FamilyRelations._();

  /// Design-facing aliases that must collapse onto the DB's `spouse`.
  static const _toDb = <String, String>{
    'husband': 'spouse',
    'wife': 'spouse',
    'partner': 'spouse',
  };

  /// Normalises a picked label to a value the API will accept.
  ///
  /// Anything the server did not offer is sent as `other`, matching the
  /// documented server behaviour rather than risking a rejected write.
  static String toApiValue(String picked, List<String> allowed) {
    final v = picked.trim().toLowerCase();
    final mapped = _toDb[v] ?? v;
    if (allowed.map((e) => e.toLowerCase()).contains(mapped)) return mapped;
    return allowed.contains('other') ? 'other' : mapped;
  }

  /// Sentence-cased label for a raw enum value.
  static String label(String relation) {
    final v = relation.trim();
    if (v.isEmpty) return v;
    if (v.toLowerCase() == 'self') return 'You';
    return v[0].toUpperCase() + v.substring(1).toLowerCase();
  }
}
