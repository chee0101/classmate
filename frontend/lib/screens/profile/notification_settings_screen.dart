import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/notification_preferences_store.dart';
import '../../core/widgets/common/form_fields.dart';
import '../../core/widgets/common/white_card.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const List<int> _leadTimeOptions = <int>[1440, 180, 60, 45, 30, 15, 10];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ValueListenableBuilder<NotificationPreferences>(
        valueListenable: notificationPreferencesNotifier,
        builder: (context, prefs, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _typeSection(
                context: context,
                title: 'Task reminders',
                value: prefs.task,
                onChanged: (next) {
                  _save(context, prefs.copyWith(task: next));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _typeSection(
                context: context,
                title: 'Event reminders',
                value: prefs.event,
                onChanged: (next) {
                  _save(context, prefs.copyWith(event: next));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _typeSection(
                context: context,
                title: 'Class reminders',
                value: prefs.classReminder,
                onChanged: (next) {
                  _save(context, prefs.copyWith(classReminder: next));
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _typeSection({
    required BuildContext context,
    required String title,
    required NotificationTypePreferences value,
    required ValueChanged<NotificationTypePreferences> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: textTheme.titleSmall)),
              Switch(
                value: value.enabled,
                onChanged: (enabled) {
                  onChanged(value.copyWith(enabled: enabled));
                },
              ),
            ],
          ),
          if (value.enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownField<int>(
              label: 'Lead time',
              showLabel: false,
              value: value.leadTimeMinutes,
              items: _leadTimeOptions
                  .map(
                    (minutes) => DropdownMenuEntry<int>(
                      value: minutes,
                      label: _formatLeadTime(minutes),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (minutes) {
                if (minutes == null) return;
                onChanged(value.copyWith(leadTimeMinutes: minutes));
              },
              hintText: _formatLeadTime(value.leadTimeMinutes),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatLeadTime(int minutes) {
    if (minutes == 1440) {
      return '1 day before';
    }
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour before' : '$hours hours before';
    }
    return '$minutes minutes before';
  }

  Future<void> _save(BuildContext context, NotificationPreferences next) async {
    try {
      await updateNotificationPreferences(next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences updated.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Check internet and try again.')),
      );
    }
  }
}
