import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/models/academic_session.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/common/empty_state_card.dart';
import '../../core/widgets/common/label_chip.dart';
import '../../core/widgets/common/white_card.dart';
import '../../core/widgets/common/add_new_bottom_sheet.dart';

class AcademicSessionsScreen extends StatefulWidget {
  const AcademicSessionsScreen({super.key});

  @override
  State<AcademicSessionsScreen> createState() => _AcademicSessionsScreenState();
}

class _AcademicSessionsScreenState extends State<AcademicSessionsScreen> {
  final Map<String, bool> _expandedSessions = {};

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Sessions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<List<AcademicSession>>(
        valueListenable: academicSessionsNotifier,
        builder: (context, sessionsList, _) {
          final sessions = [...sessionsList];

          // Sort sessions by start date
          sessions.sort((a, b) => a.startDate.compareTo(b.startDate));

          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: EmptyStateCard(
                  title: 'No academic sessions',
                  subtitle: 'Add your first academic session to get started',
                  buttonText: 'Add Session',
                  icon: Icons.calendar_today_outlined,
                  onPressed: () {
                    AddNewBottomSheet.show(context);
                  },
                ),
              ),
            );
          }

          // Determine which session should show "Current" or "Coming Soon"
          final now = DateTime.now();
          String? currentSessionId;
          String? comingSoonSessionId;

          // Find session where today is within a term window
          for (final session in sessions) {
            final termWindows = buildTermWindows(session);
            final isCurrent = termWindows.any((term) =>
                !now.isBefore(term.start) && !now.isAfter(term.end));
            if (isCurrent) {
              currentSessionId = session.id;
              break;
            }
          }

          // If no current session, find the closest upcoming session
          if (currentSessionId == null) {
            AcademicSession? closestUpcoming;
            Duration? minDuration;
            for (final session in sessions) {
              final termWindows = buildTermWindows(session);
              for (final term in termWindows) {
                if (term.start.isAfter(now)) {
                  final duration = term.start.difference(now);
                  if (minDuration == null || duration < minDuration) {
                    minDuration = duration;
                    closestUpcoming = session;
                  }
                }
              }
            }
            if (closestUpcoming != null) {
              comingSoonSessionId = closestUpcoming.id;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isCurrent = currentSessionId == session.id;
              final isComingSoon = comingSoonSessionId == session.id;
              final isExpanded = _expandedSessions[session.id] ?? false;
              final termWindows = buildTermWindows(session);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: WhiteCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      leading: Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
                        color: appPrimarySwatch.shade700,
                      ),
                      title: Row(
                        children: [
                          Text(session.name, style: textTheme.titleMedium),
                          if (isCurrent) ...[
                            const SizedBox(width: AppSpacing.sm),
                            LabelChip(
                              label: 'Current',
                              color: Colors.green,
                            ),
                          ] else if (isComingSoon) ...[
                            const SizedBox(width: AppSpacing.sm),
                            LabelChip(
                              label: 'Coming Soon',
                              color: Colors.orange,
                            ),
                          ],
                        ],
                      ),
                      trailing: SizedBox(
                        width: 24,
                        height: 24,
                        child: PopupMenuButton(
                          padding: EdgeInsets.zero,
                          color: Colors.white,
                          constraints: const BoxConstraints(),
                          iconSize: 24,
                          icon: const Icon(Icons.more_vert, size: 24),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await AcademicSessionSetupBottomSheet.show(
                                context,
                                title: 'Edit Academic Session',
                                editSession: session,
                              );
                            } else if (value == 'delete') {
                              final confirmed = await showConfirmDeleteDialog(
                                context,
                                title: 'Delete Academic Session',
                                message:
                                    'Are you sure you want to delete "${session.name}"?',
                              );
                              if (!confirmed) return;
                              deleteAcademicSession(session.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Deleted "${session.name}"'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _expandedSessions[session.id] = expanded;
                        });
                      },
                        children: termWindows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final term = entry.value;
                          final now = DateTime.now();
                          final isCurrent =
                              !now.isBefore(term.start) && !now.isAfter(term.end);
                          final isFirst = index == 0;
                          final isLast = index == termWindows.length - 1;

                          return Padding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.lg,
                              right: AppSpacing.lg,
                            ),
                            child: Row(
                              crossAxisAlignment: isFirst
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Timeline column with bullet and connecting line
                                Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Connecting line (dotted) - above the circle for second item
                                      if (!isFirst)
                                        Container(
                                          width: 2,
                                          margin: const EdgeInsets.only(bottom: 0),
                                          child: SizedBox(
                                            height: 17,
                                            child: CustomPaint(
                                              painter: _DottedLinePainter(),
                                            ),
                                          ),
                                        ),
                                      // Timeline bullet point
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCurrent
                                              ? appPrimarySwatch.shade700
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isCurrent
                                                ? appPrimarySwatch.shade700
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      // Connecting line (dotted) - below the circle for first item
                                      if (!isLast)
                                        Container(
                                          width: 2,
                                          margin: const EdgeInsets.only(top: 0),
                                          child: SizedBox(
                                            height: 33,
                                            child: CustomPaint(
                                              painter: _DottedLinePainter(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                               const SizedBox(width: AppSpacing.md),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text(
                                       term.label,
                                       style: textTheme.bodyLarge?.copyWith(
                                         fontWeight: isCurrent
                                             ? FontWeight.w700
                                             : FontWeight.w400,
                                         color: isCurrent
                                             ? Colors.black87
                                             : Colors.grey.shade600,
                                       ),
                                     ),
                                     const SizedBox(height: 4),
                                     Text(
                                       '${_formatDate(term.start)} – ${_formatDate(term.end)}',
                                       style: textTheme.bodyMedium?.copyWith(
                                         color: isCurrent
                                             ? appPrimarySwatch.shade600
                                             : Colors.grey.shade500,
                                       ),
                                     ),
                                     const SizedBox(height: AppSpacing.md),
                                   ],
                                 ),
                               ),
                             ],
                          ),
                        );
                       }).toList(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<List<AcademicSession>>(
        valueListenable: academicSessionsNotifier,
        builder: (context, sessionsList, _) {
          // Only show FAB when sessions are not empty
          if (sessionsList.isEmpty) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton(
            onPressed: () async {
              await AcademicSessionSetupBottomSheet.show(
                context,
                title: 'Add New Academic Session',
              );
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return formatDateShortWithYear(date);
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 4;
    const dashSpace = 3;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

