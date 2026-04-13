import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/extraction_job_store.dart';
import '../../core/widgets/common/app_outlined_icon_button.dart';
import '../../core/widgets/common/animated_segmented_switch.dart';
import '../../core/widgets/common/form_fields.dart';
import '../../core/widgets/common/white_card.dart';

enum AutoExtractType { academicCalendar, timetable, task }

class AutoExtractScreen extends StatefulWidget {
  const AutoExtractScreen({super.key});

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

  final TextEditingController _remarkFilterController = TextEditingController();
  List<PlatformFile> _selectedFiles = const [];

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
        return 'Upload a document to extract tasks/assignments.';
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
      allowMultiple: _type == AutoExtractType.academicCalendar,
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
    await _notImplementedYet('Scan from camera');
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

    unawaited(
      startExtractionJob(
        apiBaseUrl: _apiBaseUrl,
        endpoint: endpoint,
        typeLabel: typeLabel,
        files: _selectedFiles,
        useMultiFilesField: _type == AutoExtractType.academicCalendar,
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

