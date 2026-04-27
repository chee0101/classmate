import 'package:flutter/material.dart';

import '../../../screens/add/add_new_screen.dart' show AddType;
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../models/academic_event.dart';
import '../../models/course.dart';
import '../../models/task.dart';
import '../../utils/course_display.dart';
import '../../utils/date_time_format.dart';
import '../../utils/term_windows.dart';
import '../common/label_chip.dart';

enum UpcomingFilter { all, deadlines, events }

class UnifiedUpcomingCard extends StatefulWidget {
  const UnifiedUpcomingCard({
    super.key,
    required this.tasks,
    required this.events,
    required this.selectedTerm,
    this.courses,
  });

  final List<Task> tasks;
  final List<AcademicEvent> events;
  final TermWindow selectedTerm;
  final List<Course>? courses;

  @override
  State<UnifiedUpcomingCard> createState() => _UnifiedUpcomingCardState();
}

class _UnifiedUpcomingCardState extends State<UnifiedUpcomingCard> {
  UpcomingFilter _filter = UpcomingFilter.all;
  bool _expanded = false;

  String _filterLabel(UpcomingFilter filter) {
    switch (filter) {
      case UpcomingFilter.all:
        return 'All';
      case UpcomingFilter.deadlines:
        return 'Deadlines';
      case UpcomingFilter.events:
        return 'Events';
    }
  }

  String _eventSubtitle(AcademicEvent event) {
    final startDay = DateTime(
      event.startDateTime.year,
      event.startDateTime.month,
      event.startDateTime.day,
    );
    final endDay = DateTime(
      event.endDateTime.year,
      event.endDateTime.month,
      event.endDateTime.day,
    );
    final sameDay =
        startDay.year == endDay.year &&
        startDay.month == endDay.month &&
        startDay.day == endDay.day;

    if (event.allDay) {
      if (sameDay) return '${formatRelativeDueDate(startDay)} (All day)';
      return formatDateRangeDdMmYyyy(startDay, endDay);
    }
    if (sameDay) {
      return '${formatRelativeDueDate(startDay)}, ${formatTimeRange12h(event.startDateTime, event.endDateTime)}';
    }
    return formatDateTimeRangeDdMmYyyy(
      event.startDateTime,
      event.endDateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final allItems = <_UpcomingEntry>[
      ...widget.tasks.map((t) => _UpcomingEntry.task(t)),
      ...widget.events.map((e) => _UpcomingEntry.event(e)),
    ]..sort((a, b) => a.sortDateTime.compareTo(b.sortDateTime));

    final filteredItems = switch (_filter) {
      UpcomingFilter.all => allItems,
      UpcomingFilter.deadlines => widget.tasks.map(_UpcomingEntry.task).toList()
        ..sort((a, b) => a.sortDateTime.compareTo(b.sortDateTime)),
      UpcomingFilter.events => widget.events.map(_UpcomingEntry.event).toList()
        ..sort((a, b) => a.sortDateTime.compareTo(b.sortDateTime)),
    };

    final hasMany = filteredItems.length > 5;
    final visibleItems =
        !_expanded && hasMany ? filteredItems.take(5).toList() : filteredItems;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Upcoming',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_filterLabel(_filter)})',
                        style: textTheme.bodyMedium?.copyWith(
                          color: appPrimarySwatch.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<UpcomingFilter>(
                  tooltip: 'Filter upcoming',
                  iconColor: appPrimarySwatch.shade700,
                  onSelected: (value) {
                    setState(() {
                      _filter = value;
                      _expanded = false;
                    });
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: UpcomingFilter.all,
                      child: Text('All'),
                    ),
                    PopupMenuItem(
                      value: UpcomingFilter.deadlines,
                      child: Text('Deadlines'),
                    ),
                    PopupMenuItem(
                      value: UpcomingFilter.events,
                      child: Text('Events'),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.filter_list),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (visibleItems.isEmpty)
              _EmptyUpcomingState(
                filter: _filter,
              )
            else
              ...visibleItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    if (item.task != null)
                      _TaskRow(
                        task: item.task!,
                        textTheme: textTheme,
                        courses: widget.courses,
                      )
                    else
                      _EventRow(
                        event: item.event!,
                        textTheme: textTheme,
                        subtitle: _eventSubtitle(item.event!),
                      ),
                    if (index < visibleItems.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE5E5E5),
                      ),
                  ],
                );
              }),
            if (hasMany && !_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = true),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'View all (+${filteredItems.length - 5} more)',
                      style: textTheme.bodySmall?.copyWith(
                        color: appPrimarySwatch.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            if (hasMany && _expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Show less',
                      style: textTheme.bodySmall?.copyWith(
                        color: appPrimarySwatch.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingEntry {
  const _UpcomingEntry._({
    required this.sortDateTime,
    this.task,
    this.event,
  });

  final DateTime sortDateTime;
  final Task? task;
  final AcademicEvent? event;

  factory _UpcomingEntry.task(Task task) {
    return _UpcomingEntry._(
      sortDateTime: task.dueDateTime,
      task: task,
    );
  }

  factory _UpcomingEntry.event(AcademicEvent event) {
    return _UpcomingEntry._(
      sortDateTime: event.startDateTime,
      event: event,
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.textTheme,
    this.courses,
  });

  final Task task;
  final TextTheme textTheme;
  final List<Course>? courses;

  @override
  Widget build(BuildContext context) {
    final label = courses == null
        ? task.courseCode
        : displayCourseCodeForTask(task, courses!);
    final color = courses == null
        ? task.courseColor
        : displayCourseColorForTask(task, courses!);

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.taskDetail,
          arguments: task,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    Icons.task_alt_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelChip(
                    label: label,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: appPrimarySwatch.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${formatRelativeDueDate(task.dueDateTime)}, ${formatTime12h(task.dueDateTime)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: appPrimarySwatch.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.textTheme,
    required this.subtitle,
  });

  final AcademicEvent event;
  final TextTheme textTheme;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: Icon(Icons.event, size: 20, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: appPrimarySwatch.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUpcomingState extends StatelessWidget {
  const _EmptyUpcomingState({
    required this.filter,
  });

  final UpcomingFilter filter;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;
    String subtitle;
    String buttonText;
    AddType addType;

    switch (filter) {
      case UpcomingFilter.all:
        icon = Icons.event_available;
        title = 'No upcoming items';
        subtitle = 'Add a task or event to get started.';
        buttonText = 'Add task';
        addType = AddType.task;
        break;
      case UpcomingFilter.deadlines:
        icon = Icons.task_alt;
        title = 'No upcoming deadlines';
        subtitle = 'You are all caught up!';
        buttonText = 'Add task';
        addType = AddType.task;
        break;
      case UpcomingFilter.events:
        icon = Icons.event_available;
        title = 'No upcoming events';
        subtitle = 'Add an event to your schedule.';
        buttonText = 'Add event';
        addType = AddType.event;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 28, color: Colors.grey.shade600),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.addNew,
                arguments: addType,
              );
            },
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
