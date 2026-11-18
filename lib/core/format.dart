import 'package:intl/intl.dart';

final _num = NumberFormat.decimalPattern('en');

String etb(num? n) => 'ETB ${_num.format(n ?? 0)}';
String pts(num? n) => '${_num.format(n ?? 0)} pts';
String number(num? n) => _num.format(n ?? 0);

DateTime? parseDate(String? iso) => iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();

/// "Sun, 9 Nov"
String dayShort(String? iso) {
  final d = parseDate(iso);
  return d == null ? '—' : DateFormat('EEE, d MMM').format(d);
}

/// "9 Nov 2026"
String dayLong(String? iso) {
  final d = parseDate(iso);
  return d == null ? '—' : DateFormat('d MMM yyyy').format(d);
}

/// "Oct 2028"
String monthYear(String? iso) {
  final d = parseDate(iso);
  return d == null ? '—' : DateFormat('MMM yyyy').format(d);
}

/// "9 Nov, 14:30"
String when(String? iso) {
  final d = parseDate(iso);
  return d == null ? '—' : DateFormat('d MMM, HH:mm').format(d);
}

/// "14:30", "Yesterday", "Mon", "9 Nov" — for chat and notification lists.
String ago(String? iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return DateFormat('HH:mm').format(d);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEE').format(d);
  return DateFormat('d MMM').format(d);
}

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String firstName(String? name) => (name ?? '').trim().split(RegExp(r'\s+')).first;

String initials(String? name) {
  final parts = (name ?? '').replaceAll(RegExp(r'^(Dr\.?|Dr)\s+'), '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

String greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
}

/// Normalises an Ethiopian phone the user typed (e.g. "911 22 33 44") to what the API accepts.
String phoneForApi(String typed) {
  final digits = typed.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('251')) return '+$digits';
  if (digits.startsWith('0')) return digits;
  return '0$digits';
}
