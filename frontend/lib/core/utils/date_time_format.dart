/// Returns a human-friendly relative date like
/// "Today", "Tomorrow", "2 days ago", or "5 Mar".
String formatRelativeDueDate(DateTime dt) {
  final now = DateTime.now();
  final difference = dt.difference(
    DateTime(now.year, now.month, now.day),
  );

  if (difference.inDays == 0) {
    return 'Today';
  } else if (difference.inDays == 1) {
    return 'Tomorrow';
  } else if (difference.inDays < 0) {
    final daysAgo = -difference.inDays;
    return daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago';
  } else {
    return '${dt.day} ${_monthLabel(dt.month)}';
  }
}

/// Formats a DateTime as a 12-hour time like "2:40 PM".
String formatTime12h(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

/// Formats a DateTime as DD/MM/YYYY (e.g., 26/02/2026).
String formatDateDdMmYyyy(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${dt.year}';

String _monthLabel(int month) {
  const months = [
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
  return months[month - 1];
}

