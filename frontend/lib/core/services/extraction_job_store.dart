import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../utils/extraction_user_messages.dart';

enum ExtractionJobStatus { queued, running, success, failed }

class ExtractionJobState {
  const ExtractionJobState({
    required this.typeLabel,
    required this.fileCount,
    required this.apiPath,
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
  /// Path under `/api/` (no leading slash), e.g. `gemini/calendar`.
  final String apiPath;
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
      apiPath: apiPath,
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

String _normApiPath(String raw) {
  var s = raw.trim();
  if (s.startsWith('/api/')) s = s.substring(5);
  if (s.startsWith('api/')) s = s.substring(4);
  while (s.startsWith('/')) {
    s = s.substring(1);
  }
  return s;
}

String _baseUrl(String apiBaseUrl) => apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

/// Runs a multipart extraction against `POST /api/{apiPath}` (Gemini routes).
///
/// Previously this used `/extract/submit/...` + polling so long docling runs
/// would not block an HTTP worker. Gemini extraction is handled in-process with
/// its own timeout; a single long-lived request is simpler and matches the
/// `/gemini/...` API surface.
Future<void> startExtractionJob({
  required String apiBaseUrl,
  required String apiPath,
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

  final path = _normApiPath(apiPath);

  _extractionCancelled = false;
  final client = http.Client();
  _activeExtractionClient = client;

  extractionJobNotifier.value = ExtractionJobState(
    typeLabel: typeLabel,
    fileCount: files.length,
    apiPath: path,
    status: ExtractionJobStatus.queued,
    startedAt: DateTime.now(),
    message: 'Queued',
    assignedCourseCode: assignedCourseCode,
    sessionId: sessionId,
    termId: termId,
  );

  final uri = Uri.parse('${_baseUrl(apiBaseUrl)}/api/$path');
  final req = http.MultipartRequest('POST', uri);
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
    final streamed = await client
        .send(req)
        .timeout(const Duration(seconds: 300));
    final res = await http.Response.fromStream(streamed);
    if (_extractionCancelled) {
      return;
    }

    final now = DateTime.now();
    final startedAt = extractionJobNotifier.value?.startedAt ?? now;
    final durationMs = now.difference(startedAt).inMilliseconds;
    final body = res.body;

    if (res.statusCode < 200 || res.statusCode >= 300) {
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.failed,
        finishedAt: now,
        statusCode: res.statusCode,
        message: friendlyExtractionErrorMessage(
          technicalMessage: 'HTTP ${res.statusCode}',
          responseBody: body,
          httpStatusCode: res.statusCode,
        ),
        responseBody: body,
        durationMs: durationMs,
      );
      return;
    }

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.failed,
        finishedAt: now,
        statusCode: res.statusCode,
        message: friendlyExtractionErrorMessage(
          technicalMessage: 'Invalid JSON response',
          responseBody: body,
        ),
        responseBody: body,
        durationMs: durationMs,
      );
      return;
    }

    if (decoded == null) {
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.failed,
        finishedAt: now,
        message: friendlyExtractionErrorMessage(technicalMessage: 'Empty response'),
        responseBody: body,
        durationMs: durationMs,
      );
      return;
    }

    final statusField = (decoded['status'] as String?)?.trim().toLowerCase();
    if (statusField != null && statusField.isNotEmpty && statusField != 'ok') {
      final warnings = decoded['warnings'];
      String? firstWarning;
      if (warnings is List && warnings.isNotEmpty) {
        firstWarning = warnings.first?.toString().trim();
      }
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.failed,
        finishedAt: now,
        statusCode: res.statusCode,
        message: friendlyExtractionErrorMessage(
          technicalMessage: firstWarning ?? statusField,
          responseBody: body,
        ),
        responseBody: body,
        durationMs: durationMs,
      );
      return;
    }

    final warnings = decoded['warnings'] as List<dynamic>? ?? const [];
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

    debugPrint(
      '[extract] Completed path=$path duration_ms=$durationMs warnings=${warningTexts.length}',
    );

    extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
      status: ExtractionJobStatus.success,
      finishedAt: now,
      statusCode: res.statusCode,
      message: hasMemoryLikeWarnings ? 'Completed with warnings' : 'Completed',
      responseBody: body,
      hasWarnings: hasMemoryLikeWarnings,
      warningMessage: hasMemoryLikeWarnings
          ? 'Some pages could not be processed due to memory limits, but partial results were extracted.'
          : null,
      durationMs: durationMs,
    );
  } on TimeoutException catch (_) {
    if (_extractionCancelled) {
      return;
    }
    extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
      status: ExtractionJobStatus.failed,
      finishedAt: DateTime.now(),
      message: friendlyExtractionErrorMessage(technicalMessage: 'timeout'),
      responseBody: null,
    );
  } catch (e) {
    if (_extractionCancelled) {
      return;
    }
    extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
      status: ExtractionJobStatus.failed,
      finishedAt: DateTime.now(),
      message: friendlyExtractionErrorMessage(technicalMessage: e.toString()),
      responseBody: e.toString(),
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
