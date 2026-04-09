import 'package:flutter/material.dart';

/// App-styled outlined icon button (primary foreground + subtle primary border).
class AppOutlinedIconButton extends StatelessWidget {
  const AppOutlinedIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.expand = true,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: label,
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

