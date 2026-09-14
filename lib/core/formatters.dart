/// Small date/duration helpers — avoids pulling in `intl` for three strings.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDateTime(DateTime value) {
  final d = value.toLocal();
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} '
      '${d.year}, ${_two(d.hour)}:${_two(d.minute)}';
}

String formatRelative(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDateTime(value);
}

String formatDuration(Duration value) =>
    '${(value.inMilliseconds / 1000).toStringAsFixed(2)} s';

String _two(int v) => v.toString().padLeft(2, '0');
