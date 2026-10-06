// Parses the exact JSON payloads from document/11-mobile-api-reference.md.
//
// These endpoints are not deployed yet, so this is the only check available
// that the client models match the frozen contract. When the PHP files go
// live, a mismatch here points at either the doc or the server.
import 'package:eclinicpro_patient/features/appointments/domain/appointment.dart';
import 'package:eclinicpro_patient/features/family/domain/family_member.dart';
import 'package:eclinicpro_patient/features/profile/domain/patient_profile.dart';
import 'package:eclinicpro_patient/features/queue/domain/queue_status.dart';
import 'package:eclinicpro_patient/features/records/domain/medical_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('queue.php', () {
    test('parses the documented in-queue payload', () {
      final s = QueueStatus.fromJson({
        'ok': true,
        'in_queue': true,
        'reason': null,
        'appointment': {
          'appointment_id': 41,
          'when_iso': '2026-09-23T17:40:00+05:30',
          'status': 'confirmed',
          'doctor_name': 'Dr. Arjun Shah',
          'clinic_id': 7,
          'clinic_name': 'Shah Family Clinic',
          'clinic_phone': '+91…',
        },
        'queue': {
          'has_token': true,
          'my_token': 14,
          'now_serving': 9,
          'ahead': 5,
          'waiting': 12,
          'token_scope': 'clinic_day',
          'checked_at': '2026-09-23T17:05:11+05:30',
          'poll_seconds': 30,
        },
      });

      expect(s.inQueue, isTrue);
      expect(s.appointment!.appointmentId, 41);
      expect(s.appointment!.clinicName, 'Shah Family Clinic');
      expect(s.queue!.myToken, 14);
      expect(s.queue!.nowServing, 9);
      expect(s.queue!.ahead, 5);
      expect(s.queue!.pollSeconds, 30);
    });

    test('handles a confirmed visit with no token assigned yet', () {
      // Tokens only exist once reception starts the visit.
      final s = QueueStatus.fromJson({
        'ok': true,
        'in_queue': true,
        'queue': {'has_token': false, 'my_token': null, 'now_serving': null},
      });

      expect(s.queue!.hasToken, isFalse);
      expect(s.queue!.myToken, isNull);
      expect(s.queue!.ahead, isNull);
      expect(s.queue!.pollSeconds, 30, reason: 'falls back to the hint');
    });

    test('distinguishes the two not-in-queue reasons', () {
      final notToday = QueueStatus.fromJson(
        {'ok': true, 'in_queue': false, 'reason': 'appointment_not_today'},
      );
      final none = QueueStatus.fromJson(
        {'ok': true, 'in_queue': false, 'reason': 'no_upcoming_appointment'},
      );

      expect(notToday.isNotToday, isTrue);
      expect(notToday.hasNoAppointment, isFalse);
      expect(none.hasNoAppointment, isTrue);
    });
  });

  group('prescriptions.php / lab_reports.php', () {
    test('parses the documented prescription item', () {
      final r = MedicalRecord.fromJson({
        'id': 12,
        'family_member_id': null,
        'label': 'Dr. Shah — 12 Aug — Diabetes',
        'doctor_name': 'Dr. Arjun Shah',
        'clinic_name': 'Shah Family Clinic',
        'notes': null,
        'issued_on': '2026-08-12',
        'source': 'upload',
        'is_clinic': false,
        'has_file': true,
        'file_mime': 'application/pdf',
        'is_pdf': true,
        'file_url': 'api/mobile/v1/prescriptions.php?action=file&id=12',
        'created_at': '2026-08-12 10:04:11',
      }, kind: RecordKind.prescription);

      expect(r.id, 12);
      expect(r.dateIso, '2026-08-12');
      expect(r.isPdf, isTrue);
      expect(r.isImage, isFalse);
      expect(r.subtitle, contains('Dr. Arjun Shah'));
    });

    test('reads reported_on for lab reports', () {
      final r = MedicalRecord.fromJson({
        'id': 8,
        'label': 'HbA1c — Aug 2026',
        'test_type': 'Blood',
        'lab_name': 'Thyrocare',
        'doctor_name': null,
        'reported_on': '2026-08-14',
        'source': 'upload',
        'has_file': true,
        'file_mime': 'application/pdf',
        'is_pdf': true,
        'file_url': 'api/mobile/v1/lab_reports.php?action=file&id=8',
      }, kind: RecordKind.labReport);

      expect(r.dateIso, '2026-08-14');
      expect(r.labName, 'Thyrocare');
      expect(r.subtitle, contains('Thyrocare'));
    });

    test('detects an inline-renderable image', () {
      final r = MedicalRecord.fromJson({
        'id': 3,
        'label': 'Scan',
        'has_file': true,
        'file_mime': 'image/jpeg',
        'is_pdf': false,
      }, kind: RecordKind.prescription);

      expect(r.isImage, isTrue);
    });

    test('each vault routes to its own endpoint', () {
      expect(RecordKind.prescription.endpoint, 'prescriptions.php');
      expect(RecordKind.labReport.endpoint, 'lab_reports.php');
    });
  });

  group('family.php', () {
    test('parses the documented list payload', () {
      final m = FamilyMember.fromJson({
        'id': 5,
        'name': 'Ananya Sharma',
        'initials': 'AS',
        'relation': 'self',
        'is_self': true,
        'dob': '1997-03-02',
        'age': 29,
        'gender': 'F',
        'blood_group': 'B+',
        'abha_id': null,
      });

      expect(m.isSelf, isTrue);
      expect(m.age, 29);
      expect(m.subtitle, 'You · 29');
    });

    test('maps husband and wife onto the DB enum spouse', () {
      // The design shows Husband/Wife chips; the DB only has `spouse`.
      const allowed = [
        'spouse',
        'mother',
        'father',
        'son',
        'daughter',
        'guardian',
        'other',
      ];

      expect(FamilyRelations.toApiValue('Husband', allowed), 'spouse');
      expect(FamilyRelations.toApiValue('Wife', allowed), 'spouse');
      expect(FamilyRelations.toApiValue('Mother', allowed), 'mother');
    });

    test('falls back to other for an unknown relation', () {
      const allowed = ['spouse', 'mother', 'other'];
      expect(FamilyRelations.toApiValue('Nephew', allowed), 'other');
    });

    test('reads options rather than hardcoding them', () {
      final o = FamilyOptions.fromJson({
        'relations': ['spouse', 'mother', 'other'],
        'genders': ['M', 'F', 'Other'],
        'blood_groups': ['A+', 'O-'],
      });

      expect(o.relations, contains('spouse'));
      expect(o.relations, isNot(contains('husband')));
      expect(o.bloodGroups, hasLength(2));
    });
  });

  group('profile.php', () {
    test('surfaces phone as read-only in v1', () {
      final p = PatientProfile.fromJson({
        'name': 'Ananya Sharma',
        'phone': '+919876543210',
        'phone_verified': true,
        'phone_editable': false,
        'has_photo': true,
        'photo_url': 'api/mobile/v1/profile.php?action=photo',
        'photo_tag': 'v3',
        'age': 29,
      });

      expect(p.phoneEditable, isFalse);
      expect(p.phoneVerified, isTrue);
      expect(p.photoTag, 'v3', reason: 'cache-buster for a replaced avatar');
    });

    test('wa_opt_in defaults to on and reads false', () {
      expect(PatientProfile.fromJson({'name': 'A'}).waOptIn, isTrue);
      expect(PatientProfile.fromJson({'name': 'A', 'wa_opt_in': false}).waOptIn, isFalse);
    });

    test('treats blank strings as absent', () {
      final p = PatientProfile.fromJson({'name': 'A', 'email': '   '});
      expect(p.email, isNull);
    });

    // The save whitelist (ecp_profile_map_fields) drops unknown keys
    // silently, so the model must read the real DB column names.
    test('reads the DB column names for address and emergency contact', () {
      final p = PatientProfile.fromJson({
        'name': 'A',
        'address_line1': '12 MG Road',
        'address_city': 'Ahmedabad',
        'address_state': 'Gujarat',
        'address_postal_code': '380009',
        'emergency_contact_name': 'Ravi',
        'emergency_contact_phone': '9876543210',
        'chronic_conditions': 'Asthma',
        'dob': '0000-00-00',
      });
      expect(p.city, 'Ahmedabad');
      expect(p.pincode, '380009');
      expect(p.emergencyName, 'Ravi');
      expect(p.chronicConditions, 'Asthma');
      expect(p.dob, isNull, reason: 'a zero date means unset');
    });
  });

  group('appointments.php', () {
    test('parses the list with leads under pending_leads', () {
      final l = AppointmentList.fromJson({
        'ok': true,
        'upcoming': [
          {
            'kind': 'appointment',
            'id': 41,
            'when_date': 'Fri, 3 Oct 2026',
            'when_time': '5:40 PM',
            'status': 'confirmed',
            'token_number': null,
            'doctor_name': 'Dr. Arjun Shah',
            'clinic_name': 'Shah Family Clinic',
          },
        ],
        'past': [],
        'pending_leads': [
          {'kind': 'lead', 'id': 9, 'status': 'awaiting_clinic', 'clinic_name': 'X'},
        ],
      });
      expect(l.upcoming.single.whenLabel, 'Fri, 3 Oct 2026 · 5:40 PM');
      expect(l.upcoming.single.initials, 'AS');
      expect(l.upcoming.single.tokenNumber, isNull);
      expect(l.pending.single.isLead, isTrue);
      expect(l.pending.single.statusLabel, 'Request sent');
    });
  });
}
