import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/mock/mock_academic_session.dart';
import '../../core/mock/mock_tasks.dart';
import '../../core/utils/task_utils.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';
import '../../core/widgets/home/today_classes_card.dart';
import '../../core/widgets/home/upcoming_deadlines_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedTermId;

  @override
  void initState() {
    super.initState();
    final active = currentAcademicSessionNotifier.value;
    if (active != null) {
      final windows = buildTermWindows(active);
      _selectedTermId = defaultTermId(windows);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
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

          final termWindows = buildTermWindows(session);
          final selectedTerm = termWindows.firstWhere(
            (t) =>
                t.id ==
                (_selectedTermId != null &&
                        termWindows.any((w) => w.id == _selectedTermId)
                    ? _selectedTermId
                    : defaultTermId(termWindows)),
            orElse: () => termWindows.first,
          );

          final upcomingTasks = TaskUtils.getUpcomingTasks(mockTopLevelTasks());

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.lg,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                ),
                child: SessionHeader(
                  sessionName: session.name,
                  termWindows: termWindows,
                  selectedTerm: selectedTerm,
                  onTermChanged: (id) {
                    setState(() => _selectedTermId = id);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TodayClassesCard(hasClasses: false),
                      const SizedBox(height: AppSpacing.lg),
                      UpcomingDeadlinesCard(tasks: upcomingTasks),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}