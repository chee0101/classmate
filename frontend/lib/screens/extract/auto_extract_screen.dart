import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_cropper/image_cropper.dart';
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
import '../../core/widgets/add/add_course_dialog.dart';
import '../../core/widgets/home/session_header.dart';

import 'review_extracted_events_screen.dart';
import 'review_extracted_tasks_screen.dart';
import 'review_extracted_timetable_screen.dart';

import '../../core/services/smart_extraction_service.dart';

enum ExtractInputSource {
  upload,
  text,
}

enum TextExtractType {
  task,
  timetable,
  academicEvent,
}

enum AutoExtractType { academicCalendar, timetable, task }

class AutoExtractScreen extends StatefulWidget {
  const AutoExtractScreen({
    super.key,
    this.initialType,
    this.sessionOnly = false,
  });

  final AutoExtractType? initialType;
  final bool sessionOnly;

  @override
  State<AutoExtractScreen> createState() => _AutoExtractScreenState();
}

class _AutoExtractScreenState extends State<AutoExtractScreen> {
  static const int _maxUploadBytes = 15 * 1024 * 1024;

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

  SessionTermSelection? _resolvedSessionTermSelection() {
    final sessions = <AcademicSession>[...academicSessionsNotifier.value];
    final activeSession = currentAcademicSessionNotifier.value;
    if (activeSession != null &&
        !sessions.any((s) => s.id == activeSession.id)) {
      sessions.add(activeSession);
    }
    if (sessions.isEmpty) return null;
    final refs = buildAllSessionTermRefs(sessions);
    if (refs.isEmpty) return null;
    final current = selectedSessionTermNotifier.value;
    if (current != null &&
        refs.any(
          (r) =>
              r.session.id == current.sessionId && r.term.id == current.termId,
        )) {
      return current;
    }
    final fallback = resolveDefaultSessionTermRef(refs, DateTime.now());
    return SessionTermSelection(
      sessionId: fallback.session.id,
      termId: fallback.term.id,
    );
  }

  ExtractInputSource _inputSource = ExtractInputSource.upload;

  TextExtractType _textExtractType = TextExtractType.task;

  final _textController = TextEditingController();

  bool _isTextExtracting = false;

  List<String> _selectedTermCourseCodes() {
    final selection = _resolvedSessionTermSelection();

    if (selection == null) {
      return [];
    }

    return coursesForSessionAndTerm(
      sessionId: selection.sessionId,
      termId: selection.termId,
    )
        .map(
          (c) => c.courseCode.trim().toUpperCase(),
        )
        .where(
          (c) => c.isNotEmpty,
        )
        .toList()
      ..sort();
  }

  Future<void> _extractFromText() async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isTextExtracting = true;
    });

    try {
      final service = SmartExtractionService();

      /// =========================
      /// TASK
      /// =========================

      if (_textExtractType == TextExtractType.task) {
        final result = await service.extractTask(
          text,
        );

        if (result == null) {
          throw Exception(
            'Task extraction failed.',
          );
        }

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewExtractedTasksScreen(
              responseJson: jsonEncode(result),
            ),
          ),
        );
      }

      /// =========================
      /// TIMETABLE
      /// =========================

      else if (_textExtractType == TextExtractType.timetable) {
        final result = await service.extractClass(
          text,
        );

        if (result == null) {
          throw Exception(
            'Timetable extraction failed.',
          );
        }

        final selection = _resolvedSessionTermSelection();

        if (selection == null) {
          throw Exception(
            'Please select a valid session and term first.',
          );
        }

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewExtractedTimetableScreen(
              responseJson: jsonEncode(result),
              sessionId: selection.sessionId,
              termId: selection.termId,
            ),
          ),
        );
      }

      /// =========================
      /// ACADEMIC EVENT
      /// =========================

      else {
        final result = await service.extractEvent(
          text,
        );

        if (result == null) {
          throw Exception(
            'Event extraction failed.',
          );
        }

        final selection = _resolvedSessionTermSelection();

        if (selection == null) {
          throw Exception(
            'Please select a valid session and term first.',
          );
        }

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewExtractedEventsScreen(
              responseJson: jsonEncode(result),
              sessionId: selection.sessionId,
              termId: selection.termId,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

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
          _isTextExtracting = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.sessionOnly) {
      // Force it to upload and academic calendar if sessionOnly is true
      _type = AutoExtractType.academicCalendar;
      _inputSource = ExtractInputSource.upload;
    } else {
      _type = widget.initialType ?? AutoExtractType.academicCalendar;
    }
  }

  @override
  void dispose() {
    // _remarkFilterController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String get _dynamicDescription {
    if (_inputSource == ExtractInputSource.upload) {
      switch (_type) {
        case AutoExtractType.academicCalendar:
          if (widget.sessionOnly) {
            return 'No academic session found. Please set up an academic session to extract timetables.';
          }
          return 'Upload academic calendar documents or screenshots.';

        case AutoExtractType.timetable:
          return 'Upload timetable documents or screenshots.';

        case AutoExtractType.task:
          return 'Upload task documents or screenshots.';
      }
    }

    switch (_textExtractType) {
      case TextExtractType.task:
        return 'Describe tasks naturally for AI extraction.';

      case TextExtractType.timetable:
        return 'Describe class schedules naturally for AI extraction.';

      case TextExtractType.academicEvent:
        return 'Describe academic events naturally for AI extraction.';
    }
  }

  void _handleTypeChanged(AutoExtractType nextType) {
    if (_type == nextType) return;
    setState(() {
      _type = nextType;
      _selectedFiles = const [];
      _taskAssignedCourseCode = null;
    });
  }

  void _removeSelectedFileAt(int index) {
    if (index < 0 || index >= _selectedFiles.length) return;
    setState(() {
      final updated = [..._selectedFiles]..removeAt(index);
      _selectedFiles = updated;
    });
  }

  String get _maxUploadLabelMb =>
      (_maxUploadBytes / (1024 * 1024)).toStringAsFixed(0);

  Future<void> _showUploadSizeExceededMessage(List<String> fileNames) async {
    if (!mounted) return;
    final firstName = fileNames.first;
    final hasMore = fileNames.length > 1;
    final detail = hasMore
        ? '$firstName and ${fileNames.length - 1} more file(s)'
        : firstName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Skipped $detail. Max file size is ${_maxUploadLabelMb}MB.',
        ),
      ),
    );
  }

  Future<void> _notImplementedYet(String feature) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not implemented yet.')),
    );
  }

  Future<void> _handleChooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    final accepted = <PlatformFile>[];
    final rejectedNames = <String>[];
    for (final file in result.files) {
      if (file.size > _maxUploadBytes) {
        rejectedNames.add(file.name);
        continue;
      }
      accepted.add(file);
    }
    if (accepted.isEmpty) {
      await _showUploadSizeExceededMessage(rejectedNames);
      return;
    }
    setState(() {
      _selectedFiles = [..._selectedFiles, ...accepted];
    });
    if (rejectedNames.isNotEmpty) {
      await _showUploadSizeExceededMessage(rejectedNames);
    }
  }

  Future<void> _handleScanFromCamera() async {
    try {
      final colorScheme = Theme.of(context).colorScheme;
      final captured = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (captured == null) return;

      CroppedFile? cropped;
      try {
        cropped = await ImageCropper().cropImage(
          sourcePath: captured.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop image',
              toolbarColor: colorScheme.primary,
              toolbarWidgetColor: colorScheme.onPrimary,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop image',
              aspectRatioLockEnabled: false,
            ),
          ],
        );
      } catch (_) {
        cropped = null;
      }

      final imagePath = cropped?.path ?? captured.path;
      final bytes = await File(imagePath).readAsBytes();
      final fileName = captured.name.trim().isEmpty
          ? 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : captured.name;
      final platformFile = PlatformFile(
        name: fileName,
        size: bytes.length,
        bytes: bytes,
        path: imagePath,
      );
      if (platformFile.size > _maxUploadBytes) {
        await _showUploadSizeExceededMessage([platformFile.name]);
        return;
      }

      setState(() {
        _selectedFiles = [..._selectedFiles, platformFile];
      });
    } on FileSystemException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the captured photo.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Camera capture failed. Please try again.')),
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

    final apiPath = switch (_type) {
      AutoExtractType.academicCalendar => 'gemini/calendar',
      AutoExtractType.timetable => 'gemini/timetable',
      AutoExtractType.task => 'gemini/task',
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
      final sel = _resolvedSessionTermSelection();
      if (sel != null && selectedSessionTermNotifier.value == null) {
        setSelectedSessionTerm(sessionId: sel.sessionId, termId: sel.termId);
      }
      sessionId = sel?.sessionId;
      termId = sel?.termId;
      if (sel == null) {
        await _notImplementedYet('Please select a valid session/term first');
        return;
      }
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
      if (codes.isEmpty) {
        await _notImplementedYet(
          'No courses found for selected session/term. Add courses first.',
        );
        return;
      }
      final remark = _remarkFilterController.text.trim();
      if (remark.isNotEmpty) aiNotes = remark;
    }

    unawaited(
      startExtractionJob(
        apiBaseUrl: _apiBaseUrl,
        apiPath: apiPath,
        typeLabel: typeLabel,
        files: _selectedFiles,
        useMultiFilesField: true,
        assignedCourseCode:
            _type == AutoExtractType.task ? _taskAssignedCourseCode : null,
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
                  if (widget.sessionOnly) ...[
                    Text(
                      'Session Setup',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (!widget.sessionOnly) ...[
                    Text(
                      'Input Method',
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(
                      height: AppSpacing.sm,
                    ),
                    AnimatedSegmentedSwitch<ExtractInputSource>(
                      options: const [
                        SegmentedSwitchOption(
                          value: ExtractInputSource.upload,
                          label: 'Upload',
                        ),
                        SegmentedSwitchOption(
                          value: ExtractInputSource.text,
                          label: 'Text',
                        ),
                      ],
                      value: _inputSource,
                      onChanged: (value) {
                        setState(() {
                          _inputSource = value;
                        });
                      },
                    ),
                  ],
                  Text(
                    _dynamicDescription,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (!widget.sessionOnly) ...[
                  const SizedBox(height: AppSpacing.sm),
                    _inputSource == ExtractInputSource.upload
                        ? _ExtractTypeTabs(
                            value: _type,
                            onChanged: _isAnalyzing ? null : _handleTypeChanged,
                          )
                        : _TextExtractTypeTabs(
                            selected: _textExtractType,
                            onChanged: (value) {
                              setState(() {
                                _textExtractType = value;
                              });
                            },
                          ),
                  ],
                  if (_inputSource == ExtractInputSource.upload &&
                      _type == AutoExtractType.timetable) ...[
                    const SizedBox(height: AppSpacing.md),
                    ValueListenableBuilder<List<AcademicSession>>(
                      valueListenable: academicSessionsNotifier,
                      builder: (context, sessionsList, _) {
                        return ValueListenableBuilder<AcademicSession?>(
                          valueListenable: currentAcademicSessionNotifier,
                          builder: (context, activeSession, __) {
                            return ValueListenableBuilder<
                                SessionTermSelection?>(
                              valueListenable: selectedSessionTermNotifier,
                              builder: (context, selectedSelection, ___) {
                                final sessions = <AcademicSession>[
                                  ...sessionsList
                                ];
                                if (activeSession != null &&
                                    !sessions
                                        .any((s) => s.id == activeSession.id)) {
                                  sessions.add(activeSession);
                                }
                                if (sessions.isEmpty) {
                                  return Text(
                                    'Add an academic session and courses first.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.black54,
                                    ),
                                  );
                                }

                                final allTermRefs =
                                    buildAllSessionTermRefs(sessions);
                                if (allTermRefs.isEmpty)
                                  return const SizedBox.shrink();
                                final resolvedDefaultRef =
                                    resolveDefaultSessionTermRef(
                                  allTermRefs,
                                  DateTime.now(),
                                );
                                var selectedSessionId =
                                    selectedSelection?.sessionId ??
                                        resolvedDefaultRef.session.id;
                                var selectedTermId =
                                    selectedSelection?.termId ??
                                        resolvedDefaultRef.term.id;
                                final isValidSelection = allTermRefs.any(
                                  (ref) =>
                                      ref.session.id == selectedSessionId &&
                                      ref.term.id == selectedTermId,
                                );
                                if (!isValidSelection) {
                                  selectedSessionId =
                                      resolvedDefaultRef.session.id;
                                  selectedTermId = resolvedDefaultRef.term.id;
                                }
                                if (selectedSelection == null ||
                                    selectedSelection.sessionId !=
                                        selectedSessionId ||
                                    selectedSelection.termId !=
                                        selectedTermId) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    setSelectedSessionTerm(
                                      sessionId: selectedSessionId,
                                      termId: selectedTermId,
                                    );
                                  });
                                }

                                return ValueListenableBuilder<List<Course>>(
                                  valueListenable: coursesNotifier,
                                  builder: (context, _, __) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ValueListenableBuilder<
                                            List<AcademicSession>>(
                                          valueListenable:
                                              academicSessionsNotifier,
                                          builder: (context, sessionsList, _) {
                                            return ValueListenableBuilder<
                                                AcademicSession?>(
                                              valueListenable:
                                                  currentAcademicSessionNotifier,
                                              builder:
                                                  (context, activeSession, __) {
                                                return ValueListenableBuilder<
                                                    SessionTermSelection?>(
                                                  valueListenable:
                                                      selectedSessionTermNotifier,
                                                  builder: (context,
                                                      selectedSelection, ___) {
                                                    final sessions =
                                                        <AcademicSession>[
                                                      ...sessionsList
                                                    ];

                                                    if (activeSession != null &&
                                                        !sessions.any((s) =>
                                                            s.id ==
                                                            activeSession.id)) {
                                                      sessions
                                                          .add(activeSession);
                                                    }

                                                    if (sessions.isEmpty) {
                                                      return Text(
                                                        'Add an academic session and courses first.',
                                                        style: textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                          color: Colors.black54,
                                                        ),
                                                      );
                                                    }

                                                    final allTermRefs =
                                                        buildAllSessionTermRefs(
                                                            sessions);
                                                    if (allTermRefs.isEmpty)
                                                      return const SizedBox
                                                          .shrink();

                                                    final resolvedDefaultRef =
                                                        resolveDefaultSessionTermRef(
                                                      allTermRefs,
                                                      DateTime.now(),
                                                    );

                                                    var selectedSessionId =
                                                        selectedSelection
                                                                ?.sessionId ??
                                                            resolvedDefaultRef
                                                                .session.id;

                                                    var selectedTermId =
                                                        selectedSelection
                                                                ?.termId ??
                                                            resolvedDefaultRef
                                                                .term.id;

                                                    final isValidSelection =
                                                        allTermRefs.any(
                                                      (ref) =>
                                                          ref.session.id ==
                                                              selectedSessionId &&
                                                          ref.term.id ==
                                                              selectedTermId,
                                                    );

                                                    if (!isValidSelection) {
                                                      selectedSessionId =
                                                          resolvedDefaultRef
                                                              .session.id;
                                                      selectedTermId =
                                                          resolvedDefaultRef
                                                              .term.id;
                                                    }

                                                    if (selectedSelection ==
                                                            null ||
                                                        selectedSelection
                                                                .sessionId !=
                                                            selectedSessionId ||
                                                        selectedSelection
                                                                .termId !=
                                                            selectedTermId) {
                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback(
                                                              (_) {
                                                        setSelectedSessionTerm(
                                                          sessionId:
                                                              selectedSessionId,
                                                          termId:
                                                              selectedTermId,
                                                        );
                                                      });
                                                    }

                                                    return ValueListenableBuilder<
                                                        List<Course>>(
                                                      valueListenable:
                                                          coursesNotifier,
                                                      builder:
                                                          (context, _, __) {
                                                        final courseCodes =
                                                            coursesForSessionAndTerm(
                                                          sessionId:
                                                              selectedSessionId,
                                                          termId:
                                                              selectedTermId,
                                                        )
                                                                .map((c) => c
                                                                    .courseCode
                                                                    .trim()
                                                                    .toUpperCase())
                                                                .where((c) => c
                                                                    .isNotEmpty)
                                                                .toList(
                                                                    growable:
                                                                        false)
                                                              ..sort();

                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            /// 🔹 Session Selector
                                                            SessionHeader(
                                                              sessions:
                                                                  sessions,
                                                              selectedSessionId:
                                                                  selectedSessionId,
                                                              selectedTermId:
                                                                  selectedTermId,
                                                              onSelectionChanged:
                                                                  (sessionId,
                                                                      termId) {
                                                                setSelectedSessionTerm(
                                                                  sessionId:
                                                                      sessionId,
                                                                  termId:
                                                                      termId,
                                                                );
                                                              },
                                                            ),
                                                            const SizedBox(
                                                                height:
                                                                    AppSpacing
                                                                        .md),
                                                            WhiteCard(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .fromLTRB(
                                                                      AppSpacing
                                                                          .md,
                                                                      0,
                                                                      AppSpacing
                                                                          .md,
                                                                      AppSpacing
                                                                          .md),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  /// Header row
                                                                  Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          'Courses to extract',
                                                                          style:
                                                                              textTheme.titleSmall,
                                                                        ),
                                                                      ),
                                                                      TextButton
                                                                          .icon(
                                                                        onPressed:
                                                                            () async {
                                                                          await CourseDialog
                                                                              .show(
                                                                            context,
                                                                            sessionId:
                                                                                selectedSessionId,
                                                                            termId:
                                                                                selectedTermId,
                                                                          );
                                                                        },
                                                                        icon: const Icon(
                                                                            Icons
                                                                                .add,
                                                                            size:
                                                                                16),
                                                                        label: const Text(
                                                                            'Add course',
                                                                            style:
                                                                                TextStyle(fontSize: 14)),
                                                                      ),
                                                                    ],
                                                                  ),

                                                                  /// Empty state
                                                                  if (courseCodes
                                                                      .isEmpty)
                                                                    Text(
                                                                      'No courses added yet.',
                                                                      style: textTheme
                                                                          .bodySmall
                                                                          ?.copyWith(
                                                                        color: Colors
                                                                            .black54,
                                                                      ),
                                                                    )
                                                                  else
                                                                    Wrap(
                                                                      spacing:
                                                                          AppSpacing
                                                                              .sm,
                                                                      children: [
                                                                        for (final code
                                                                            in courseCodes)
                                                                          Chip(
                                                                            label:
                                                                                Text(
                                                                              code,
                                                                              style: textTheme.bodySmall,
                                                                            ),
                                                                            visualDensity:
                                                                                VisualDensity.compact,
                                                                          ),
                                                                      ],
                                                                    ),
                                                                ],
                                                              ),
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
                  if (_inputSource == ExtractInputSource.upload &&
                      _type == AutoExtractType.task) ...[
                    const SizedBox(height: AppSpacing.md),
                    ValueListenableBuilder<List<AcademicSession>>(
                      valueListenable: academicSessionsNotifier,
                      builder: (context, sessionsList, _) {
                        return ValueListenableBuilder<AcademicSession?>(
                          valueListenable: currentAcademicSessionNotifier,
                          builder: (context, activeSession, __) {
                            return ValueListenableBuilder<
                                SessionTermSelection?>(
                              valueListenable: selectedSessionTermNotifier,
                              builder: (context, selectedSelection, ___) {
                                final sessions = <AcademicSession>[
                                  ...sessionsList
                                ];
                                if (activeSession != null &&
                                    !sessions
                                        .any((s) => s.id == activeSession.id)) {
                                  sessions.add(activeSession);
                                }
                                if (sessions.isEmpty)
                                  return const SizedBox.shrink();

                                final allTermRefs =
                                    buildAllSessionTermRefs(sessions);
                                if (allTermRefs.isEmpty)
                                  return const SizedBox.shrink();

                                final resolvedDefaultRef =
                                    resolveDefaultSessionTermRef(
                                  allTermRefs,
                                  DateTime.now(),
                                );
                                var selectedSessionId =
                                    selectedSelection?.sessionId ??
                                        resolvedDefaultRef.session.id;
                                var selectedTermId =
                                    selectedSelection?.termId ??
                                        resolvedDefaultRef.term.id;

                                final isValidSelection = allTermRefs.any(
                                  (ref) =>
                                      ref.session.id == selectedSessionId &&
                                      ref.term.id == selectedTermId,
                                );
                                if (!isValidSelection) {
                                  selectedSessionId =
                                      resolvedDefaultRef.session.id;
                                  selectedTermId = resolvedDefaultRef.term.id;
                                }

                                // Keep the global selection valid so downstream task save
                                // resolves course IDs in the intended session/term.
                                if (selectedSelection == null ||
                                    selectedSelection.sessionId !=
                                        selectedSessionId ||
                                    selectedSelection.termId !=
                                        selectedTermId) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
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
                                        .map((c) =>
                                            c.courseCode.trim().toUpperCase())
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
                                                courseCodes.contains(
                                                    normalizedSelected)
                                            ? normalizedSelected
                                            : null;
                                    final dropdownValue =
                                        effectiveSelected ?? autoValue;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SessionHeader(
                                          sessions: sessions,
                                          selectedSessionId: selectedSessionId,
                                          selectedTermId: selectedTermId,
                                          onSelectionChanged:
                                              (sessionId, termId) {
                                            setSelectedSessionTerm(
                                              sessionId: sessionId,
                                              termId: termId,
                                            );
                                            setState(() =>
                                                _taskAssignedCourseCode = null);
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
                                                (code) =>
                                                    DropdownMenuEntry<String>(
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
                  if (_inputSource == ExtractInputSource.upload) ...[
                    const SizedBox(height: AppSpacing.md),
                    WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upload Method', style: textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: AppOutlinedIconButton(
                                  expand: false,
                                  onPressed:
                                      _isAnalyzing ? null : _handleChooseFile,
                                  icon: const Icon(Icons.upload_file_outlined),
                                  label: const Text('File',
                                      style: TextStyle(fontSize: 14)),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppOutlinedIconButton(
                                  expand: false,
                                  onPressed: _isAnalyzing
                                      ? null
                                      : _handleScanFromCamera,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Camera',
                                      style: TextStyle(fontSize: 14)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Supported formats: PDF, DOCX, PNG, JPEG',
                            style: textTheme.bodySmall
                                ?.copyWith(color: Colors.black45),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Max file size: ${_maxUploadLabelMb}MB',
                            style: textTheme.bodySmall
                                ?.copyWith(color: Colors.black45),
                          ),
                          if (_selectedFiles.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Selected file(s)',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              children: [
                                for (var i = 0; i < _selectedFiles.length; i++)
                                  Chip(
                                    label: Text(
                                      _selectedFiles[i].name,
                                      style: textTheme.bodySmall,
                                    ),
                                    onDeleted: _isAnalyzing
                                        ? null
                                        : () => _removeSelectedFileAt(i),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 16),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  ],
                  if (_inputSource == ExtractInputSource.text) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildTextExtractSection(),
                  ],
                  if (_inputSource == ExtractInputSource.upload &&
                      _type == AutoExtractType.timetable) ...[
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
                      style:
                          textTheme.bodySmall?.copyWith(color: Colors.black45),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 14,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
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
                  onPressed: _inputSource == ExtractInputSource.upload
                      ? (_isAnalyzing ? null : _handleContinue)
                      : (_isTextExtracting ? null : _extractFromText),
                  child: (_inputSource == ExtractInputSource.upload
                          ? _isAnalyzing
                          : _isTextExtracting)
                      ? const _AnalyzingInline()
                      : const Text('Extract'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextExtractSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSessionSelector(),
        const SizedBox(
          height: AppSpacing.md,
        ),
        TextField(
          controller: _textController,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: _textHintText,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionSelector() {
    return ValueListenableBuilder<List<AcademicSession>>(
      valueListenable: academicSessionsNotifier,
      builder: (context, sessionsList, _) {
        return ValueListenableBuilder<AcademicSession?>(
          valueListenable: currentAcademicSessionNotifier,
          builder: (context, activeSession, __) {
            return ValueListenableBuilder<SessionTermSelection?>(
              valueListenable: selectedSessionTermNotifier,
              builder: (
                context,
                selectedSelection,
                ___,
              ) {
                final sessions = <AcademicSession>[
                  ...sessionsList,
                ];

                if (activeSession != null &&
                    !sessions.any(
                      (s) => s.id == activeSession.id,
                    )) {
                  sessions.add(
                    activeSession,
                  );
                }

                if (sessions.isEmpty) {
                  return const SizedBox.shrink();
                }

                final allTermRefs = buildAllSessionTermRefs(
                  sessions,
                );

                if (allTermRefs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final resolvedDefaultRef = resolveDefaultSessionTermRef(
                  allTermRefs,
                  DateTime.now(),
                );

                var selectedSessionId = selectedSelection?.sessionId ??
                    resolvedDefaultRef.session.id;

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

                return SessionHeader(
                  sessions: sessions,
                  selectedSessionId: selectedSessionId,
                  selectedTermId: selectedTermId,
                  onSelectionChanged: (
                    sessionId,
                    termId,
                  ) {
                    setSelectedSessionTerm(
                      sessionId: sessionId,
                      termId: termId,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String get _textHintText {
    switch (_textExtractType) {
      case TextExtractType.task:
        return 'Example:\n\n'
            'CAT404 Assignment 2 due next Friday 11:59PM';

      case TextExtractType.timetable:
        return 'Example:\n\n'
            'CSC404 Monday 10AM - 12PM DK G31 Lecture';

      case TextExtractType.academicEvent:
        return 'Example:\n\n'
            'Labour day next week Monday';
    }
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

class _TextExtractTypeTabs extends StatelessWidget {
  const _TextExtractTypeTabs({
    required this.selected,
    required this.onChanged,
  });

  final TextExtractType selected;

  final ValueChanged<TextExtractType> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extract Type', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSegmentedSwitch<TextExtractType>(
          options: const [
            SegmentedSwitchOption(
              value: TextExtractType.task,
              label: 'Task',
            ),
            SegmentedSwitchOption(
              value: TextExtractType.timetable,
              label: 'Timetable',
            ),
            SegmentedSwitchOption(
              value: TextExtractType.academicEvent,
              label: 'Event',
            ),
          ],
          value: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
