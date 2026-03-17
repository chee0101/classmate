import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';

class ColorPicker extends StatelessWidget {
  final List<Color> colors;
  final int selectedIndex;
  final Function(int) onSelect;

  const ColorPicker({
    super.key,
    required this.colors,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: List.generate(colors.length, (index) {
        final color = colors[index];
        final selected = index == selectedIndex;

        return GestureDetector(
          onTap: () => onSelect(index),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: selected
                  ? Border.all(
                      color: Colors.black.withOpacity(0.6),
                      width: 2,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }
}