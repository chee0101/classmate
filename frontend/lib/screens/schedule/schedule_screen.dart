import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/mock/mock_academic_session.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: currentAcademicSessionNotifier,
        builder: (context, session, _) {
          if (session == null) {
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

          return const Center(child: Text('Your Main App Content'));
        },
      ),
    );
  }
}
