import '../constants/months.dart';

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
    return '${dt.day} ${monthShortLabel(dt.month)}';
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

/// True when [a] and [b] are on the same calendar day.
bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Formats a DateTime as "8 Mar 2026".
String formatDateShortWithYear(DateTime dt) =>
    '${dt.day} ${monthShortLabel(dt.month)} ${dt.year}';

/// Formats date range for all-day labels.
String formatAllDayRange(DateTime start, DateTime end) {
  if (isSameDate(start, end)) {
    return '${formatDateShortWithYear(start)} (All day)';
  }
  return '${formatDateShortWithYear(start)} - ${formatDateShortWithYear(end)} (All day)';
}

/// Formats a date-time range, using a compact same-day form.
String formatDateTimeRange(DateTime start, DateTime end) {
  if (isSameDate(start, end)) {
    return '${formatDateShortWithYear(start)} • ${formatTime12h(start)} - ${formatTime12h(end)}';
  }
  return '${formatDateShortWithYear(start)} ${formatTime12h(start)} - ${formatDateShortWithYear(end)} ${formatTime12h(end)}';
}

