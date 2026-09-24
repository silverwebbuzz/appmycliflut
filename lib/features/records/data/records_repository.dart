import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../domain/medical_record.dart';

/// Backs both record vaults: `prescriptions.php` and `lab_reports.php`.
///
/// The two endpoints share a shape, so [RecordKind] selects the path and every
/// method serves both. Paths are relative to `kApiBaseUrl`.
class RecordsRepository {
  RecordsRepository(this._api);

  final ApiClient _api;

  Future<ApiResult<List<MedicalRecord>>> list(RecordKind kind) async {
    final result = await _api.get(
      '/${kind.endpoint}',
      queryParameters: {'action': 'list'},
    );

    return switch (result) {
      ApiSuccess(:final value) => ApiSuccess(_parseItems(value, kind)),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  Future<ApiResult<MedicalRecord>> detail(RecordKind kind, int id) async {
    final result = await _api.get(
      '/${kind.endpoint}',
      queryParameters: {'action': 'detail', 'id': id},
    );

    return switch (result) {
      ApiSuccess(:final value) => _parseItem(value, kind),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  /// Downloads the attached file.
  ///
  /// `?action=file` returns raw bytes and requires the Bearer header, so the
  /// caller renders from memory — `Image.network` cannot read this route.
  Future<ApiResult<Uint8List>> file(RecordKind kind, int id) {
    return _api.bytes(
      '/${kind.endpoint}',
      queryParameters: {'action': 'file', 'id': id},
    );
  }

  /// Creates a record. **multipart/form-data**, binary part named `file`.
  ///
  /// The attachment is optional — metadata alone is valid. Server limits:
  /// 10 MB, PDF/JPEG/PNG/WebP.
  Future<ApiResult<MedicalRecord>> add(
    RecordKind kind, {
    required String label,
    String? doctorName,
    String? clinicName,
    String? labName,
    String? testType,
    String? notes,
    String? dateIso,
    int? familyMemberId,
    String? filePath,
    String? fileName,
  }) async {
    final result = await _api.upload(
      '/${kind.endpoint}',
      queryParameters: {'action': 'add'},
      fields: {
        'label': label,
        if (doctorName != null && doctorName.isNotEmpty)
          'doctor_name': doctorName,
        if (clinicName != null && clinicName.isNotEmpty)
          'clinic_name': clinicName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (familyMemberId != null) 'family_member_id': '$familyMemberId',
        // The vaults name their date and source fields differently.
        if (dateIso != null && dateIso.isNotEmpty)
          if (kind == RecordKind.prescription)
            'issued_on': dateIso
          else
            'reported_on': dateIso,
        if (kind == RecordKind.labReport) ...{
          if (labName != null && labName.isNotEmpty) 'lab_name': labName,
          if (testType != null && testType.isNotEmpty) 'test_type': testType,
        },
      },
      filePath: filePath,
      fileName: fileName,
    );

    return switch (result) {
      ApiSuccess(:final value) => _parseItem(value, kind),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  /// Soft-deletes a record.
  Future<ApiResult<bool>> remove(RecordKind kind, int id) async {
    final result = await _api.post(
      '/${kind.endpoint}',
      queryParameters: {'action': 'remove'},
      data: {'id': id},
    );

    return switch (result) {
      ApiSuccess() => const ApiSuccess(true),
      ApiFailure(:final error, :final statusCode, :final message) =>
        ApiFailure(error: error, statusCode: statusCode, message: message),
    };
  }

  List<MedicalRecord> _parseItems(Map<String, dynamic> json, RecordKind kind) {
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => MedicalRecord.fromJson(
              Map<String, dynamic>.from(e),
              kind: kind,
            ))
        .toList();
  }

  ApiResult<MedicalRecord> _parseItem(
    Map<String, dynamic> json,
    RecordKind kind,
  ) {
    final item = json['item'];
    if (item is! Map) {
      return const ApiFailure(
        error: 'invalid_response',
        message: 'Record payload was missing.',
      );
    }
    return ApiSuccess(
      MedicalRecord.fromJson(Map<String, dynamic>.from(item), kind: kind),
    );
  }
}
