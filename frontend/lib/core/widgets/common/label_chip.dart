import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';

/// A reusable label chip widget for displaying labels with colored background.
/// Can be used for course codes, status labels, or any other badge-like display.
class LabelChip extends StatelessWidget {
  const LabelChip({
    super.key,
    required this.label,
    this.color,
    this.background,
    this.foreground,
    this.backgroundOpacity = 0.15,
  }) : assert(
          (color != null) != (background != null && foreground != null),
          'Either provide color or both background and foreground',
        );

  /// The text to display in the chip.
  final String label;

  /// Single color that will be used for both background (with opacity) and foreground.
  /// If provided, background and foreground will be ignored.
  final Color? color;

  /// Background color (used when color is not provided).
  final Color? background;

  /// Foreground/text color (used when color is not provided).
  final Color? foreground;

  /// Opacity for background when using the color parameter. Default is 0.15.
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final bgColor = color != null
        ? color!.withOpacity(backgroundOpacity)
        : background!;
    final fgColor = color ?? foreground!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
      ),
    );
  }
}
