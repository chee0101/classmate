import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/models/course.dart';
import '../../core/mock/mock_academic_session.dart';
import '../../core/mock/mock_courses.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/add/add_course_dialog.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final Map<String, bool> _expandedTerms = {};

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final activeSession = currentAcademicSessionNotifier.value;

    if (activeSession == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Courses'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 64,
                  color: AppPrimarySwatch.shade400,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No academic session',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Set up an academic session first to manage courses',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppPrimarySwatch.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final termWindows = buildTermWindows(activeSession);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: mockCoursesNotifier,
        builder: (context, courses, _) {
          // Group courses by term
          final coursesByTerm = <String, List<Course>>{};
          for (final term in termWindows) {
            coursesByTerm[term.id] = courses
                .where((c) =>
                    c.sessionId == activeSession.id && c.termId == term.id)
                .toList();
          }

          if (coursesByTerm.values.every((list) => list.isEmpty)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 64,
                      color: AppPrimarySwatch.shade400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No courses yet',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add your first course to get started',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppPrimarySwatch.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: termWindows.length,
            itemBuilder: (context, index) {
              final term = termWindows[index];
              final termCourses = coursesByTerm[term.id] ?? [];
              final isExpanded = _expandedTerms[term.id] ?? false;

              if (termCourses.isEmpty) {
                return const SizedBox.shrink();
              }

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ExpansionTile(
                  leading: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: AppPrimarySwatch.shade700,
                  ),
                  title: Text(
                    term.label,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _expandedTerms[term.id] = expanded;
                    });
                  },
                  children: [
                    ...termCourses.map((course) {
                      final colorValue = int.tryParse(
                        course.courseColor.replaceFirst('#', '0xFF'),
                      );
                      final courseColor = Color(colorValue ?? 0xFF6C4DD9);
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: courseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(course.courseCode),
                        trailing: PopupMenuButton(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              // TODO: Implement edit
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Edit course (mock)')),
                              );
                            } else if (value == 'delete') {
                              // TODO: Implement delete
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Delete course (mock)')),
                              );
                            }
                          },
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AddCourseDialog.show(
                            context,
                            sessionId: activeSession.id,
                            termId: term.id,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add course'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
