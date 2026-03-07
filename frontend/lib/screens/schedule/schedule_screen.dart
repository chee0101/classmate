import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/class_type.dart';
import '../../core/models/course.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/course_store.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/animated_segmented_switch.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? _selectedSessionId;
  String? _selectedTermId;
  bool _showMonthly = false;
  DateTime _monthCursor = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _weekCursor = _startOfWeek(DateTime.now());

  static const List<String> _weekdayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder<List<AcademicSession>>(
        valueListenable: academicSessionsNotifier,
        builder: (context, sessionsList, _) {
          final activeSession = currentAcademicSessionNotifier.value;
          final sessions = <AcademicSession>[...sessionsList];
          if (activeSession != null &&
              !sessions.any((s) => s.id == activeSession.id)) {
            sessions.add(activeSession);
          }

          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyStateCard(
                  onPressed: () {
                    AcademicSessionSetupBottomSheet.show(context);
                  },
                ),
              ),
            );
          }

          final refs = <({AcademicSession session, TermWindow term})>[];
          for (final session in sessions) {
            for (final term in buildTermWindows(session)) {
              refs.add((session: session, term: term));
            }
          }

          var selectedRef = refs.first;
          final now = DateTime.now();
          final current = refs.where(
            (ref) =>
                !now.isBefore(ref.term.start) && !now.isAfter(ref.term.end),
          );
          if (current.isNotEmpty) selectedRef = current.first;

          final selectedSessionId = _selectedSessionId ?? selectedRef.session.id;
          final selectedTermId = _selectedTermId ?? selectedRef.term.id;
          final exact = refs.where(
            (ref) =>
                ref.session.id == selectedSessionId &&
                ref.term.id == selectedTermId,
          );
          if (exact.isNotEmpty) selectedRef = exact.first;

          final selectedSession = selectedRef.session;
          final selectedTerm = selectedRef.term;

          return ValueListenableBuilder<List<TimetableEntry>>(
            valueListenable: timetablesNotifier,
            builder: (context, entries, _) {
              return ValueListenableBuilder<List<Course>>(
                valueListenable: coursesNotifier,
                builder: (context, courses, _) {
                  final filteredEntries = entries
                      .where(
                        (e) =>
                            e.sessionId == selectedSession.id &&
                            e.termId == selectedTerm.id,
                      )
                      .toList(growable: false);

                  final courseColorByCode = <String, Color>{
                    for (final c in courses.where(
                      (c) =>
                          c.sessionId == selectedSession.id &&
                          c.termId == selectedTerm.id,
                    ))
                      c.courseCode: _parseHexColor(c.courseColor),
                  };

                  final classSlots =
                      _flattenSlots(filteredEntries, courseColorByCode);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: SessionHeader(
                          sessions: sessions,
                          selectedSessionId: selectedSession.id,
                          selectedTermId: selectedTerm.id,
                          onSelectionChanged: (sessionId, termId) {
                            setState(() {
                              _selectedSessionId = sessionId;
                              _selectedTermId = termId;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _ScheduleModeToggle(
                          showMonthly: _showMonthly,
                          onChanged: (monthly) {
                            setState(() => _showMonthly = monthly);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: _showMonthly
                            ? _MonthlyScheduleView(
                                monthCursor: _monthCursor,
                                onMonthChanged: (month) {
                                  setState(() => _monthCursor = month);
                                },
                                term: selectedTerm,
                                classSlots: classSlots,
                              )
                            : _WeeklyScheduleView(
                                classSlots: classSlots,
                                weekStart: _weekCursor,
                                onWeekChanged: (nextWeekStart) {
                                  setState(() => _weekCursor = nextWeekStart);
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<_RenderedClassSlot> _flattenSlots(
    List<TimetableEntry> entries,
    Map<String, Color> courseColorByCode,
  ) {
    final output = <_RenderedClassSlot>[];
    for (final entry in entries) {
      final color = courseColorByCode[entry.courseCode] ?? const Color(0xFF6C4DD9);
      for (final slot in entry.slots) {
        final dayIndex = _weekdayKeys.indexOf(slot.day.toLowerCase());
        if (dayIndex == -1) continue;
        final start = _parseMinutes(slot.startTime);
        final end = _parseMinutes(slot.endTime);
        if (start == null || end == null || end <= start) continue;
        output.add(
          _RenderedClassSlot(
            courseCode: entry.courseCode,
            dayIndex: dayIndex,
            startMinutes: start,
            endMinutes: end,
            color: color,
            classType: slot.classType,
          ),
        );
      }
    }
    return output;
  }

  int? _parseMinutes(String value) {
    final regex =
        RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = regex.firstMatch(value.trim());
    if (match == null) return null;
    final hour12 = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final period = (match.group(3) ?? '').toUpperCase();
    if (hour12 == null || minute == null) return null;
    final hour24 = period == 'AM' ? hour12 % 12 : (hour12 % 12) + 12;
    return hour24 * 60 + minute;
  }

  Color _parseHexColor(String colorHex) {
    final parsed = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
    return Color(parsed ?? 0xFF6C4DD9);
  }

  static DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }
}

class _ScheduleModeToggle extends StatelessWidget {
  const _ScheduleModeToggle({
    required this.showMonthly,
    required this.onChanged,
  });

  final bool showMonthly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSegmentedSwitch<bool>(
      value: showMonthly,
      onChanged: onChanged,
      options: const [
        SegmentedSwitchOption<bool>(value: false, label: 'Weekly'),
        SegmentedSwitchOption<bool>(value: true, label: 'Monthly'),
      ],
    );
  }
}

class _WeeklyScheduleView extends StatelessWidget {
  const _WeeklyScheduleView({
    required this.classSlots,
    required this.weekStart,
    required this.onWeekChanged,
  });

  final List<_RenderedClassSlot> classSlots;
  final DateTime weekStart;
  final ValueChanged<DateTime> onWeekChanged;

  static const _startHour = 0;
  static const _endHour = 23;
  static const _rowHeight = 64.0;
  static const _timeColumnWidth = 40.0;
  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String _hourLabel(int hour24) {
    final normalized = hour24 % 24;
    if (normalized == 0) return '';
    final hour12 = normalized % 12 == 0 ? 12 : normalized % 12;
    final suffix = normalized >= 12 ? 'PM' : 'AM';
    return '$hour12 $suffix';
  }

  @override
  Widget build(BuildContext context) {
    const totalHeight = (_endHour - _startHour + 1) * _rowHeight;
    final weekDates = List.generate(
      7,
      (idx) => weekStart.add(Duration(days: idx)),
      growable: false,
    );
    final today = DateTime.now();
    final focusDate = weekStart.add(const Duration(days: 3));
    final monthYearLabel = '${_monthLabel(focusDate.month)} ${focusDate.year}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    onWeekChanged(weekStart.subtract(const Duration(days: 7))),
              ),
              Expanded(
                child: Text(
                  monthYearLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    onWeekChanged(weekStart.add(const Duration(days: 7))),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              const SizedBox(width: _timeColumnWidth),
              ...List.generate(
                _dayLabels.length,
                (i) => Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          _dayLabels[i],
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (weekDates[i].year == today.year &&
                                    weekDates[i].month == today.month &&
                                    weekDates[i].day == today.day)
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${weekDates[i].day}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final vx = details.primaryVelocity ?? 0;
              if (vx.abs() < 80) return;
              if (vx < 0) {
                onWeekChanged(weekStart.add(const Duration(days: 7)));
              } else {
                onWeekChanged(weekStart.subtract(const Duration(days: 7)));
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                height: totalHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dayWidth =
                        (constraints.maxWidth - _timeColumnWidth) / _dayLabels.length;
                    return Stack(
                      children: [
                        for (int hour = _startHour; hour <= _endHour; hour++)
                          for (int day = 0; day < _dayLabels.length; day++)
                            Positioned(
                              top: (hour - _startHour) * _rowHeight,
                              left: _timeColumnWidth + (day * dayWidth),
                              width: dayWidth,
                              height: _rowHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        for (int hour = _startHour; hour <= _endHour; hour++)
                          Positioned(
                            top: (hour - _startHour) * _rowHeight,
                            left: 0,
                            right: 0,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: _timeColumnWidth,
                                  child: Text(
                                    _hourLabel(hour),
                                    style:
                                        Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey.shade500,
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...classSlots.map((slot) {
                          final top =
                              ((slot.startMinutes - (_startHour * 60)) / 60) * _rowHeight;
                          final height = (((slot.endMinutes - slot.startMinutes) / 60) *
                                  _rowHeight)
                              .clamp(24.0, 240.0);
                          return Positioned(
                            left: _timeColumnWidth + (slot.dayIndex * dayWidth) + 4,
                            top: top,
                            width: dayWidth - 8,
                            height: height,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: slot.color.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${slot.courseCode}\n${slot.classType.label}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: slot.color,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
}

class _MonthlyScheduleView extends StatelessWidget {
  const _MonthlyScheduleView({
    required this.monthCursor,
    required this.onMonthChanged,
    required this.term,
    required this.classSlots,
  });

  final DateTime monthCursor;
  final ValueChanged<DateTime> onMonthChanged;
  final TermWindow term;
  final List<_RenderedClassSlot> classSlots;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(monthCursor.year, monthCursor.month, 1);
    final startWeekday = firstOfMonth.weekday; // Mon=1
    final gridStart = firstOfMonth.subtract(Duration(days: startWeekday - 1));
    final today = DateTime.now();
    final slotCountByWeekday = <int, int>{};
    for (final slot in classSlots) {
      slotCountByWeekday[slot.dayIndex] =
          (slotCountByWeekday[slot.dayIndex] ?? 0) + 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  onMonthChanged(DateTime(monthCursor.year, monthCursor.month - 1, 1));
                },
              ),
              Expanded(
                child: Text(
                  '${_monthLabel(monthCursor.month)} ${monthCursor.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  onMonthChanged(DateTime(monthCursor.year, monthCursor.month + 1, 1));
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: _dayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: List.generate(6, (weekIdx) {
                final weekStart = gridStart.add(Duration(days: weekIdx * 7));
                final weekEnd = weekStart.add(const Duration(days: 6));
                final overlapsTerm =
                    !weekEnd.isBefore(term.start) && !weekStart.isAfter(term.end);
                final weekNo = ((weekStart.difference(term.start).inDays) ~/ 7) + 1;
                return Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(7, (dayIdx) {
                            final date = weekStart.add(Duration(days: dayIdx));
                            final inMonth = date.month == monthCursor.month;
                            final isToday = date.year == today.year &&
                                date.month == today.month &&
                                date.day == today.day;
                            final count = slotCountByWeekday[dayIdx] ?? 0;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(0.5),
                                padding: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color:
                                      inMonth ? Colors.white : const Color(0xFFEAF3FA),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.2)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${date.day}',
                                        style:
                                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Colors.grey.shade700,
                                                ),
                                      ),
                                    ),
                                    if (count > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      if (overlapsTerm)
                        Container(
                          height: 16,
                          margin: const EdgeInsets.only(top: 2, bottom: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Week ${weekNo < 1 ? 1 : weekNo}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

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
}

class _RenderedClassSlot {
  const _RenderedClassSlot({
    required this.courseCode,
    required this.dayIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.color,
    required this.classType,
  });

  final String courseCode;
  final int dayIndex;
  final int startMinutes;
  final int endMinutes;
  final Color color;
  final ClassType classType;
}

