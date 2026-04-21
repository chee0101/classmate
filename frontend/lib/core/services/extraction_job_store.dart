import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum ExtractionJobStatus { queued, running, success, failed }

class ExtractionJobState {
  const ExtractionJobState({
    required this.typeLabel,
    required this.fileCount,
    required this.endpoint,
    required this.status,
    required this.startedAt,
    this.assignedCourseCode,
    this.sessionId,
    this.termId,
    this.hasWarnings = false,
    this.warningMessage,
    this.durationMs,
    this.finishedAt,
    this.statusCode,
    this.message,
    this.responseBody,
  });

  final String typeLabel;
  final int fileCount;
  final String endpoint;
  final ExtractionJobStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? statusCode;
  final String? message;
  final String? responseBody;
  final String? assignedCourseCode;
  /// When set (e.g. timetable import), review/save uses this session/term.
  final String? sessionId;
  final String? termId;
  final bool hasWarnings;
  final String? warningMessage;
  final int? durationMs;

  bool get isRunning =>
      status == ExtractionJobStatus.queued || status == ExtractionJobStatus.running;

  ExtractionJobState copyWith({
    ExtractionJobStatus? status,
    DateTime? finishedAt,
    int? statusCode,
    String? message,
    String? responseBody,
    String? assignedCourseCode,
    String? sessionId,
    String? termId,
    bool? hasWarnings,
    String? warningMessage,
    int? durationMs,
  }) {
    return ExtractionJobState(
      typeLabel: typeLabel,
      fileCount: fileCount,
      endpoint: endpoint,
      status: status ?? this.status,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      statusCode: statusCode ?? this.statusCode,
      message: message ?? this.message,
      responseBody: responseBody ?? this.responseBody,
      assignedCourseCode: assignedCourseCode ?? this.assignedCourseCode,
      sessionId: sessionId ?? this.sessionId,
      termId: termId ?? this.termId,
      hasWarnings: hasWarnings ?? this.hasWarnings,
      warningMessage: warningMessage ?? this.warningMessage,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

final ValueNotifier<ExtractionJobState?> extractionJobNotifier =
    ValueNotifier<ExtractionJobState?>(null);

http.Client? _activeExtractionClient;
bool _extractionCancelled = false;

bool get hasRunningExtractionJob => extractionJobNotifier.value?.isRunning ?? false;

/// Stops the in-flight HTTP request and clears the extraction card.
/// Call after the user confirms cancellation in the UI.
void cancelRunningExtractionJob() {
  if (!hasRunningExtractionJob) return;
  _extractionCancelled = true;
  _activeExtractionClient?.close();
  _activeExtractionClient = null;
  extractionJobNotifier.value = null;
}

Future<void> startExtractionJob({
  required String apiBaseUrl,
  required String endpoint,
  required String typeLabel,
  required List<PlatformFile> files,
  required bool useMultiFilesField,
  String? assignedCourseCode,
  /// Comma-separated course codes sent to backend whitelist (timetable).
  String? courseCodesAllowedCsv,
  String? aiNotes,
  String? sessionId,
  String? termId,
}) async {
  if (files.isEmpty) {
    throw StateError('No files selected.');
  }
  if (hasRunningExtractionJob) {
    throw StateError('Another extraction job is currently running.');
  }

  _extractionCancelled = false;
  final client = http.Client();
  _activeExtractionClient = client;

  extractionJobNotifier.value = ExtractionJobState(
    typeLabel: typeLabel,
    fileCount: files.length,
    endpoint: endpoint,
    status: ExtractionJobStatus.queued,
    startedAt: DateTime.now(),
    message: 'Queued',
    assignedCourseCode: assignedCourseCode,
    sessionId: sessionId,
    termId: termId,
  );

  final kind = endpoint.split('/').last;
  final submitUri = Uri.parse('$apiBaseUrl/api/extract/submit/$kind');
  final req = http.MultipartRequest('POST', submitUri);
  final fileField = useMultiFilesField ? 'files' : 'file';

  for (final file in files) {
    req.files.add(await _toMultipartFile(fileField, file));
  }

  final codes = (courseCodesAllowedCsv ?? '').trim();
  if (codes.isNotEmpty) {
    req.fields['course_codes_allowed'] = codes;
  }
  final notes = (aiNotes ?? '').trim();
  if (notes.isNotEmpty) {
    req.fields['ai_notes'] = notes;
  }

  extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
    status: ExtractionJobStatus.running,
    message: 'Processing',
  );

  try {
    final submitStreamed = await client.send(req);
    final submitRes = await http.Response.fromStream(submitStreamed);
    if (_extractionCancelled) {
      return;
    }
    if (submitRes.statusCode < 200 || submitRes.statusCode >= 300) {
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.failed,
        finishedAt: DateTime.now(),
        statusCode: submitRes.statusCode,
        message: 'Failed (${submitRes.statusCode})',
        responseBody: submitRes.body,
      );
      return;
    }
    final submitJson = jsonDecode(submitRes.body) as Map<String, dynamic>;
    final jobId = (submitJson['job_id'] as String?)?.trim();
    if (jobId == null || jobId.isEmpty) {
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.failed,
        finishedAt: DateTime.now(),
        message: 'Failed (missing job id)',
        responseBody: submitRes.body,
      );
      return;
    }
    while (!_extractionCancelled) {
      final pollUri = Uri.parse('$apiBaseUrl/api/extract/job/$jobId');
      final pollRes = await client.get(pollUri);
      if (_extractionCancelled) return;
      if (pollRes.statusCode < 200 || pollRes.statusCode >= 300) {
        extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
          status: ExtractionJobStatus.failed,
          finishedAt: DateTime.now(),
          statusCode: pollRes.statusCode,
          message: 'Failed polling (${pollRes.statusCode})',
          responseBody: pollRes.body,
        );
        return;
      }
      final pollJson = jsonDecode(pollRes.body) as Map<String, dynamic>;
      final status = (pollJson['status'] as String?)?.trim().toLowerCase() ?? '';
      if (status == 'queued' || status == 'running') {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      final now = DateTime.now();
      final startedAt = extractionJobNotifier.value?.startedAt ?? now;
      if (status == 'success') {
        final resultObj = pollJson['result'];
        final resultBody = resultObj == null ? '' : jsonEncode(resultObj);
        final warnings = switch (resultObj) {
          Map<String, dynamic> m => (m['warnings'] as List<dynamic>? ?? const []),
          _ => const <dynamic>[],
        };
        final warningTexts = warnings
            .map((w) => w.toString().trim())
            .where((w) => w.isNotEmpty)
            .toList(growable: false);
        final hasMemoryLikeWarnings = warningTexts.any(
          (w) {
            final t = w.toLowerCase();
            return t.contains('bad_alloc') ||
                t.contains('out of memory') ||
                t.contains('preprocess failed') ||
                t.contains('failed for run');
          },
        );
        final durationMs = pollJson['duration_ms'] is num
            ? (pollJson['duration_ms'] as num).round()
            : now.difference(startedAt).inMilliseconds;
        debugPrint(
          '[extract] Completed kind=$kind job_id=$jobId duration_ms=$durationMs warnings=${warningTexts.length}',
        );
        extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
          status: ExtractionJobStatus.success,
          finishedAt: now,
          statusCode: 200,
          message: hasMemoryLikeWarnings ? 'Completed with warnings' : 'Completed',
          responseBody: resultBody,
          hasWarnings: hasMemoryLikeWarnings,
          warningMessage: hasMemoryLikeWarnings
              ? 'Some pages could not be processed due to memory limits, but partial results were extracted.'
              : null,
          durationMs: durationMs,
        );
        return;
      }
      final error = (pollJson['error'] as String?) ?? 'Unknown job error';
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.failed,
        finishedAt: now,
        statusCode: 500,
        message: error,
        responseBody: error,
        durationMs: pollJson['duration_ms'] is num
            ? (pollJson['duration_ms'] as num).round()
            : now.difference(startedAt).inMilliseconds,
      );
      return;
    }
  } catch (e) {
    if (_extractionCancelled) {
      return;
    }
    extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
      status: ExtractionJobStatus.failed,
      finishedAt: DateTime.now(),
      message: 'Error: $e',
      responseBody: '$e',
    );
  } finally {
    _activeExtractionClient = null;
    client.close();
  }
}

void dismissExtractionJobCard() {
  if (hasRunningExtractionJob) return;
  extractionJobNotifier.value = null;
}

Future<http.MultipartFile> _toMultipartFile(String field, PlatformFile file) async {
  if (file.path != null) {
    return http.MultipartFile.fromPath(field, file.path!, filename: file.name);
  }
  final bytes = file.bytes;
  if (bytes == null) {
    throw StateError('Cannot read file bytes for ${file.name}.');
  }
  return http.MultipartFile.fromBytes(field, bytes, filename: file.name);
}

