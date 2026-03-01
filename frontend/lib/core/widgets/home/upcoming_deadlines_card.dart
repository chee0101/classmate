import 'package:flutter/material.dart';

import '../common/empty_state_card.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../models/task.dart';
import '../../../screens/add/add_new_screen.dart' show AddType;
import 'task_list_item.dart';

/// A card widget that displays upcoming deadlines or an empty state.
class UpcomingDeadlinesCard extends StatelessWidget {
  const UpcomingDeadlinesCard({
    super.key,
    required this.tasks,
  });

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (tasks.isEmpty) {
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
            Text(
              'Upcoming Deadlines',
              style: textTheme.titleLarge,
            ),
            Builder(
              builder: (context) {
                final taskList = tasks.take(3).toList();
                return Column(
                  children: [
                    for (var i = 0; i < taskList.length; i++) ...[
                      TaskListItem(
                        task: taskList[i],
                        textTheme: textTheme,
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
