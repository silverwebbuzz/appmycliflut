/// An item from `appointments.php?action=list` (or `home.php`'s
/// `next_appointment`).
///
/// Two kinds share the shape: `appointment` is a real visit a clinic has on
/// its books, and `lead` is a request sent to a clinic that has not been
/// confirmed yet. Bind the pretty `when_date` / `when_time` directly; keep
/// `when_iso` for sorting.
class Appointment {
  const Appointment({
    required this.id,
    required this.kind,
    this.whenIso,
    this.whenDate,
    this.whenTime,
    this.status,
    this.isFollowup = false,
    this.tokenNumber,
    this.reason,
    this.doctorName,
    this.doctorSpec,
    this.clinicName,
    this.clinicPhone,
    this.clinicAddress,
  });

  final int id;

  /// `appointment` or `lead`.
  final String kind;
  final String? whenIso;
  final String? whenDate;
  final String? whenTime;

  /// Appointment: `scheduled`, `confirmed`, `in_progress`, `completed`… —
  /// Lead: `awaiting_clinic`, `clinic_viewed`, `delivery_failed`.
  final String? status;
  final bool isFollowup;

  /// Assigned only once reception starts the visit.
  final int? tokenNumber;
  final String? reason;
  final String? doctorName;
  final String? doctorSpec;
  final String? clinicName;
  final String? clinicPhone;
  final String? clinicAddress;

  bool get isLead => kind == 'lead';

  /// "Fri, 3 Oct 2026 · 5:40 PM".
  String get whenLabel => [whenDate, whenTime]
      .where((e) => e != null && e.isNotEmpty)
      .join(' · ');

  String get title => doctorName ?? clinicName ?? 'Appointment';

  /// Clinic line under the title, without repeating the title.
  String? get subtitle {
    final parts = <String>[
      ?doctorSpec,
      if (clinicName != null && clinicName != title) clinicName!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Short status for a pill, in the patient's terms.
  String get statusLabel => switch (status) {
        'awaiting_clinic' => 'Request sent',
        'clinic_viewed' => 'Seen by clinic',
        'delivery_failed' => 'Not delivered',
        'scheduled' => 'Scheduled',
        'confirmed' => 'Confirmed',
        'in_progress' => 'In progress',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        'no_show' => 'Missed',
        null => isLead ? 'Request sent' : 'Booked',
        final s => s[0].toUpperCase() + s.substring(1).replaceAll('_', ' '),
      };

  String get initials {
    final words = title
        .replaceFirst(RegExp(r'^Dr\.?\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first[0];
    return (words.length == 1 ? first : first + words.last[0]).toUpperCase();
  }

  static int? _asInt(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static String? _asString(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory Appointment.fromJson(Map<String, dynamic> json, {String? kind}) {
    return Appointment(
      id: _asInt(json['id']) ?? 0,
      kind: _asString(json['kind']) ?? kind ?? 'appointment',
      whenIso: _asString(json['when_iso']),
      whenDate: _asString(json['when_date']),
      whenTime: _asString(json['when_time']),
      status: _asString(json['status']),
      isFollowup: json['is_followup'] == true,
      tokenNumber: _asInt(json['token_number']),
      reason: _asString(json['reason']),
      doctorName: _asString(json['doctor_name']),
      doctorSpec: _asString(json['doctor_spec']),
      clinicName: _asString(json['clinic_name']),
      clinicPhone: _asString(json['clinic_phone']),
      clinicAddress: _asString(json['clinic_address']),
    );
  }
}

class AppointmentList {
  const AppointmentList({
    this.upcoming = const [],
    this.past = const [],
    this.pending = const [],
  });

  final List<Appointment> upcoming;
  final List<Appointment> past;

  /// Requests to clinics that have not confirmed yet.
  final List<Appointment> pending;

  static List<Appointment> _list(Object? raw, String kind) => raw is List
      ? raw
          .whereType<Map>()
          .map((e) =>
              Appointment.fromJson(Map<String, dynamic>.from(e), kind: kind))
          .toList()
      : const [];

  factory AppointmentList.fromJson(Map<String, dynamic> json) {
    return AppointmentList(
      upcoming: _list(json['upcoming'], 'appointment'),
      past: _list(json['past'], 'appointment'),
      pending: _list(json['pending_leads'], 'lead'),
    );
  }
}

/// `home.php` — the dashboard aggregate.
class HomeSummary {
  const HomeSummary({
    this.firstName,
    this.nextAppointment,
    this.upcoming = 0,
    this.pendingRequests = 0,
    this.savedDoctors = 0,
  });

  final String? firstName;
  final Appointment? nextAppointment;
  final int upcoming;
  final int pendingRequests;
  final int savedDoctors;

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    final next = json['next_appointment'];
    final counts = json['counts'] is Map
        ? Map<String, dynamic>.from(json['counts'] as Map)
        : const <String, dynamic>{};
    int count(String k) => Appointment._asInt(counts[k]) ?? 0;
    return HomeSummary(
      firstName: patient is Map ? Appointment._asString(patient['first_name']) : null,
      nextAppointment: next is Map
          ? Appointment.fromJson(Map<String, dynamic>.from(next))
          : null,
      upcoming: count('upcoming'),
      pendingRequests: count('pending_requests'),
      savedDoctors: count('saved_doctors'),
    );
  }
}
