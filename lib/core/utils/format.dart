String _two(int n) => n.toString().padLeft(2, '0');

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 01:42:07 - used by the live task timers.
String formatElapsed(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${_two(s ~/ 3600)}:${_two((s % 3600) ~/ 60)}:${_two(s % 60)}';
}

/// 2h 14m, 14m 09s, 42s - used for total durations in History.
String formatDuration(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return '${h}h ${_two(m)}m';
  if (m > 0) return '${m}m ${_two(s % 60)}s';
  return '${s}s';
}

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String formatDateTime(DateTime? d) =>
    d == null ? '-' : '${formatDate(d)} · ${formatTime(d)}';

/// "Today · 8:16 AM", "Yesterday · 5:02 PM" or the full date.
String formatFriendly(DateTime? d) {
  if (d == null) return '-';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today · ${formatTime(d)}';
  if (diff == 1) return 'Yesterday · ${formatTime(d)}';
  if (diff == -1) return 'Tomorrow · ${formatTime(d)}';
  return formatDateTime(d);
}
