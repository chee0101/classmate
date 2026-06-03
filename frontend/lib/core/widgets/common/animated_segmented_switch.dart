import 'package:flutter/material.dart';

class SegmentedSwitchOption<T> {
  const SegmentedSwitchOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class AnimatedSegmentedSwitch<T> extends StatelessWidget {
  const AnimatedSegmentedSwitch({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 50,
    this.padding = const EdgeInsets.all(4),
    this.borderRadius = 12,
    this.itemBorderRadius = 10,
    this.gap = 0,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOut,
    this.backgroundColor,
    this.thumbColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.textStyle,
  }) : assert(options.length > 1, 'At least 2 options are required.');

  final List<SegmentedSwitchOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double itemBorderRadius;
  final double gap;
  final Duration duration;
  final Curve curve;
  final Color? backgroundColor;
  final Color? thumbColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseTextStyle = textStyle ??
        Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            );
    final selectedIndex = _selectedIndex();

    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final totalGap = gap * (options.length - 1);
          final itemWidth = (availableWidth - totalGap) / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: curve,
                left: selectedIndex * (itemWidth + gap),
                top: 0,
                width: itemWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumbColor ?? colorScheme.primary,
                    borderRadius: BorderRadius.circular(itemBorderRadius),
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < options.length; i++) ...[
                    SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        onTap: () => onChanged(options[i].value),
                        borderRadius: BorderRadius.circular(itemBorderRadius),
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                options[i].label,
                                maxLines: 1,
                                style: baseTextStyle?.copyWith(
                                  color: i == selectedIndex
                                      ? (selectedTextColor ?? Colors.white)
                                      : (unselectedTextColor ??
                                          colorScheme.primary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i != options.length - 1) SizedBox(width: gap),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  int _selectedIndex() {
    final index = options.indexWhere((option) => option.value == value);
    return index < 0 ? 0 : index;
  }
}
