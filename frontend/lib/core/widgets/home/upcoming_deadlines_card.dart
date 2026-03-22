import 'package:flutter/material.dart';

import '../common/empty_state_card.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../models/course.dart';
import '../../models/task.dart';
import '../../../screens/add/add_new_screen.dart' show AddType;
import 'task_list_item.dart';

/// A card widget that displays upcoming deadlines or an empty state.
class UpcomingDeadlinesCard extends StatefulWidget {
  const UpcomingDeadlinesCard({
    super.key,
    required this.tasks,
    this.courses,
  });

  final List<Task> tasks;
  final List<Course>? courses;

  @override
  State<UpcomingDeadlinesCard> createState() => _UpcomingDeadlinesCardState();
}

class _UpcomingDeadlinesCardState extends State<UpcomingDeadlinesCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (widget.tasks.isEmpty) {
      return EmptyStateCard(
        icon: Icons.task_alt,
        title: 'Upcoming Deadlines',
        subtitle: 'No upcoming tasks. You are all caught up!',
        buttonText: 'Add task',
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addNew,
            arguments: AddType.task,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Deadlines',
                  style: textTheme.titleLarge,
                ),
                if (widget.tasks.length > 5)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isExpanded ? 'Show Less' : 'View All',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            Builder(
              builder: (context) {
                final taskList = _isExpanded
                    ? widget.tasks
                    : widget.tasks.take(5).toList();
                return Column(
                  children: [
                    for (var i = 0; i < taskList.length; i++) ...[
                      TaskListItem(
                        task: taskList[i],
                        textTheme: textTheme,
                        courses: widget.courses,
                      ),
                      if (i < taskList.length - 1) ...[
                        const SizedBox(height: 16),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 0,
                          endIndent: 0,
                          color: Color(0xFFE5E5E5),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
