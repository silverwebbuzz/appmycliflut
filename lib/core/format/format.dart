/// Display formatting shared across features.
///
/// Hand-rolled rather than pulling in `intl`: the app only needs rupees and a
/// couple of date shapes, always in Indian conventions.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Integer paise → "₹1,299" or "₹12.50", as the website prints it.
///
/// Whole rupees drop the `.00`. Grouping is Indian (1,23,456). The store
/// sends every amount in paise and the app never computes a total itself,
/// so this is formatting only.
String formatPaise(int paise) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final rem = abs % 100;
  final whole = _groupIndian(rupees);
  final body = rem == 0 ? whole : '$whole.${rem.toString().padLeft(2, '0')}';
  return '${negative ? '−' : ''}₹$body';
}

String _groupIndian(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// Parses the server's `YYYY-MM-DD` or `YYYY-MM-DD HH:MM:SS` (IST, no zone)
/// as a local wall-clock time.
DateTime? parseServerDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
}

/// "12 Aug 2026".
String formatDate(String? raw) {
  final d = parseServerDate(raw);
  if (d == null) return raw ?? '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "12 Aug 2026, 5:40 PM".
String formatDateTime(String? raw) {
  final d = parseServerDate(raw);
  if (d == null) return raw ?? '';
  return '${formatDate(raw)}, ${formatTime(d)}';
}

/// "5:40 PM".
String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// `YYYY-MM-DD` for API date fields.
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
