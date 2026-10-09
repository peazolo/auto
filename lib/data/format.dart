import 'package:intl/intl.dart';

final _date = DateFormat('d MMM yyyy');
final _num = NumberFormat.decimalPattern();

String fmtDate(DateTime? d) => d == null ? '—' : _date.format(d);
String fmtNum(num? n) => n == null ? '—' : _num.format(n);

String fmtMoney(num? n, String currency) {
  if (n == null) return '—';
  try {
    return NumberFormat.simpleCurrency(name: currency).format(n);
  } catch (_) {
    return '$currency ${n.toStringAsFixed(2)}';
  }
}

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

int daysUntil(DateTime d) => DateTime(d.year, d.month, d.day).difference(today()).inDays;

String relativeDays(DateTime d) {
  final n = daysUntil(d);
  if (n == 0) return 'today';
  if (n == 1) return 'tomorrow';
  if (n == -1) return 'yesterday';
  return n > 0 ? 'in $n days' : '${-n} days ago';
}

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  return fmtDate(d);
}

/// yyyy-MM-dd for Postgres date columns.
String? isoDate(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);
DateTime? parseDate(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
