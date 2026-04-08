import '../constants/months.dart';
import '../constants/weekdays.dart';

/// Returns a human-friendly relative date like
/// "Today", "Tomorrow", "2 days ago", or "5 Mar".
String formatRelativeDueDate(DateTime dt) {
  final now = DateTime.now();
  // Compare calendar days (midnight-to-midnight) instead of raw duration.
  // This avoids edge cases like tasks at 11:59 PM showing as "Today"
  // right after midnight due to `Duration.inDays` truncation.
  final todayMidnight = DateTime(now.year, now.month, now.day);
  final dtMidnight = DateTime(dt.year, dt.month, dt.day);
  final dayDiff = dtMidnight.difference(todayMidnight).inDays;

  if (dayDiff == 0) {
    return 'Today';
  } else if (dayDiff == 1) {
    return 'Tomorrow';
  } else if (dayDiff < 0) {
    final daysAgo = -dayDiff;
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

/// Formats a time range like "9:00 AM – 10:00 AM".
String formatTimeRange12h(
  DateTime start,
  DateTime end, {
  String separator = ' – ',
}) {
  return '${formatTime12h(start)}$separator${formatTime12h(end)}';
}

/// Formats weekday + time range, e.g. "Thursday • 9:00 AM – 10:00 AM".
String formatWeekdayTimeRange(
  DateTime start,
  DateTime end, {
  String dayTimeSeparator = ' ',
  String timeRangeSeparator = ' – ',
}) {
  final dayLabel = weekdayNamesMondayFirst[start.weekday - 1];
  final timeLabel = formatTimeRange12h(start, end, separator: timeRangeSeparator);
  return '$dayLabel$dayTimeSeparator$timeLabel';
}

/// Formats a DateTime as DD/MM/YYYY (e.g., 26/02/2026).
String formatDateDdMmYyyy(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${dt.year}';

/// Formats a date range as DD/MM/YYYY – DD/MM/YYYY.
String formatDateRangeDdMmYyyy(
  DateTime start,
  DateTime end, {
  String separator = ' – ',
}) {
  return '${formatDateDdMmYyyy(start)}$separator${formatDateDdMmYyyy(end)}';
}

/// Formats a date-time range as:
/// DD/MM/YYYY h:mm AM/PM – DD/MM/YYYY h:mm AM/PM.
String formatDateTimeRangeDdMmYyyy(
  DateTime start,
  DateTime end, {
  String separator = ' – ',
}) {
  return '${formatDateDdMmYyyy(start)} ${formatTime12h(start)}$separator${formatDateDdMmYyyy(end)} ${formatTime12h(end)}';
}

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
  return '${formatDateShortWithYear(start)} – ${formatDateShortWithYear(end)} (All day)';
}

/// Formats a date-time range, using a compact same-day form.
String formatDateTimeRange(DateTime start, DateTime end) {
  if (isSameDate(start, end)) {
    return '${formatDateShortWithYear(start)} • ${formatTimeRange12h(start, end)}';
  }
  return '${formatDateShortWithYear(start)} ${formatTime12h(start)} – ${formatDateShortWithYear(end)} ${formatTime12h(end)}';
}

/// Parses a 12-hour time label like "9:30 AM" into minutes since midnight.
///
/// Returns `null` if the string is not a valid time.
int? parseTimeLabel12hToMinutes(String value) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  final hour12 = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  final period = (match.group(3) ?? '').toUpperCase();
  if (hour12 == null || minute == null) return null;
  if (hour12 < 1 || hour12 > 12 || minute < 0 || minute > 59) return null;
  final hour24 = period == 'AM' ? hour12 % 12 : (hour12 % 12) + 12;
  return (hour24 * 60) + minute;
}

/// Formats minutes since midnight as a 12-hour time like "9:30 AM".
String formatMinutes12h(int minutes) {
  final normalized = ((minutes % 1440) + 1440) % 1440;
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minuteString = minute.toString().padLeft(2, '0');
  return '$hour12:$minuteString $period';
}
