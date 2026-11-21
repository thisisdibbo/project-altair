/// "Today", "Tomorrow", "23 days left" or "3 days ago".
String countdownLabel(int days) {
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days > 1) return '$days days left';
  if (days == -1) return 'Yesterday';
  return '${-days} days ago';
}
