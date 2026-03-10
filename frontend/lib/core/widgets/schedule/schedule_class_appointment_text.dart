import 'package:flutter/material.dart';

class ScheduleClassAppointmentText extends StatelessWidget {
  const ScheduleClassAppointmentText({
    super.key,
    required this.subject,
    required this.textColor,
    required this.maxLines,
  });

  final String subject;
  final Color textColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final parts = subject.split('\n');
    final courseCode = parts.isNotEmpty ? parts.first : subject;
    final classType = parts.length > 1 ? parts.sublist(1).join('\n') : '';
    final resolvedTextColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.28),
      textColor,
    );
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: resolvedTextColor,
        );
    return RichText(
      maxLines: maxLines,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: courseCode,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (classType.isNotEmpty) ...[
            const TextSpan(text: '\n'),
            TextSpan(
              text: classType,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
                color: resolvedTextColor.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
