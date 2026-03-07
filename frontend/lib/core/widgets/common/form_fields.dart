import 'package:flutter/material.dart';

class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
    this.errorText,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final String? errorText;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class TapField extends StatelessWidget {
  const TapField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hintText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? hintText;

  bool _isPlaceholder(String value, String? hintText) {
    if (hintText != null && value == hintText) {
      return true;
    }
    // Check for common placeholder patterns
    final lowerValue = value.toLowerCase();
    return lowerValue.startsWith('select') || 
           lowerValue == '' ||
           (hintText != null && lowerValue == hintText.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isPlaceholder = _isPlaceholder(value, hintText);
    final textColor = isPlaceholder 
        ? Colors.grey.shade400 
        : Colors.black87;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.titleSmall),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.showLabel = true,
  });

  final String label;
  final T? value;
  final List<DropdownMenuEntry<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hintText;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final dropdownTextStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<T>(
              key: ValueKey(value),
              width: constraints.maxWidth,
              hintText: hintText,
              initialSelection: value,
              dropdownMenuEntries: items,
              onSelected: onChanged,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                hintStyle: dropdownTextStyle,
                labelStyle: dropdownTextStyle,
              ),
            );
          },
        ),
      ],
    );
  }
}
