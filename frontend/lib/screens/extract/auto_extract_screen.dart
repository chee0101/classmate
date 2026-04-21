import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/academic_session.dart';
import '../../core/models/course.dart';
import '../../core/services/academic_session_store.dart';
import '../../core/services/course_store.dart';
import '../../core/services/extraction_job_store.dart';
import '../../core/services/session_term_selection_store.dart';
import '../../core/utils/session_term_resolver.dart';
import '../../core/widgets/common/app_outlined_icon_button.dart';
import '../../core/widgets/common/animated_segmented_switch.dart';
import '../../core/widgets/common/form_fields.dart';
import '../../core/widgets/common/white_card.dart';
import '../../core/widgets/home/session_header.dart';

enum AutoExtractType { academicCalendar, timetable, task }

class AutoExtractScreen extends StatefulWidget {
  const AutoExtractScreen({
    super.key,
    this.initialType,
  });

  final AutoExtractType? initialType;

  @override
  State<AutoExtractScreen> createState() => _AutoExtractScreenState();
}

class _AutoExtractScreenState extends State<AutoExtractScreen> {
  // Preferred: .env -> API_BASE_URL=http://your-ip:8000
  // Fallback: flutter run --dart-define=API_BASE_URL=http://your-ip:8000
  String get _apiBaseUrl {
    final fromEnv = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment('API_BASE_URL').trim();
  }

  AutoExtractType _type = AutoExtractType.academicCalendar;
  bool _isAnalyzing = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Optional: if user picks one course, we auto-fill empty extracted course codes.
  String? _taskAssignedCourseCode;

  final TextEditingController _remarkFilterController = TextEditingController();
  List<PlatformFile> _selectedFiles = const [];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? AutoExtractType.academicCalendar;
  }

  @override
  void dispose() {
    _remarkFilterController.dispose();
    super.dispose();
  }

  String get _title {
    switch (_type) {
      case AutoExtractType.academicCalendar:
        return 'Academic calendar';
      case AutoExtractType.timetable:
        return 'Timetable';
      case AutoExtractType.task:
        return 'Task';
    }
  }

  String get _subtitle {
    switch (_type) {
      case AutoExtractType.academicCalendar:
        return 'Upload your academic calendar document or screenshots.';
      case AutoExtractType.timetable:
        return 'Upload your timetable document or screenshots.';
      case AutoExtractType.task:
        return 'Upload task documents or screenshots.';
    }
  }

  Future<void> _notImplementedYet(String feature) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not implemented yet.')),
    );
  }

  Future<void> _handleChooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: _type != AutoExtractType.timetable,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedFiles = result.files;
    });
  }

  Future<void> _handleScanFromCamera() async {
    try {
      final captured = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (captured == null) return;

      final bytes = await captured.readAsBytes();
      final fileName = captured.name.trim().isEmpty
          ? 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : captured.name;
      final platformFile = PlatformFile(
        name: fileName,
        size: bytes.length,
        bytes: bytes,
        path: captured.path,
      );

      setState(() {
        if (_type != AutoExtractType.timetable) {
          _selectedFiles = [..._selectedFiles, platformFile];
        } else {
          _selectedFiles = [platformFile];
        }
      });
    } on FileSystemException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the captured photo.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera capture failed. Please try again.')),
      );
    }
  }

  Future<void> _handleContinue() async {
    if (_apiBaseUrl.trim().isEmpty) {
      await _notImplementedYet(
        'Missing API_BASE_URL. Run with --dart-define=API_BASE_URL=http://your-ip:8000',
      );
      return;
    }

    if (_selectedFiles.isEmpty) {
      await _notImplementedYet('Please choose a file first');
      return;
    }

    if (hasRunningExtractionJob) {
      await _notImplementedYet('Another extraction is already running');
      return;
    }

    final endpoint = switch (_type) {
      AutoExtractType.academicCalendar => '/api/extract/academic-calendar',
      AutoExtractType.timetable => '/api/extract/timetable',
      AutoExtractType.task => '/api/extract/task',
    };
    final typeLabel = switch (_type) {
      AutoExtractType.academicCalendar => 'Academic calendar',
      AutoExtractType.timetable => 'Timetable',
      AutoExtractType.task => 'Task',
    };

    String? courseCodesAllowedCsv;
    String? aiNotes;
    String? sessionId;
    String? termId;
    if (_type == AutoExtractType.timetable) {
      final sel = selectedSessionTermNotifier.value;
      sessionId = sel?.sessionId;
      termId = sel?.termId;
      if (sel != null) {
        final codes = coursesForSessionAndTerm(
              sessionId: sel.sessionId,
              termId: sel.termId,
            )
            .map((c) => c.courseCode.trim().toUpperCase())
            .where((c) => c.isNotEmpty)
            .toList()
          ..sort();
        if (codes.isNotEmpty) {
          courseCodesAllowedCsv = codes.join(', ');
        }
      }
      final remark = _remarkFilterController.text.trim();
      if (remark.isNotEmpty) aiNotes = remark;
    }

    unawaited(
      startExtractionJob(
        apiBaseUrl: _apiBaseUrl,
        endpoint: endpoint,
        typeLabel: typeLabel,
        files: _selectedFiles,
        useMultiFilesField: _type != AutoExtractType.timetable,
        assignedCourseCode: _type == AutoExtractType.task
            ? _taskAssignedCourseCode
            : null,
        courseCodesAllowedCsv: courseCodesAllowedCsv,
        aiNotes: aiNotes,
        sessionId: sessionId,
        termId: termId,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Extract'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              _subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ExtractTypeTabs(
              value: _type,
              onChanged: _isAnalyzing ? null : (v) => setState(() => _type = v),
            ),
            if (_type == AutoExtractType.task) ...[
              const SizedBox(height: AppSpacing.md),
              ValueListenableBuilder<List<AcademicSession>>(
                valueListenable: academicSessionsNotifier,
                builder: (context, sessionsList, _) {
                  return ValueListenableBuilder<AcademicSession?>(
                    valueListenable: currentAcademicSessionNotifier,
                    builder: (context, activeSession, __) {
                      return ValueListenableBuilder<SessionTermSelection?>(
                        valueListenable: selectedSessionTermNotifier,
                        builder: (context, selectedSelection, ___) {
                          final sessions = <AcademicSession>[...sessionsList];
                          if (activeSession != null &&
                              !sessions.any((s) => s.id == activeSession.id)) {
                            sessions.add(activeSession);
                          }
                          if (sessions.isEmpty) return const SizedBox.shrink();

                          final allTermRefs = buildAllSessionTermRefs(sessions);
                          if (allTermRefs.isEmpty) return const SizedBox.shrink();

                          final resolvedDefaultRef = resolveDefaultSessionTermRef(
                            allTermRefs,
                            DateTime.now(),
                          );
                          var selectedSessionId =
                              selectedSelection?.sessionId ?? resolvedDefaultRef.session.id;
                          var selectedTermId =
                              selectedSelection?.termId ?? resolvedDefaultRef.term.id;

                          final isValidSelection = allTermRefs.any(
                            (ref) =>
                                ref.session.id == selectedSessionId &&
                                ref.term.id == selectedTermId,
                          );
                          if (!isValidSelection) {
                            selectedSessionId = resolvedDefaultRef.session.id;
                            selectedTermId = resolvedDefaultRef.term.id;
                          }

                          // Keep the global selection valid so downstream task save
                          // resolves course IDs in the intended session/term.
                          if (selectedSelection == null ||
                              selectedSelection.sessionId != selectedSessionId ||
                              selectedSelection.termId != selectedTermId) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setSelectedSessionTerm(
                                sessionId: selectedSessionId,
                                termId: selectedTermId,
                              );
                            });
                          }

                          return ValueListenableBuilder<List<Course>>(
                            valueListenable: coursesNotifier,
                            builder: (context, _, __) {
                              final termCourses =
                                  coursesForSessionAndTerm(
                                sessionId: selectedSessionId,
                                termId: selectedTermId,
                              );
                              final courseCodes = termCourses
                                .map((c) => c.courseCode.trim().toUpperCase())
                                .where((c) => c.isNotEmpty)
                                .toList(growable: false)
                              ..sort();

                              const autoValue = '__auto__';
                              final normalizedSelected =
                                  _taskAssignedCourseCode
                                      ?.trim()
                                      .toUpperCase();
                              final effectiveSelected =
                                  normalizedSelected != null &&
                                          courseCodes.contains(normalizedSelected)
                                      ? normalizedSelected
                                      : null;
                              final dropdownValue =
                                  effectiveSelected ?? autoValue;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SessionHeader(
                                    sessions: sessions,
                                    selectedSessionId: selectedSessionId,
                                    selectedTermId: selectedTermId,
                                    onSelectionChanged: (sessionId, termId) {
                                      setSelectedSessionTerm(
                                        sessionId: sessionId,
                                        termId: termId,
                                      );
                                      setState(() => _taskAssignedCourseCode = null);
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (courseCodes.isNotEmpty)
                                    DropdownField<String>(
                                      label:
                                          'Assign extracted tasks to course (optional)',
                                      showLabel: true,
                                      hintText: 'Select course code',
                                      value: dropdownValue,
                                      items: [
                                        const DropdownMenuEntry<String>(
                                          value: autoValue,
                                          label:
                                              'Auto (use extracted course codes)',
                                        ),
                                        ...courseCodes.map(
                                          (code) => DropdownMenuEntry<String>(
                                            value: code,
                                            label: code,
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (!mounted) return;
                                        setState(() {
                                          _taskAssignedCourseCode =
                                              (value == autoValue)
                                                  ? null
                                                  : value;
                                        });
                                      },
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            WhiteCard(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _handleChooseFile,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Choose file'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Supported formats: PDF, DOCX, PNG, JPEG',
                    style: textTheme.bodySmall?.copyWith(color: Colors.black45),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Max file size: 10MB',
                    style: textTheme.bodySmall?.copyWith(color: Colors.black45),
                  ),
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Selected file(s): ${_selectedFiles.map((f) => f.name).join(', ')}',
                      style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppOutlinedIconButton(
              onPressed: _isAnalyzing ? null : _handleScanFromCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Scan from camera'),
            ),
                  if (_type == AutoExtractType.timetable) ...[
                    const SizedBox(height: AppSpacing.md),
                    LabeledTextField(
                      label: 'Remark filter (optional)',
                      hintText: 'e.g. Group 1, Slot B, Tutorial A',
                      controller: _remarkFilterController,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Only keep classes whose remarks contain this text (case-insensitive).',
                      style: textTheme.bodySmall?.copyWith(color: Colors.black45),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _handleContinue,
                child: _isAnalyzing
                    ? const _AnalyzingInline()
                    : Text('Continue ($_title)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingInline extends StatelessWidget {
  const _AnalyzingInline();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Analyzing...'),
        ],
      ),
    );
  }
}

class _ExtractTypeTabs extends StatelessWidget {
  const _ExtractTypeTabs({
    required this.value,
    required this.onChanged,
  });

  final AutoExtractType value;
  final ValueChanged<AutoExtractType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extract Type', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSegmentedSwitch<AutoExtractType>(
          options: const [
            SegmentedSwitchOption(
              value: AutoExtractType.academicCalendar,
              label: 'Session',
            ),
            SegmentedSwitchOption(
              value: AutoExtractType.timetable,
              label: 'Timetable',
            ),
            SegmentedSwitchOption(
              value: AutoExtractType.task,
              label: 'Task',
            ),
          ],
          value: value,
          onChanged: onChanged ?? (_) {},
        ),
      ],
    );
  }
}

