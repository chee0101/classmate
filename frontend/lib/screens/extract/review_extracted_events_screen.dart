import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/academic_event.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/widgets/common/white_card.dart';
import '../../core/widgets/common/label_chip.dart';
import '../../core/utils/term_windows.dart';
import '../../core/utils/date_time_format.dart';
import '../../screens/schedule/schedule_event_editor_screen.dart';
import '../../core/services/extraction_job_store.dart';
import '../../core/widgets/common/confirm_dialog.dart';

class ReviewExtractedEventsScreen extends StatefulWidget {
  const ReviewExtractedEventsScreen({
    super.key,
    required this.responseJson,
    required this.sessionId,
    required this.termId,
  });

  final String responseJson;
  final String sessionId;
  final String termId;

  @override
  State<ReviewExtractedEventsScreen> createState() =>
      _ReviewExtractedEventsScreenState();
}

class _ReviewExtractedEventsScreenState
    extends State<ReviewExtractedEventsScreen> {
  late final List<_ExtractedEventItem> _events;

  bool _isSaving = false;

  String? _errorMessage;

  bool _isApiError = false;

  @override
  void initState() {
    super.initState();
    _events = _parseEvents();
  }

  bool _isWithinSelectedTerm(
    DateTime start,
    DateTime end,
  ) {
    final sessions = academicSessionsNotifier.value;

    TermWindow? matchedTerm;

    for (final session in sessions) {
      if (session.id != widget.sessionId) {
        continue;
      }

      final windows = buildTermWindows(session);

      for (final term in windows) {
        if (term.id == widget.termId) {
          matchedTerm = term;
          break;
        }
      }
    }

    if (matchedTerm == null) {
      return true;
    }

    return !start.isBefore(
          matchedTerm.start,
        ) &&
        !end.isAfter(
          matchedTerm.end,
        );
  }

  String? matchedTermDateRange() {
    final sessions = academicSessionsNotifier.value;

    TermWindow? matchedTerm;

    for (final session in sessions) {
      if (session.id != widget.sessionId) {
        continue;
      }

      final windows = buildTermWindows(session);

      for (final term in windows) {
        if (term.id == widget.termId) {
          matchedTerm = term;
          break;
        }
      }
    }

    if (matchedTerm == null) {
      return null;
    }

    return formatDateRangeDdMmYyyy(matchedTerm.start, matchedTerm.end);
  }

  List<_ExtractedEventItem> _parseEvents() {
    log(widget.responseJson);

    try {
      final decoded = jsonDecode(
        widget.responseJson,
      );

      if (decoded['success'] == false) {
        _isApiError = true;

        final rawError = decoded['error']?['message']?.toString() ?? '';

        if (rawError.contains('429') ||
            rawError.contains('RESOURCE_EXHAUSTED')) {
          _errorMessage =
              'Extraction service temporarily unavailable. Please try again later.';
        } else {
          _errorMessage = 'Could not extract data from this content.';
        }

        return [];
      }

      final extraction = decoded['extraction'];

      if (extraction == null) {
        return [];
      }

      dynamic events;

      final academicSession = extraction['academic_session'];

      if (academicSession != null) {
        events = academicSession['events'];
      } else {
        events = extraction['events'];
      }

      if (events is! List) {
        return [];
      }

      final parsed = <_ExtractedEventItem>[];

      for (final e in events) {
        final start = DateTime.tryParse(
          e['start_datetime']?.toString() ?? '',
        );

        final end = DateTime.tryParse(
          e['end_datetime']?.toString() ?? '',
        );

        if (start == null || end == null) {
          continue;
        }

        parsed.add(
          _ExtractedEventItem(
            title: (e['title'] ?? '').toString(),
            location: e['location']?.toString(),
            startDateTime: start,
            endDateTime: end,
            allDay: e['all_day'] == true,
            hideClassesDuringEvent: true,
            isAcademicBreak: e['is_academic_break'] == true,
            selected: true,
          ),
        );
      }

      return parsed;
    } catch (e, stack) {
      log(e.toString());
      log(stack.toString());
      return [];
    }
  }

  TermWindow? _selectedTermWindow() {
    final sessions = academicSessionsNotifier.value;

    for (final session in sessions) {
      if (session.id != widget.sessionId) {
        continue;
      }

      final windows = buildTermWindows(session);

      for (final term in windows) {
        if (term.id == widget.termId) {
          return term;
        }
      }
    }

    return null;
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }

    final selectedEvents = _events
        .where(
          (e) => e.selected,
        )
        .toList();

    if (selectedEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one event.',
          ),
        ),
      );
      return;
    }

    final selection = selectedSessionTermNotifier.value;

    if (selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a session and term first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (final event in selectedEvents) {
        if (event.startDateTime == null || event.endDateTime == null) {
          continue;
        }

        await addAcademicEvent(
          AcademicEvent(
            id: '',
            sessionId: widget.sessionId,
            termId: widget.termId,
            title: event.title,
            startDateTime: event.startDateTime!,
            endDateTime: event.endDateTime!,
            allDay: event.allDay,
            hideClassesDuringEvent: event.hideClassesDuringEvent,
            isAcademicBreak: event.isAcademicBreak,
            location: event.location,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Events imported successfully.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _confirmDiscardReview() async {
    if (_isSaving) return false;

    return showConfirmDialog(
      context,
      title: 'Discard extracted events?',
      message:
          'If you leave now, reviewed extracted events will not be saved and will be lost.',
      cancelText: 'Stay',
      confirmText: 'Discard and leave',
      destructive: true,
    );
  }

  Future<void> _openEventEditor(
    _ExtractedEventItem event,
  ) async {
    final selection = selectedSessionTermNotifier.value;

    if (selection == null) {
      return;
    }

    final selectedTerm = _selectedTermWindow();

    if (selectedTerm == null) {
      return;
    }

    final result = await Navigator.push<AcademicEvent>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleEventEditorScreen(
          initialEvent: AcademicEvent(
            id: '',
            sessionId: widget.sessionId,
            termId: widget.termId,
            title: event.title,
            startDateTime: event.startDateTime!,
            endDateTime: event.endDateTime!,
            allDay: event.allDay,
            hideClassesDuringEvent: event.hideClassesDuringEvent,
            isAcademicBreak: event.isAcademicBreak,
            location: event.location,
          ),
          selectedTerm: selectedTerm,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      event.title = result.title;
      event.location = result.location;
      event.startDateTime = result.startDateTime;
      event.endDateTime = result.endDateTime;
      event.allDay = result.allDay;
      event.hideClassesDuringEvent = result.hideClassesDuringEvent;
      event.isAcademicBreak = result.isAcademicBreak;
    });
  }

  bool get _hasSelectedEventsOutsideTerm {
    for (final event in _events) {
      if (!event.selected) continue;
      if (event.startDateTime == null || event.endDateTime == null) return true;
      if (!_isWithinSelectedTerm(event.startDateTime!, event.endDateTime!)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          final shouldLeave = await _confirmDiscardReview();

          if (!shouldLeave || !mounted) return;

          dismissExtractionJobCard();

          Navigator.of(context).pop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Review Events',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                final shouldLeave = await _confirmDiscardReview();

                if (!shouldLeave || !mounted) return;

                dismissExtractionJobCard();

                Navigator.of(context).pop();
              },
            ),
          ),
          body: _isApiError || _events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                        ),
                        const SizedBox(
                          height: AppSpacing.md,
                        ),
                        Text(
                          'Could not extract data',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium,
                        ),
                        const SizedBox(
                          height: AppSpacing.sm,
                        ),
                        Text(
                          'Please try clearer instructions or try again later.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                        const SizedBox(
                          height: AppSpacing.lg,
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Go back',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(
                          AppSpacing.md,
                        ),
                        child: _ExtractedEventsPage(
                          events: _events,
                          onEdit: _openEventEditor,
                          onToggleSelected: (event, value) {
                            setState(() {
                              event.selected = value;
                            });
                          },
                          isOutsideTerm: (event) {
                            if (event.startDateTime == null ||
                                event.endDateTime == null) return true;
                            return !_isWithinSelectedTerm(
                                event.startDateTime!, event.endDateTime!);
                          },
                          matchedTermDateRange: matchedTermDateRange(),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.all(
                        AppSpacing.md,
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_hasSelectedEventsOutsideTerm)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs),
                                child: Text(
                                  'Please resolve the errors before saving.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ElevatedButton(
                              onPressed:
                                  (_isSaving || _hasSelectedEventsOutsideTerm)
                                      ? null
                                      : _handleSave,
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Import Events',
                                    ),
                            ),
                          ]),
                    ),
                  ],
                ),
        ));
  }
}

class _ExtractedEventItem {
  _ExtractedEventItem({
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.allDay,
    required this.hideClassesDuringEvent,
    required this.isAcademicBreak,
    required this.selected,
    this.location,
  });

  String title;

  String? location;

  DateTime? startDateTime;

  DateTime? endDateTime;

  bool allDay;

  bool hideClassesDuringEvent;

  bool isAcademicBreak;

  bool selected;
}

class _ExtractedEventsPage extends StatelessWidget {
  const _ExtractedEventsPage({
    required this.events,
    required this.onEdit,
    required this.onToggleSelected,
    required this.isOutsideTerm,
    required this.matchedTermDateRange,
  });

  final List<_ExtractedEventItem> events;

  final Future<void> Function(
    _ExtractedEventItem event,
  ) onEdit;

  final void Function(
    _ExtractedEventItem event,
    bool value,
  ) onToggleSelected;

  final bool Function(_ExtractedEventItem event) isOutsideTerm;

  final String? matchedTermDateRange;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
            ),
            child: WhiteCard(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.sm,
                0,
                AppSpacing.sm,
              ),
              borderRadius: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: event.selected,
                    onChanged: (value) {
                      onToggleSelected(
                        event,
                        value ?? false,
                      );
                    },
                  ),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onEdit(event),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xs,
                            bottom: AppSpacing.xs,
                            right: AppSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isOutsideTerm(event)) ...[
                                const Padding(
                                  padding: EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: LabelChip(
                                    label: 'OUTSIDE TERM',
                                    background: Color(0xFFFFE5E5),
                                    foreground: Color(0xFFD32F2F),
                                  ),
                                ),
                              ],
                              Text(
                                event.title,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                _buildDateTimeText(event),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              if (event.location != null &&
                                  event.location!.trim().isNotEmpty) ...[
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  event.location!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              if (event.hideClassesDuringEvent) ...[
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'Hide classes during this event',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (isOutsideTerm(event)) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Event dates must be within the selected term ($matchedTermDateRange)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                              if (event.isAcademicBreak) ...[
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'Academic break',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.sm,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _buildDateTimeText(
    _ExtractedEventItem event,
  ) {
    final start = event.startDateTime;
    final end = event.endDateTime;

    if (start == null || end == null) {
      return 'No date';
    }

    if (event.allDay) {
      return formatDateRangeDdMmYyyy(
        start,
        end,
      );
    }

    return formatDateTimeRangeDdMmYyyy(
      start,
      end,
    );
  }
}
