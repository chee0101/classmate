import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../utils/term_windows.dart';

/// A header widget that displays and allows selection of academic session and term.
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    super.key,
    required this.sessionName,
    required this.termWindows,
    required this.selectedTerm,
    required this.onTermChanged,
  });

  final String sessionName;
  final List<TermWindow> termWindows;
  final TermWindow selectedTerm;
  final ValueChanged<String> onTermChanged;

  @override
  Widget build(BuildContext context) {
    final darkPurpleTextStyle = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppPrimarySwatch.shade900,
    );

    final entries = termWindows
        .map(
          (t) => DropdownMenuEntry<String>(
            value: t.id,
            label: '$sessionName - ${t.label}',
            labelWidget: Text(
              '$sessionName - ${t.label}',
              style: darkPurpleTextStyle,
            ),
          ),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownMenu<String>(
            width: constraints.maxWidth,
            initialSelection: selectedTerm.id,
            dropdownMenuEntries: entries,
            onSelected: (value) {
              if (value == null) return;
              onTermChanged(value);
            },
            inputDecorationTheme: InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintStyle: darkPurpleTextStyle,
              labelStyle: darkPurpleTextStyle,
            ),
            textStyle: darkPurpleTextStyle,
          ),
        );
      },
    );
  }
}
