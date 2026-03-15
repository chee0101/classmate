enum ClassSlotOverrideAction { edit, cancel }

class ClassSlotOverride {
  const ClassSlotOverride({
    required this.id,
    required this.classSlotId,
    required this.occurrenceDate,
    required this.action,
    this.overrideDate,
    this.overrideStartMinutes,
    this.overrideEndMinutes,
    this.overrideMode,
    this.overrideVenue,
  });

  final String id;
  final String classSlotId;
  final DateTime occurrenceDate;
  final ClassSlotOverrideAction action;
  final DateTime? overrideDate;
  final int? overrideStartMinutes;
  final int? overrideEndMinutes;
  final String? overrideMode;
  final String? overrideVenue;

  String get occurrenceKey => buildClassSlotOccurrenceKey(
        classSlotId: classSlotId,
        occurrenceDate: occurrenceDate,
      );

  static String buildClassSlotOccurrenceKey({
    required String classSlotId,
    required DateTime occurrenceDate,
  }) {
    final date = _normalizeDate(occurrenceDate);
    return '${classSlotId.trim()}::${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  static String buildClassSlotOverrideId({
    required String classSlotId,
    required DateTime occurrenceDate,
  }) {
    final base = buildClassSlotOccurrenceKey(
      classSlotId: classSlotId,
      occurrenceDate: occurrenceDate,
    );
    return base.replaceAll(RegExp(r'[^A-Za-z0-9:_-]'), '_');
  }

  static DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
