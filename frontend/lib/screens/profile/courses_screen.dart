import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/session_term_ref.dart';
import '../../core/models/academic_session.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/widgets/add/add_course_dialog.dart';
import '../../core/widgets/common/add_new_bottom_sheet.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/home/session_header.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {

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
                padding: const EdgeInsets.all(AppSpacing.md),
                child: EmptyStateCard(
                  title: 'No academic session',
                  subtitle:
                      'Set up an academic session first to manage courses',
                  buttonText: 'Add session',
                  icon: Icons.calendar_today_outlined,
                  onPressed: () {
                    AddNewBottomSheet.show(context);
                  },
                ),
              ),
            );
          }

          // Build all (session, term) combinations and resolve default.
          final now = DateTime.now();
          final allTermRefs = buildAllSessionTermRefs(sessions);
          final resolvedDefaultRef =
              resolveDefaultSessionTermRef(allTermRefs, now);

          return ValueListenableBuilder<SessionTermSelection?>(
            valueListenable: selectedSessionTermNotifier,
            builder: (context, selection, _) {
              String selectedSessionId =
                  selection?.sessionId ?? resolvedDefaultRef.session.id;
              String selectedTermId =
                  selection?.termId ?? resolvedDefaultRef.term.id;

              SessionTermRef selectedRef = resolvedDefaultRef;
              for (final ref in allTermRefs) {
                if (ref.session.id == selectedSessionId &&
                    ref.term.id == selectedTermId) {
                  selectedRef = ref;
                  break;
                }
              }

              selectedSessionId = selectedRef.session.id;
              selectedTermId = selectedRef.term.id;
              String semesterName = selectedTermId == 'sem1' ? 'Semester 1' : 'Semester 2';

              if (selection == null ||
                  selection.sessionId != selectedSessionId ||
                  selection.termId != selectedTermId) {
                setSelectedSessionTerm(
                  sessionId: selectedSessionId,
                  termId: selectedTermId,
                );
              }

              return ValueListenableBuilder(
                valueListenable: coursesNotifier,
                builder: (context, courses, _) {
                  final filteredCourses = courses
                      .where(
                        (c) =>
                            c.sessionId == selectedSessionId &&
                            c.termId == selectedTermId,
                      )
                      .toList(growable: false);

                  final header = Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: SessionHeader(
                      sessions: sessions,
                      selectedSessionId: selectedSessionId,
                      selectedTermId: selectedTermId,
                      onSelectionChanged: (sessionId, termId) {
                        setSelectedSessionTerm(
                          sessionId: sessionId,
                          termId: termId,
                        );
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
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: EmptyStateCard(
                              title: 'No courses added',
                              subtitle:
                                  'Add your first course for Academic Session ${activeSession?.name} $semesterName.',
                              buttonText: 'Add course',
                              icon: Icons.book_outlined,
                              onPressed: () {
                                CourseDialog.show(
                                  context,
                                  sessionId: selectedSessionId,
                                  termId: selectedTermId,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                                        sessionId: selectedSessionId,
                                        termId: selectedTermId,
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
          );
        },
      ),
    );
  }
}
