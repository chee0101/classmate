import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../services/extraction_job_store.dart';
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
        final titleText = isRunning ? 'Extracting...' : 'Extraction Complete';
        final subtitleText =
            isRunning ? 'May take a few minutes...' : 'Tap for review';
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
                if (!isRunning)
                  IconButton(
                    tooltip: 'Review extracted data',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Open Review Screen to review before saving'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

