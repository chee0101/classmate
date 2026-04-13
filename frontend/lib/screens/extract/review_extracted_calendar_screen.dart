import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/models/academic_event.dart';
import '../../core/models/academic_session.dart';
import '../../core/services/academic_event_store.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/cascade_cleanup.dart';
import '../../core/services/extraction_job_store.dart';
import '../../core/utils/academic_extraction_json.dart';
import '../../core/utils/app_date_picker.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/utils/day_bounds_utils.dart';
import '../../core/widgets/common/app_outlined_icon_button.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/common/form_fields.dart';
import '../../core/widgets/common/white_card.dart';

/// Review flow after academic calendar extraction: structure (2 pages) + holidays.
enum _ExactSessionAction { replace, mergeIntoExisting, addNew, cancel }

enum _SaveMode { addNew, replace, merge }

class ReviewExtractedCalendarScreen extends StatefulWidget {
  const ReviewExtractedCalendarScreen({
    super.key,
    required this.responseJson,
  });

  final String responseJson;

  @override
  State<ReviewExtractedCalendarScreen> createState() =>
      _ReviewExtractedCalendarScreenState();
}

class _ReviewExtractedCalendarScreenState
    extends State<ReviewExtractedCalendarScreen> {
  ParsedAcademicExtraction? _parsed;
  late List<SessionTerm> _terms;
  late List<ParsedExtractedEvent> _events;
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _saving = false;

  DateTime _toDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _sameDay(DateTime a, DateTime b) => _toDay(a) == _toDay(b);

  bool _rangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return !aEnd.isBefore(bStart) && !aStart.isAfter(bEnd);
  }

  bool _isDuplicateForMerge(
    ParsedExtractedEvent candidate,
    List<AcademicEvent> existingEvents,
  ) {
    for (final existing in existingEvents) {
      if (existing.isAcademicBreak && candidate.isAcademicBreak) {
        final sameTerm =
            existing.termId.trim().toLowerCase() ==
            candidate.termId.trim().toLowerCase();
        final sameTitle =
            existing.title.trim().toLowerCase() ==
            candidate.title.trim().toLowerCase();
        if (!sameTerm || !sameTitle) continue;

        if (_rangesOverlap(
          existing.startDateTime,
          existing.endDateTime,
          candidate.startDateTime,
          candidate.endDateTime,
        )) {
          return true;
        }
        continue;
      }

      final sameSignature = _eventSignature(
            title: existing.title,
            termId: existing.termId,
            start: existing.startDateTime,
            end: existing.endDateTime,
            isAcademicBreak: existing.isAcademicBreak,
          ) ==
          _eventSignature(
            title: candidate.title,
            termId: candidate.termId,
            start: candidate.startDateTime,
            end: candidate.endDateTime,
            isAcademicBreak: candidate.isAcademicBreak,
          );
      if (sameSignature) return true;
    }
    return false;
  }

  String _eventSignature({
    required String title,
    required String termId,
    required DateTime start,
    required DateTime end,
    required bool isAcademicBreak,
  }) {
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedTermId = termId.trim().toLowerCase();
    return '$normalizedTitle|$normalizedTermId|${start.toIso8601String()}|${end.toIso8601String()}|$isAcademicBreak';
  }

  AcademicSession? _findExactDateMatch(AcademicSession candidate) {
    for (final session in academicSessionsNotifier.value) {
      if (_sameDay(session.startDate, candidate.startDate) &&
          _sameDay(session.endDate, candidate.endDate)) {
        return session;
      }
    }
    return null;
  }

  List<AcademicSession> _findOverlappingSessions(
    AcademicSession candidate, {
    String? excludeSessionId,
  }) {
    return academicSessionsNotifier.value.where((session) {
      if (excludeSessionId != null && session.id == excludeSessionId) {
        return false;
      }
      return _rangesOverlap(
        _toDay(session.startDate),
        _toDay(session.endDate),
        _toDay(candidate.startDate),
        _toDay(candidate.endDate),
      );
    }).toList(growable: false);
  }

  Future<_ExactSessionAction> _askExactSessionAction(
    AcademicSession existing,
  ) async {
    final result = await showFourOptionDialog(
      context,
      title: 'Session already exists',
      message:
          'A session with the same start and end dates already exists: '
          '"${existing.name}" '
          '(${formatDateDdMmYyyy(existing.startDate)} – ${formatDateDdMmYyyy(existing.endDate)}).\n\n'
          'Choose how to save extracted events.',
      cancelText: 'Cancel',
      tertiaryText: 'Add new',
      secondaryText: 'Merge',
      primaryText: 'Replace',
    );
    return switch (result) {
      FourOptionDialogResult.cancel => _ExactSessionAction.cancel,
      FourOptionDialogResult.tertiary => _ExactSessionAction.addNew,
      FourOptionDialogResult.secondary => _ExactSessionAction.mergeIntoExisting,
      FourOptionDialogResult.primary => _ExactSessionAction.replace,
    };
  }

  Future<bool> _confirmOverlapWarning(List<AcademicSession> overlaps) async {
    final preview = overlaps
        .take(3)
        .map(
          (s) =>
              '- ${s.name} (${formatDateDdMmYyyy(s.startDate)} – ${formatDateDdMmYyyy(s.endDate)})',
        )
        .join('\n');
    final hasMore = overlaps.length > 3;
    final suffix = hasMore ? '\n- ...and ${overlaps.length - 3} more' : '';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Session date overlap',
      message:
          'This session overlaps with existing session(s):\n\n$preview$suffix\n\nContinue anyway?',
      cancelText: 'Cancel',
      confirmText: 'Continue',
    );
    return confirmed;
  }

  @override
  void initState() {
    super.initState();
    _parsed = tryParseAcademicExtractionEnvelope(widget.responseJson);
    if (_parsed != null) {
      _terms = List<SessionTerm>.from(_parsed!.terms);
      _events = List<ParsedExtractedEvent>.from(_parsed!.events);
    } else {
      _terms = [];
      _events = [];
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _sessionPickerFirstDate() {
    final s = _parsed!.sessionStart;
    return DateTime(s.year, s.month, s.day);
  }

  DateTime _sessionPickerLastDate() {
    final e = _parsed!.sessionEnd;
    return DateTime(e.year, e.month, e.day);
  }

  SessionTerm? _termById(String id) {
    for (final t in _terms) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<ParsedExtractedEvent> _breaksFor(String termId) =>
      _events.where((e) => e.isAcademicBreak && e.termId == termId).toList();

  List<ParsedExtractedEvent> get _holidays =>
      _events.where((e) => !e.isAcademicBreak).toList();

  Future<void> _editTerm(SessionTerm term) async {
    if (_parsed == null) return;
    final first = _sessionPickerFirstDate();
    final last = _sessionPickerLastDate();

    final startPick = await showAppDatePicker(
      context: context,
      initialDate: startOfDay(term.start),
      firstDate: first,
      lastDate: last,
    );
    if (startPick == null || !mounted) return;
    final newStart = startOfDay(startPick);

    final endPick = await showAppDatePicker(
      context: context,
      initialDate: term.end.isBefore(newStart) ? newStart : term.end,
      firstDate: newStart,
      lastDate: last,
    );
    if (endPick == null || !mounted) return;
    final newEnd = endOfDayInclusive(endPick);

    setState(() {
      _terms = _terms
          .map(
            (t) => t.id != term.id
                ? t
                : SessionTerm(
                    id: t.id,
                    label: t.label,
                    start: newStart,
                    end: newEnd,
                  ),
          )
          .toList(growable: false);
    });
  }

  Future<void> _editParsedEventPeriod(
    ParsedExtractedEvent e, {
    required bool allowEditTitle,
  }) async {
    if (_parsed == null) return;
    final first = _sessionPickerFirstDate();
    final last = _sessionPickerLastDate();

    final result = await showModalBottomSheet<_EditAcademicPeriodResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _EditAcademicPeriodSheet(
        headerTitle: allowEditTitle ? 'Edit holiday' : 'Edit academic break',
        allowEditTitle: allowEditTitle,
        initialTitle: e.title,
        sessionFirst: first,
        sessionLast: last,
        initialStart: e.startDateTime,
        initialEnd: e.endDateTime,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (allowEditTitle) {
        final t = result.title.trim();
        e.title = t.isEmpty ? e.title : t;
      }
      e.startDateTime = startOfDay(result.start);
      e.endDateTime = endOfDayInclusive(result.end);
    });
  }

  void _removeHoliday(ParsedExtractedEvent e) {
    setState(() {
      _events.remove(e);
    });
  }

  Future<void> _addHoliday() async {
    if (_parsed == null) return;
    final today = DateTime.now();
    final first = _sessionPickerFirstDate();
    final last = _sessionPickerLastDate();

    final result = await showModalBottomSheet<_EditAcademicPeriodResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _EditAcademicPeriodSheet(
        headerTitle: 'Add holiday',
        allowEditTitle: true,
        initialTitle: '',
        sessionFirst: first,
        sessionLast: last,
        initialStart: today,
        initialEnd: today,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _events.add(
        ParsedExtractedEvent(
          title: result.title.trim(),
          startDateTime: startOfDay(result.start),
          endDateTime: endOfDayInclusive(result.end),
          allDay: true,
          hideClassesDuringEvent: true,
          isAcademicBreak: false,
          termId: 'sem1',
        ),
      );
    });
  }

  Future<void> _saveCalendar() async {
    if (_parsed == null || _terms.isEmpty) return;
    setState(() => _saving = true);
    try {
      final earliest =
          _terms.map((t) => t.start).reduce((a, b) => a.isBefore(b) ? a : b);
      final latest =
          _terms.map((t) => t.end).reduce((a, b) => a.isAfter(b) ? a : b);

      final session = AcademicSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _parsed!.sessionName,
        startDate: startOfDay(earliest),
        endDate: endOfDayInclusive(latest),
        terms: _terms,
      );

      final exactMatch = _findExactDateMatch(session);
      var saveMode = _SaveMode.addNew;
      AcademicSession targetSession = session;
      if (exactMatch != null) {
        final action = await _askExactSessionAction(exactMatch);
        if (!mounted || action == _ExactSessionAction.cancel) return;
        if (action == _ExactSessionAction.replace) {
          saveMode = _SaveMode.replace;
          targetSession = AcademicSession(
            id: exactMatch.id,
            name: session.name,
            startDate: session.startDate,
            endDate: session.endDate,
            terms: session.terms,
          );
        } else if (action == _ExactSessionAction.mergeIntoExisting) {
          saveMode = _SaveMode.merge;
          targetSession = exactMatch;
        }
      }

      final overlaps = _findOverlappingSessions(
        targetSession,
        excludeSessionId: saveMode == _SaveMode.replace ? targetSession.id : null,
      );
      if (overlaps.isNotEmpty) {
        final proceed = await _confirmOverlapWarning(overlaps);
        if (!mounted || !proceed) return;
      }

      if (saveMode == _SaveMode.replace) {
        await updateAcademicSession(
          targetSession,
          seedAcademicBreakEvents: false,
        );
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await CascadeCleanup.deleteEventsForSessionId(uid, targetSession.id);
        }
      } else {
        await addAcademicSession(
          targetSession,
          seedAcademicBreakEvents: false,
          allowDuplicateSignature: exactMatch != null,
        );
      }

      final existingMergeEvents = <AcademicEvent>[];
      if (saveMode == _SaveMode.merge) {
        for (final existing in academicEventsNotifier.value) {
          if (existing.sessionId != targetSession.id) continue;
          existingMergeEvents.add(existing);
        }
      }

      var mergedAdded = 0;
      var mergedSkipped = 0;
      for (final e in _events) {
        if (saveMode == _SaveMode.merge &&
            _isDuplicateForMerge(e, existingMergeEvents)) {
          mergedSkipped += 1;
          continue;
        }
        await addAcademicEvent(
          AcademicEvent(
            id: '',
            sessionId: targetSession.id,
            termId: e.termId,
            title: e.title,
            startDateTime: e.startDateTime,
            endDateTime: e.endDateTime,
            allDay: e.allDay,
            hideClassesDuringEvent: e.hideClassesDuringEvent,
            isAcademicBreak: e.isAcademicBreak,
            location: e.location,
          ),
        );
        if (saveMode == _SaveMode.merge) {
          existingMergeEvents.add(
            AcademicEvent(
              id: '',
              sessionId: targetSession.id,
              termId: e.termId,
              title: e.title,
              startDateTime: e.startDateTime,
              endDateTime: e.endDateTime,
              allDay: e.allDay,
              hideClassesDuringEvent: e.hideClassesDuringEvent,
              isAcademicBreak: e.isAcademicBreak,
              location: e.location,
            ),
          );
          mergedAdded += 1;
        }
      }

      dismissExtractionJobCard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveMode == _SaveMode.replace
                ? 'Calendar replaced'
                : saveMode == _SaveMode.merge
                    ? 'Merge complete: $mergedAdded added, $mergedSkipped skipped'
                    : 'Calendar saved',
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parsed == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Extracted Calendar')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Could not read extracted calendar data.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final holidayCount = _holidays.length;
    final pageTitle = switch (_pageIndex) {
      0 => 'Semester 1',
      1 => 'Semester 2',
      _ => 'Public holidays',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Extracted Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review what ClassMate detected and edit if needed before saving.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Session ${_parsed!.sessionName}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(pageTitle, style: textTheme.titleMedium),
                if (_pageIndex == 2) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$holidayCount public holiday${holidayCount == 1 ? '' : 's'} extracted',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [
                _SemesterStructurePage(
                  term: _termById('sem1'),
                  breaks: _breaksFor('sem1'),
                  onEditTerm: _editTerm,
                  onEditBreak: (e) =>
                      _editParsedEventPeriod(e, allowEditTitle: false),
                ),
                _SemesterStructurePage(
                  term: _termById('sem2'),
                  breaks: _breaksFor('sem2'),
                  onEditTerm: _editTerm,
                  onEditBreak: (e) =>
                      _editParsedEventPeriod(e, allowEditTitle: false),
                ),
                _HolidaysPage(
                  holidays: _holidays,
                  onEdit: (e) =>
                      _editParsedEventPeriod(e, allowEditTitle: true),
                  onDelete: _removeHoliday,
                  onAdd: _addHoliday,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i == _pageIndex;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 10 : 8,
                      height: active ? 10 : 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? appPrimarySwatch.shade700
                            : Colors.grey.shade400,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_pageIndex < 2) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                              );
                            } else {
                              _saveCalendar();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: appPrimarySwatch.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _pageIndex < 2 ? 'Next' : 'Save calendar',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterStructurePage extends StatelessWidget {
  const _SemesterStructurePage({
    required this.term,
    required this.breaks,
    required this.onEditTerm,
    required this.onEditBreak,
  });

  final SessionTerm? term;
  final List<ParsedExtractedEvent> breaks;
  final void Function(SessionTerm term) onEditTerm;
  final void Function(ParsedExtractedEvent e) onEditBreak;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (term == null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'No semester window was found for this section. You can still adjust holidays on the next screens.',
                style:
                    textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
            )
          else
            _PeriodTile(
              label: term!.label,
              rangeText:
                  '${formatDateDdMmYyyy(term!.start)} – ${formatDateDdMmYyyy(term!.end)}',
              onTap: () => onEditTerm(term!),
            ),
          ...breaks.map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _PeriodTile(
                label: e.title,
                rangeText:
                    '${formatDateDdMmYyyy(e.startDateTime)} – ${formatDateDdMmYyyy(e.endDateTime)}',
                onTap: () => onEditBreak(e),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.label,
    required this.rangeText,
    required this.onTap,
  });

  final String label;
  final String rangeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return WhiteCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  rangeText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HolidaysPage extends StatelessWidget {
  const _HolidaysPage({
    required this.holidays,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final List<ParsedExtractedEvent> holidays;
  final void Function(ParsedExtractedEvent e) onEdit;
  final void Function(ParsedExtractedEvent e) onDelete;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...holidays.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16),
                        ),
                        onTap: () => onEdit(e),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatDateDdMmYyyy(e.startDateTime)} – ${formatDateDdMmYyyy(e.endDateTime)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.red.shade700),
                        onPressed: () => onDelete(e),
                        tooltip: 'Remove',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppOutlinedIconButton(
            onPressed: () => onAdd(),
            icon: const Icon(Icons.add),
            label: const Text('Add holiday'),
          ),
        ],
      ),
    );
  }
}

class _EditAcademicPeriodResult {
  const _EditAcademicPeriodResult({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  final DateTime end;
}

class _EditAcademicPeriodSheet extends StatefulWidget {
  const _EditAcademicPeriodSheet({
    required this.headerTitle,
    required this.allowEditTitle,
    required this.initialTitle,
    required this.sessionFirst,
    required this.sessionLast,
    required this.initialStart,
    required this.initialEnd,
  });

  final String headerTitle;
  final bool allowEditTitle;
  final String initialTitle;
  final DateTime sessionFirst;
  final DateTime sessionLast;
  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_EditAcademicPeriodSheet> createState() =>
      _EditAcademicPeriodSheetState();
}

class _EditAcademicPeriodSheetState extends State<_EditAcademicPeriodSheet> {
  late final TextEditingController _titleCtrl;
  late DateTime _start;
  late DateTime _end;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _start = startOfDay(widget.initialStart);
    _end = startOfDay(widget.initialEnd);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final r = await showAppDatePicker(
      context: context,
      initialDate: _start,
      firstDate: widget.sessionFirst,
      lastDate: widget.sessionLast,
    );
    if (r == null || !mounted) return;
    setState(() {
      _start = startOfDay(r);
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final r = await showAppDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: widget.sessionLast,
    );
    if (r == null || !mounted) return;
    setState(() => _end = startOfDay(r));
  }

  void _save() {
    if (widget.allowEditTitle && _titleCtrl.text.trim().isEmpty) {
      setState(() => _titleError = 'Name cannot be empty');
      return;
    }

    Navigator.pop(
      context,
      _EditAcademicPeriodResult(
        title: _titleCtrl.text,
        start: _start,
        end: _end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.headerTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledTextField(
                label:
                    widget.allowEditTitle ? 'Holiday name' : 'Academic break',
                hintText: widget.allowEditTitle ? 'Enter name' : '',
                controller: _titleCtrl,
                enabled: widget.allowEditTitle,
                errorText: _titleError,
                onChanged: (value) {
                  if (_titleError == null) return;
                  if (value.trim().isNotEmpty) {
                    setState(() => _titleError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TapField(
                      label: 'Start date',
                      value: formatDateDdMmYyyy(_start),
                      onTap: _pickStart,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TapField(
                      label: 'End date',
                      value: formatDateDdMmYyyy(_end),
                      onTap: _pickEnd,
                      hintText: 'Select date',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: appPrimarySwatch.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
