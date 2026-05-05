import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../models/academic_session.dart';
import '../../services/academic_session_store.dart';
import '../../utils/term_windows.dart';

/// A header widget that displays and allows selection of academic session and term.
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    super.key,
    required this.sessions,
    required this.selectedSessionId,
    required this.selectedTermId,
    required this.onSelectionChanged,
  });

  /// All available academic sessions.
  final List<AcademicSession> sessions;

  /// Currently selected session ID.
  final String selectedSessionId;

  /// Currently selected term ID (within the selected session).
  final String selectedTermId;

  /// Callback when user selects a different (session, term) pair.
  final void Function(String sessionId, String termId) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final darkPurpleTextStyle = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: appPrimarySwatch.shade900,
    );

    // Build dropdown entries for all (session, term) combinations.
    final entries = <DropdownMenuEntry<String>>[];
    final currentSession = currentAcademicSessionNotifier.value;
    final currentSessionId = currentSession?.id;
    final currentTermId = currentSession == null
        ? null
        : defaultTermId(buildTermWindows(currentSession));

    for (final session in sessions) {
      final termWindows = buildTermWindows(session);
      for (final term in termWindows) {
        final key = '${session.id}::${term.id}';
        final isCurrent =
            session.id == currentSessionId && term.id == currentTermId;
        final label = isCurrent
            ? '${session.name} · ${term.label} (Current)'
            : '${session.name} · ${term.label}';
        entries.add(
          DropdownMenuEntry<String>(
            value: key,
            label: label,
            labelWidget: Text(
              label,
              style: darkPurpleTextStyle,
            ),
          ),
        );
      }
    }

    final initialKey = '$selectedSessionId::$selectedTermId';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownMenu<String>(
            width: constraints.maxWidth,
            initialSelection: initialKey,
            menuStyle: MenuStyle(
              elevation: const WidgetStatePropertyAll<double>(8),
              backgroundColor: const WidgetStatePropertyAll<Color>(
                Colors.white,
              ),
              surfaceTintColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              shadowColor: WidgetStatePropertyAll<Color>(
                Colors.black.withValues(alpha: 1),
              ),
              shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            dropdownMenuEntries: entries,
            onSelected: (value) {
              if (value == null) return;
              final parts = value.split('::');
              if (parts.length != 2) return;
              onSelectionChanged(parts[0], parts[1]);
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
