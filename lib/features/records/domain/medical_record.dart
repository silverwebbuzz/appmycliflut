/// A row from either record vault.
///
/// `prescriptions.php` and `lab_reports.php` return the same shape apart from
/// a few labels, so one model backs both and [kind] says which vault it came
/// from. That keeps the Records list and its two tabs on one code path.
///
/// Note what is deliberately absent: there are **no medicine lines, dosages,
/// diagnosis text, numeric results, units or reference ranges** in the
/// database. The API reference calls this out for both vaults. Rendering an
/// itemised prescription or a lab trend chart is therefore impossible from
/// this data, and neither is attempted — the app shows this metadata plus the
/// attached file.
enum RecordKind {
  prescription('prescriptions.php', 'Prescription'),
  labReport('lab_reports.php', 'Lab report');

  const RecordKind(this.endpoint, this.label);

  /// Path under `kApiBaseUrl`; never hardcode a full URL per call.
  final String endpoint;
  final String label;
}

class MedicalRecord {
  const MedicalRecord({
    required this.id,
    required this.kind,
    required this.label,
    this.familyMemberId,
    this.doctorName,
    this.clinicName,
    this.labName,
    this.testType,
    this.notes,
    this.dateIso,
    this.source,
    this.isClinic = false,
    this.hasFile = false,
    this.fileMime,
    this.isPdf = false,
    this.fileUrl,
  });

  final int id;
  final RecordKind kind;

  /// Free-text snapshot, e.g. "Dr. Shah — 12 Aug — Diabetes".
  final String label;
  final int? familyMemberId;
  final String? doctorName;
  final String? clinicName;

  /// Lab reports only.
  final String? labName;
  final String? testType;
  final String? notes;

  /// `issued_on` for prescriptions, `reported_on` for lab reports.
  final String? dateIso;

  /// `upload` (patient added) or `clinic` (a doctor shared it).
  final String? source;
  final bool isClinic;

  final bool hasFile;
  final String? fileMime;
  final bool isPdf;

  /// Relative path from the server, e.g.
  /// `api/mobile/v1/prescriptions.php?action=file&id=12`. Requires the Bearer
  /// header, so it cannot be handed to `Image.network`.
  final String? fileUrl;

  /// True when the file is an image the app can render inline.
  bool get isImage =>
      hasFile && !isPdf && (fileMime?.startsWith('image/') ?? false);

  /// "Shah Family Clinic · Dr. Arjun Shah" — whichever parts exist.
  String? get subtitle {
    final parts = <String>[
      if (kind == RecordKind.labReport && (labName?.isNotEmpty ?? false))
        labName!,
      if (doctorName?.isNotEmpty ?? false) doctorName!,
      if (clinicName?.isNotEmpty ?? false) clinicName!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static int? _asInt(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static String? _asString(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory MedicalRecord.fromJson(
    Map<String, dynamic> json, {
    required RecordKind kind,
  }) {
    return MedicalRecord(
      id: _asInt(json['id']) ?? 0,
      kind: kind,
      label: _asString(json['label']) ?? 'Untitled',
      familyMemberId: _asInt(json['family_member_id']),
      doctorName: _asString(json['doctor_name']),
      clinicName: _asString(json['clinic_name']),
      labName: _asString(json['lab_name']),
      testType: _asString(json['test_type']),
      notes: _asString(json['notes']),
      // The two vaults name their date column differently.
      dateIso: _asString(json['issued_on']) ?? _asString(json['reported_on']),
      source: _asString(json['source']),
      isClinic: json['is_clinic'] == true,
      hasFile: json['has_file'] == true,
      fileMime: _asString(json['file_mime']),
      isPdf: json['is_pdf'] == true,
      fileUrl: _asString(json['file_url']),
    );
  }
}
