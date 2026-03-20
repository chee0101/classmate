/// Day boundary helpers used for consistent event filtering.
///
/// Uses inclusive end-of-day semantics (23:59:59.999).
DateTime startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 0, 0, 0, 0);

DateTime endOfDayInclusive(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

