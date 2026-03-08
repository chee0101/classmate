import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../models/academic_event.dart';
import '../../utils/date_time_format.dart';
import '../../../screens/add/add_new_screen.dart' show AddType;
import '../common/empty_state_card.dart';

class UpcomingEventsCard extends StatelessWidget {
  const UpcomingEventsCard({
    super.key,
    required this.events,
  });

  final List<AcademicEvent> events;

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
      return '${formatDateDdMmYyyy(startDay)} - ${formatDateDdMmYyyy(endDay)}';
    }
    if (sameDay) {
      return '${formatRelativeDueDate(startDay)}, ${formatTime12h(event.startDateTime)} - ${formatTime12h(event.endDateTime)}';
    }
    return '${formatDateDdMmYyyy(startDay)} ${formatTime12h(event.startDateTime)} - ${formatDateDdMmYyyy(endDay)} ${formatTime12h(event.endDateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = events.take(5).toList(growable: false);

    if (events.isEmpty) {
      return EmptyStateCard(
        icon: Icons.event_available,
        title: 'Upcoming Events',
        subtitle: 'No upcoming events yet.',
        buttonText: 'Add event',
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addNew,
            arguments: AddType.event,
          );
        },
      );
    }

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
            Text(
              'Upcoming Events',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...preview.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.event, size: 20),
                    title: Text(
                      event.title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _eventSubtitle(event),
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (i < preview.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE5E5E5),
                    ),
                ],
              );
            }),
            if (events.length > preview.length) ...[
              const SizedBox(height: 6),
              Text(
                '+${events.length - preview.length} more events',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

