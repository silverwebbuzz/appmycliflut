import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../domain/family_member.dart';

/// `family.php` — family profiles, capped at 6 including the auto-created
/// `self` row.
class FamilyRepository {
  FamilyRepository(this._api);

  final ApiClient _api;

  Future<ApiResult<FamilyListResult>> list() async {
    final result = await _api.get(
      '/family.php',
      queryParameters: {'action': 'list'},
    );

    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(FamilyListResult.fromJson(value)),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<ApiResult<FamilyMember>> detail(int id) async {
    final result = await _api.get(
      '/family.php',
      queryParameters: {'action': 'detail', 'id': id},
    );

    return switch (result) {
      ApiSuccess(:final value) => _member(value),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  /// Creates when [memberId] is null, updates otherwise.
  ///
  /// [relation] must already be normalised through
  /// [FamilyRelations.toApiValue] so design labels like "Wife" reach the
  /// server as the DB's `spouse`.
  Future<ApiResult<FamilyMember>> save({
    int? memberId,
    required String name,
    String? relation,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? abhaId,
  }) async {
    final result = await _api.post(
      '/family.php',
      queryParameters: {'action': 'save'},
      data: {
        'member_id': ?memberId,
        'name': name,
        // NOT a partial write (unlike profile.php): `ecp_fam_save_member`
        // rewrites every column, so an omitted field is cleared and an
        // omitted relation becomes `other`. Always send the whole form.
        'relation': relation ?? '',
        'dob': dob ?? '',
        'gender': gender ?? '',
        'blood_group': bloodGroup ?? '',
        'abha_id': abhaId ?? '',
      },
    );

    return switch (result) {
      ApiSuccess(:final value) => _member(value),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  /// Removes a member. The `self` row cannot be removed — the server answers
  /// `cannot_remove_self` (409).
  Future<ApiResult<bool>> remove(int memberId) async {
    final result = await _api.post(
      '/family.php',
      queryParameters: {'action': 'remove'},
      data: {'member_id': memberId},
    );

    return switch (result) {
      ApiSuccess() => const ApiSuccess(true),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  ApiResult<FamilyMember> _member(Map<String, dynamic> json) {
    final member = json['member'];
    if (member is! Map) {
      return const ApiFailure(
        error: 'invalid_response',
        message: 'Member payload was missing.',
      );
    }
    return ApiSuccess(FamilyMember.fromJson(Map<String, dynamic>.from(member)));
  }
}

/// `list` returns the roster plus the choice lists and the add-cap.
class FamilyListResult {
  const FamilyListResult({
    this.members = const [],
    this.options = const FamilyOptions(),
    this.canAdd = true,
    this.maxMembers = 6,
  });

  final List<FamilyMember> members;
  final FamilyOptions options;
  final bool canAdd;
  final int maxMembers;

  factory FamilyListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['members'];
    return FamilyListResult(
      members: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      options: FamilyOptions.fromJson(
        json['options'] is Map
            ? Map<String, dynamic>.from(json['options'] as Map)
            : null,
      ),
      canAdd: json['can_add'] != false,
      maxMembers: json['max_members'] is int
          ? json['max_members'] as int
          : int.tryParse('${json['max_members']}') ?? 6,
    );
  }
}
