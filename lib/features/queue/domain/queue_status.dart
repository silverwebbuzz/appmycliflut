/// Live token state from `queue.php?action=status`.
///
/// Tokens are per **clinic, per day** — not per doctor — and are only assigned
/// once reception moves a visit to `in_progress`. A confirmed appointment
/// therefore has no token yet, which is why [QueueInfo.hasToken] must be
/// handled rather than assumed.
class QueueStatus {
  const QueueStatus({
    required this.inQueue,
    this.reason,
    this.appointment,
    this.queue,
  });

  final bool inQueue;

  /// `appointment_not_today` → show the appointment card, not the queue.
  /// `no_upcoming_appointment` → empty state.
  final String? reason;
  final QueueAppointment? appointment;
  final QueueInfo? queue;

  bool get isNotToday => reason == 'appointment_not_today';
  bool get hasNoAppointment => reason == 'no_upcoming_appointment';

  factory QueueStatus.fromJson(Map<String, dynamic> json) {
    final appt = json['appointment'];
    final q = json['queue'];
    return QueueStatus(
      inQueue: json['in_queue'] == true,
      reason: json['reason']?.toString(),
      appointment: appt is Map
          ? QueueAppointment.fromJson(Map<String, dynamic>.from(appt))
          : null,
      queue: q is Map ? QueueInfo.fromJson(Map<String, dynamic>.from(q)) : null,
    );
  }
}

class QueueAppointment {
  const QueueAppointment({
    required this.appointmentId,
    this.whenIso,
    this.status,
    this.doctorName,
    this.clinicId,
    this.clinicName,
    this.clinicPhone,
  });

  final int appointmentId;
  final String? whenIso;
  final String? status;
  final String? doctorName;
  final int? clinicId;
  final String? clinicName;
  final String? clinicPhone;

  DateTime? get when =>
      whenIso == null ? null : DateTime.tryParse(whenIso!)?.toLocal();

  static int? _asInt(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static String? _asString(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory QueueAppointment.fromJson(Map<String, dynamic> json) {
    return QueueAppointment(
      appointmentId: _asInt(json['appointment_id']) ?? 0,
      whenIso: _asString(json['when_iso']),
      status: _asString(json['status']),
      doctorName: _asString(json['doctor_name']),
      clinicId: _asInt(json['clinic_id']),
      clinicName: _asString(json['clinic_name']),
      clinicPhone: _asString(json['clinic_phone']),
    );
  }
}

class QueueInfo {
  const QueueInfo({
    this.hasToken = false,
    this.myToken,
    this.nowServing,
    this.ahead,
    this.waiting,
    this.tokenScope,
    this.checkedAt,
    this.pollSeconds = 30,
  });

  /// False for a scheduled or confirmed visit that reception has not started.
  final bool hasToken;
  final int? myToken;
  final int? nowServing;

  /// An estimate. Null until both [myToken] and [nowServing] exist, and never
  /// negative.
  final int? ahead;
  final int? waiting;
  final String? tokenScope;
  final String? checkedAt;

  /// Server's polling hint; the screen polls only while it is open.
  final int pollSeconds;

  static int? _asInt(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  factory QueueInfo.fromJson(Map<String, dynamic> json) {
    return QueueInfo(
      hasToken: json['has_token'] == true,
      myToken: _asInt(json['my_token']),
      nowServing: _asInt(json['now_serving']),
      ahead: _asInt(json['ahead']),
      waiting: _asInt(json['waiting']),
      tokenScope: json['token_scope']?.toString(),
      checkedAt: json['checked_at']?.toString(),
      pollSeconds: _asInt(json['poll_seconds']) ?? 30,
    );
  }
}
