import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/course_store.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/add/add_course_dialog.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String? _selectedSessionId;
  String? _selectedTermId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<List<dynamic>>(
        valueListenable: academicSessionsNotifier,
        builder: (context, sessionsList, _) {
          final activeSession = currentAcademicSessionNotifier.value;
          final sessions = <dynamic>[...sessionsList];
          if (activeSession != null &&
              !sessions.any((s) => s.id == activeSession.id)) {
            sessions.add(activeSession);
          }

          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: EmptyStateCard(
                  title: 'No academic session',
                  subtitle:
                      'Set up an academic session first to manage courses',
                  buttonText: 'Add session',
                  icon: Icons.calendar_today_outlined,
                  onPressed: () {
                    AcademicSessionSetupBottomSheet.show(context);
                  },
                ),
              ),
            );
          }

          final allRefs = <Map<String, dynamic>>[];
          for (final session in sessions) {
            final windows = buildTermWindows(session);
            for (final term in windows) {
              allRefs.add({'session': session, 'term': term});
            }
          }

          final now = DateTime.now();
          Map<String, dynamic> selectedRef = allRefs.first;

          final current = allRefs.where((ref) {
            final term = ref['term'];
            return !now.isBefore(term.start) && !now.isAfter(term.end);
          });
          if (current.isNotEmpty) {
            selectedRef = current.first;
          }

          final selectedSessionId =
              _selectedSessionId ?? selectedRef['session'].id;
          final selectedTermId = _selectedTermId ?? selectedRef['term'].id;

          final exact = allRefs.where(
            (ref) =>
                ref['session'].id == selectedSessionId &&
                ref['term'].id == selectedTermId,
          );
          if (exact.isNotEmpty) {
            selectedRef = exact.first;
          }

          final selectedSession = selectedRef['session'];
          final selectedTerm = selectedRef['term'];

          return ValueListenableBuilder(
            valueListenable: coursesNotifier,
            builder: (context, courses, _) {
              final filteredCourses = courses
                  .where(
                    (c) =>
                        c.sessionId == selectedSession.id &&
                        c.termId == selectedTerm.id,
                  )
                  .toList(growable: false);

              final header = Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: SessionHeader(
                  sessions: sessions.cast(),
                  selectedSessionId: selectedSession.id,
                  selectedTermId: selectedTerm.id,
                  onSelectionChanged: (sessionId, termId) {
                    setState(() {
                      _selectedSessionId = sessionId;
                      _selectedTermId = termId;
                    });
                  },
                ),
              );

              if (filteredCourses.isEmpty) {
                return Stack(
                  children: [
                    Column(
                      children: [
                        header,
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: EmptyStateCard(
                          title: 'No courses in ${selectedTerm.label}',
                          subtitle:
                              'Add your first course for ${selectedSession.name}.',
                          buttonText: 'Add course',
                          icon: Icons.book_outlined,
                          onPressed: () {
                            CourseDialog.show(
                              context,
                              sessionId: selectedSession.id,
                              termId: selectedTerm.id,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tap a course to edit',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        bottom: AppSpacing.md,
                      ),
                      itemCount: filteredCourses.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filteredCourses.length) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.sm,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.45),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () {
                                  CourseDialog.show(
                                    context,
                                    sessionId: selectedSession.id,
                                    termId: selectedTerm.id,
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add course'),
                              ),
                            ),
                          );
                        }

                        final course = filteredCourses[index];
                        final colorValue = int.tryParse(
                          course.courseColor.replaceFirst('#', '0xFF'),
                        );
                        final courseColor = Color(colorValue ?? 0xFF6C4DD9);

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              splashColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                              highlightColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.04),
                              onTap: () {
                                CourseDialog.show(
                                  context,
                                  sessionId: course.sessionId,
                                  termId: course.termId,
                                  course: course,
                                );
                              },
                              child: ListTile(
                                leading: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: courseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                title: Text(course.courseCode),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    showConfirmDeleteDialog(
                                      context,
                                      title: 'Delete course',
                                      message:
                                          'Are you sure you want to delete ${course.courseCode}?',
                                    ).then((confirmed) {
                                      if (!confirmed) return;
                                      deleteCourse(course.id);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
