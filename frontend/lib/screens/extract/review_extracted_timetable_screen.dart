import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/course.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/services/class_slot_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/extraction_job_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/timetable_extraction_json.dart';
import '../../core/widgets/add/class_form.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/extract/timetable_save_mode_sheet.dart';
import '../../core/widgets/schedule/class_slot_sheet.dart';
import '../../core/widgets/timetable/timetable_course_card.dart';
import '../schedule/class_slot_editor_screen.dart';

enum _TimetableImportMode { merge, replace }

class ReviewExtractedTimetableScreen extends StatefulWidget {
  const ReviewExtractedTimetableScreen({
    super.key,
    required this.responseJson,
    this.sessionId,
    this.termId,
  });

  final String responseJson;
  final String? sessionId;
  final String? termId;

  @override
  State<ReviewExtractedTimetableScreen> createState() =>
      _ReviewExtractedTimetableScreenState();
}

class _ReviewExtractedTimetableScreenState
    extends State<ReviewExtractedTimetableScreen> {
  ParsedTimetableExtraction? _parsed;
  bool _saving = false;
  bool _showSaveBarShadow = false;
  final Map<String, List<TimetableSlot>> _editableByCourse = {};
  final Set<String> _selectedCourseCodes = <String>{};
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _parsed = parseTimetableExtractionJson(widget.responseJson);
    if (_parsed != null) {
      for (final entry in _parsed!.slotsByCourseCode.entries) {
        _editableByCourse[entry.key] = entry.value
            .map(
              (s) => TimetableSlot(
                classSlotId: s.classSlotId,
                day: s.day,
                startTime: s.startTime,
                endTime: s.endTime,
                mode: s.mode,
                classType: s.classType,
                venue: s.venue,
              ),
            )
            .toList(growable: true);
        _selectedCourseCodes.add(entry.key);
      }
    }
    _contentScrollController.addListener(_updateSaveBarShadow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSaveBarShadow());
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_updateSaveBarShadow);
    _contentScrollController.dispose();
    super.dispose();
  }

  void _updateSaveBarShadow() {
    if (!_contentScrollController.hasClients) return;
    final position = _contentScrollController.position;
    final shouldShow = position.maxScrollExtent > 1;
    if (shouldShow == _showSaveBarShadow) return;
    setState(() => _showSaveBarShadow = shouldShow);
  }

  Color _parseCourseColorHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return const Color(0xFF6C4DD9);
    final parsed = int.tryParse(hex.trim().replaceFirst('#', '0xFF'));
    return Color(parsed ?? 0xFF6C4DD9);
  }

  List<ClassSlotDraft> _toDrafts(List<TimetableSlot> slots) {
    return slots
        .map(
          (s) => ClassSlotDraft(
            classSlotId: s.classSlotId.isEmpty ? null : s.classSlotId,
            day: s.day,
            startTime: s.startTime,
            endTime: s.endTime,
            mode: s.mode,
            classType: s.classType,
            venue: s.venue,
          ),
        )
        .toList(growable: true);
  }

  TimetableSlot _fromDraft(ClassSlotDraft d) {
    return TimetableSlot(
      classSlotId: d.classSlotId ?? '',
      day: d.day,
      startTime: d.startTime,
      endTime: d.endTime,
      mode: d.mode,
      classType: d.classType,
      venue: d.venue,
    );
  }

  Future<void> _openCourseEditor(String courseCode) async {
    final current = _editableByCourse[courseCode] ?? const <TimetableSlot>[];
    final edited = await showModalBottomSheet<List<ClassSlotDraft>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReviewCourseSlotsSheet(
        courseCode: courseCode,
        initialSlots: _toDrafts(current),
      ),
    );
    if (edited == null) return;
    setState(() {
      _editableByCourse[courseCode] =
          edited.map(_fromDraft).toList(growable: false);
      if (_editableByCourse[courseCode]!.isEmpty) {
        _selectedCourseCodes.remove(courseCode);
      } else {
        _selectedCourseCodes.add(courseCode);
      }
    });
  }

  Future<void> _save({
    required String sessionId,
    required String termId,
    required _TimetableImportMode mode,
  }) async {
    final parsed = _parsed;
    if (parsed == null || _selectedCourseCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: mode == _TimetableImportMode.replace
          ? 'Replace timetables?'
          : 'Merge timetables?',
      message: mode == _TimetableImportMode.replace
          ? 'Existing class slots for each imported course will be removed and replaced.'
          : 'New slots will be added; duplicates are skipped.',
      confirmText: 'Save',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    var saved = 0;
    var skipped = 0;
    var selectedCount = 0;

    try {
      for (final code in _selectedCourseCodes) {
        final incoming = _editableByCourse[code] ?? const <TimetableSlot>[];
        if (incoming.isEmpty) continue;
        selectedCount++;
        final courseId = await findCourseIdBySessionTermCode(
          uid: user.uid,
          sessionId: sessionId,
          termId: termId,
          normalizedCourseCode: code,
        );
        if (courseId == null) {
          skipped++;
          continue;
        }

        if (mode == _TimetableImportMode.replace) {
          await deleteTimetableEntry(courseId);
          await upsertTimetableByCourse(
            sessionId: sessionId,
            termId: termId,
            courseCode: code,
            slots: incoming,
          );
          saved++;
          continue;
        }

        TimetableEntry? existing;
        for (final e in timetablesNotifier.value) {
          if (e.sessionId == sessionId &&
              e.termId == termId &&
              e.id == courseId) {
            existing = e;
            break;
          }
        }
        final merged = mergeTimetableSlots(
          existing?.slots ?? const [],
          incoming,
        );
        await upsertTimetableByCourse(
          sessionId: sessionId,
          termId: termId,
          courseCode: code,
          slots: merged,
        );
        saved++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved $saved / $selectedCount selected course(s)'
            '${skipped > 0 ? '; skipped $skipped (no matching course)' : ''}.',
          ),
        ),
      );
      dismissExtractionJobCard();
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_TimetableImportMode?> _pickSaveMode() async {
    final action = await showModalBottomSheet<TimetableSaveModeAction>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TimetableSaveModeSheet(),
    );
    return switch (action) {
      TimetableSaveModeAction.merge => _TimetableImportMode.merge,
      TimetableSaveModeAction.replace => _TimetableImportMode.replace,
      TimetableSaveModeAction.cancel || null => null,
    };
  }

  Future<void> _onSavePressed({
    required String sessionId,
    required String termId,
  }) async {
    final mode = await _pickSaveMode();
    if (!mounted || mode == null) return;
    if (mode == _TimetableImportMode.replace) {
      final destructiveConfirmed = await showConfirmDialog(
        context,
        title: 'Confirm replace',
        message:
            'This will overwrite existing class slots for selected courses. Continue?',
        confirmText: 'Yes, replace',
        destructive: true,
      );
      if (!destructiveConfirmed || !mounted) return;
    }
    await _save(
      sessionId: sessionId,
      termId: termId,
      mode: mode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final textTheme = Theme.of(context).textTheme;

    if (parsed == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review timetable')),
        body: const Center(child: Text('Could not read extraction data.')),
      );
    }

    final hasEditableSlots = _editableByCourse.values.any((s) => s.isNotEmpty);
    if (!hasEditableSlots || parsed.documentKind == 'unknown') {
      return Scaffold(
        appBar: AppBar(title: const Text('Review timetable')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No timetable slots were found.',
                style: textTheme.titleMedium,
              ),
              if (parsed.warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ...parsed.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text('• $w', style: textTheme.bodySmall),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final selected = selectedSessionTermNotifier.value;
    final selectedSessionId = widget.sessionId ?? selected?.sessionId;
    final selectedTermId = widget.termId ?? selected?.termId;
    if (selectedSessionId == null || selectedTermId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review timetable')),
        body: const Center(
          child: Text('Missing selected session/term from extraction.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review timetable'),
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
              AppSpacing.xs,
            ),
            child: Text(
              'Review what ClassMate detected and edit if needed before saving.',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Course>>(
              valueListenable: coursesNotifier,
              builder: (context, courses, _) {
                final termCourses = coursesForSessionAndTerm(
                  sessionId: selectedSessionId,
                  termId: selectedTermId,
                );
                final colorByCode = <String, Color>{
                  for (final c in termCourses)
                    c.courseCode.trim().toUpperCase(): _parseCourseColorHex(
                      c.courseColor,
                    ),
                };

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final shouldShow = notification.metrics.maxScrollExtent > 1;
                    if (shouldShow != _showSaveBarShadow) {
                      setState(() => _showSaveBarShadow = shouldShow);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _contentScrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _editableByCourse.length,
                    itemBuilder: (context, index) {
                      final code = _editableByCourse.keys.elementAt(index);
                      final slots =
                          _editableByCourse[code] ?? const <TimetableSlot>[];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                right: 0,
                              ),
                              child: Checkbox(
                                value: _selectedCourseCodes.contains(code),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedCourseCodes.add(code);
                                    } else {
                                      _selectedCourseCodes.remove(code);
                                    }
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: TimetableCourseCard(
                                courseCode: code,
                                slots: slots,
                                courseColor:
                                    colorByCode[code] ?? const Color(0xFF6C4DD9),
                                onTap: () => _openCourseEditor(code),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: _showSaveBarShadow
                  ? const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: Offset(0, -4),
                      ),
                    ]
                  : const [],
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : _selectedCourseCodes.isEmpty
                        ? null
                        : () => _onSavePressed(
                              sessionId: selectedSessionId,
                              termId: selectedTermId,
                            ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save to timetable'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCourseSlotsSheet extends StatefulWidget {
  const _ReviewCourseSlotsSheet({
    required this.courseCode,
    required this.initialSlots,
  });

  final String courseCode;
  final List<ClassSlotDraft> initialSlots;

  @override
  State<_ReviewCourseSlotsSheet> createState() => _ReviewCourseSlotsSheetState();
}

class _ReviewCourseSlotsSheetState extends State<_ReviewCourseSlotsSheet> {
  late List<ClassSlotDraft> _slots;

  @override
  void initState() {
    super.initState();
    _slots = widget.initialSlots
        .map(
          (s) => ClassSlotDraft(
            classSlotId: s.classSlotId,
            day: s.day,
            startTime: s.startTime,
            endTime: s.endTime,
            mode: s.mode,
            classType: s.classType,
            venue: s.venue,
          ),
        )
        .toList(growable: true);
  }

  Future<void> _addSlot() async {
    final added = await ClassSlotEditorScreen.show(context);
    if (added == null) return;
    setState(() => _slots.add(added));
  }

  Future<void> _editSlot(int index) async {
    final edited = await ClassSlotEditorScreen.show(
      context,
      initial: _slots[index],
    );
    if (edited == null) return;
    setState(() => _slots[index] = edited);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit ${widget.courseCode}',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Fix extracted slots before saving.',
              style: textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: AppSpacing.md),
            ClassForm(
              courseCodes: [widget.courseCode],
              selectedCourseCode: widget.courseCode,
              slots: _slots,
              slotsByCourse: {widget.courseCode: _slots},
              onCourseChanged: (_) {},
              onSlotsHydratedForCourse: (_) {},
              onAddSlot: _addSlot,
              onEditSlot: (slot) {
                final index = _slots.indexOf(slot);
                if (index >= 0) _editSlot(index);
              },
              onRemoveSlot: (slot) async {
                final confirmed = await showConfirmDeleteDialog(
                  context,
                  title: 'Delete class slot',
                  message:
                      'Delete ${slot.day} (${slot.startTime} – ${slot.endTime})?',
                );
                if (!confirmed || !mounted) return;
                setState(() => _slots.remove(slot));
              },
              onAddCourseRequested: () async => null,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_slots),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
