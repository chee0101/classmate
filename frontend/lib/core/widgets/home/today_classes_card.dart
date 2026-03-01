import 'package:flutter/material.dart';

import '../common/empty_state_card.dart';
import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../../screens/add/add_new_screen.dart' show AddType;

/// A card widget that displays today's classes or an empty state.
class TodayClassesCard extends StatelessWidget {
  const TodayClassesCard({
    super.key,
    this.hasClasses = false,
  });

  final bool hasClasses;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!hasClasses) {
      return EmptyStateCard(
        icon: Icons.event_busy,
        title: "Today's Classes",
        subtitle: 'No timetable added yet.',
        buttonText: 'Add class',
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addNew,
            arguments: AddType.classSlot,
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Classes",
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          // TODO: Add class list here when classes are available
        ],
      ),
    );
  }
}
