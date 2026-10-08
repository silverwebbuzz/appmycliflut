// Date display must match the server's App\Support\IndianDate.
import 'package:eclinicpro_patient/core/format/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dates: two-digit day, always with the year', () {
    expect(formatDate('2026-10-06'), '06 Oct 2026');
    expect(formatDate('2026-12-25 09:05:00'), '25 Dec 2026');
  });

  test('date-times and times: two-digit hour, AM/PM', () {
    expect(formatDateTime('2026-10-06 15:45:00'), '06 Oct 2026, 03:45 PM');
    expect(formatDateTime('2026-10-06 00:07:00'), '06 Oct 2026, 12:07 AM');
    expect(formatTime(DateTime(2026, 1, 1, 12, 30)), '12:30 PM');
  });

  test('missing, zero or unreadable dates show a dash', () {
    for (final v in [null, '', '0000-00-00', '0000-00-00 00:00:00', 'soon']) {
      expect(formatDate(v), '—');
      expect(formatDateTime(v), '—');
    }
  });
}
