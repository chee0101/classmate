import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../services/extraction_job_store.dart';
import '../../utils/extraction_user_messages.dart';
import 'confirm_dialog.dart';

class ExtractionProgressFloatingCard extends StatelessWidget {
  const ExtractionProgressFloatingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ExtractionJobState?>(
      valueListenable: extractionJobNotifier,
      builder: (context, job, _) {
        if (job == null) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final isRunning = job.isRunning;
        final titleText = switch (job.status) {
          ExtractionJobStatus.queued || ExtractionJobStatus.running =>
            'Extracting...',
          ExtractionJobStatus.success => job.hasWarnings
              ? 'Extraction Complete (Warnings)'
              : 'Extraction Complete',
          ExtractionJobStatus.failed => 'Extraction Failed',
        };
        final subtitleText = switch (job.status) {
          ExtractionJobStatus.queued || ExtractionJobStatus.running =>
            'May take a few minutes...',
          ExtractionJobStatus.success => job.hasWarnings
              ? (job.warningMessage ?? 'Tap for review')
              : 'Tap for review',
          ExtractionJobStatus.failed => friendlyExtractionErrorMessage(
              technicalMessage: job.message,
              responseBody: job.responseBody,
              httpStatusCode: job.statusCode,
            ),
        };
        final icon = switch (job.status) {
          ExtractionJobStatus.queued || ExtractionJobStatus.running => const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ExtractionJobStatus.success => Icon(Icons.check_circle, color: Colors.green.shade600),
          ExtractionJobStatus.failed => Icon(Icons.error, color: Colors.red.shade600),
        };

        return Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Row(
              children: [
                icon,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.75),
                            ),
                      ),
                    ],
                  ),
                ),
                if (isRunning)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Cancel extraction?',
                        message:
                            'Are you sure you want to cancel? The current upload will stop and any partial result will be discarded.',
                        cancelText: 'No',
                        confirmText: 'Yes, cancel',
                        destructive: true,
                      );
                      if (!context.mounted || !confirmed) return;
                      cancelRunningExtractionJob();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Extraction cancelled')),
                      );
                    },
                    child: const Text('Cancel'),
                  ),
                if (job.status == ExtractionJobStatus.success)
                  IconButton(
                    tooltip: 'Review extracted data',
                    onPressed: () {
                      final body = job.responseBody;
                      if (body == null || body.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No extraction data to review.'),
                          ),
                        );
                        return;
                      }
                      final route = switch (job.typeLabel) {
                        'Academic calendar' => AppRoutes.reviewExtractedCalendar,
                        'Task' => AppRoutes.reviewExtractedTasks,
                        'Timetable' => AppRoutes.reviewExtractedTimetable,
                        _ => null,
                      };
                      if (route == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Review for “${job.typeLabel}” is not available yet.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (job.status != ExtractionJobStatus.success) {
                        return;
                      }
                      final Object args;
                      if (route == AppRoutes.reviewExtractedTasks) {
                        args = <String, dynamic>{
                          'responseJson': body,
                          'assignedCourseCode': job.assignedCourseCode,
                        };
                      } else if (route == AppRoutes.reviewExtractedTimetable) {
                        args = <String, dynamic>{
                          'responseJson': body,
                          'sessionId': job.sessionId,
                          'termId': job.termId,
                        };
                      } else {
                        args = body;
                      }
                      Navigator.of(context).pushNamed(route, arguments: args);
                    },
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                  ),
                if (job.status == ExtractionJobStatus.failed)
                  const IconButton(
                    tooltip: 'Dismiss',
                    onPressed: dismissExtractionJobCard,
                    icon: Icon(Icons.close),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

