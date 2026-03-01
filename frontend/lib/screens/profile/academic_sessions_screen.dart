import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/mock/mock_academic_session.dart';
import '../../core/utils/term_windows.dart';
import '../../core/widgets/common/academic_session_setup_bottom_sheet.dart';

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
        title: const Text('Academic Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: currentAcademicSessionNotifier,
        builder: (context, activeSession, _) {
          final sessions = [...mockAcademicSessions];
          if (activeSession != null &&
              !sessions.any((s) => s.id == activeSession.id)) {
            sessions.add(activeSession);
          }

          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: AppPrimarySwatch.shade400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No academic sessions',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add your first academic session to get started',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppPrimarySwatch.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () {
                        AcademicSessionSetupBottomSheet.show(context);
                      },
                      child: const Text('Add Session'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isActive = activeSession?.id == session.id;
              final isExpanded = _expandedSessions[session.id] ?? false;
              final termWindows = buildTermWindows(session);

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ExpansionTile(
                  leading: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: AppPrimarySwatch.shade700,
                  ),
                  title: Row(
                    children: [
                      Text(
                        session.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _expandedSessions[session.id] = expanded;
                    });
                  },
                  children: termWindows.map((term) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        bottom: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 16,
                            color: AppPrimarySwatch.shade600,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${term.label}: ${_formatDate(term.start)} - ${_formatDate(term.end)}',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AcademicSessionSetupBottomSheet.show(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
