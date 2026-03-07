import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/routes.dart';
import '../../services/academic_session_store.dart';
import 'academic_session_setup_bottom_sheet.dart';

class AddNewBottomSheet extends StatelessWidget {
  const AddNewBottomSheet({super.key});

  static void show(BuildContext context) {
    if (!hasAcademicSession()) {
      AcademicSessionSetupBottomSheet.show(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddNewBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Add New',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  icon: Icons.document_scanner_outlined,
                  title: 'Auto Extract',
                  subtitle: 'Auto-fill from documents',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Auto Extract flow will be added next.'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _OptionCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Manual Input',
                  subtitle: 'Enter details manually',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.addNew);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: primaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


