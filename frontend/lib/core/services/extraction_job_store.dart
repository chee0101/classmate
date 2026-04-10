import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ExtractionJobStatus { queued, running, success, failed }

class ExtractionJobState {
  const ExtractionJobState({
    required this.typeLabel,
    required this.fileCount,
    required this.endpoint,
    required this.status,
    required this.startedAt,
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

  bool get isRunning =>
      status == ExtractionJobStatus.queued || status == ExtractionJobStatus.running;

  ExtractionJobState copyWith({
    ExtractionJobStatus? status,
    DateTime? finishedAt,
    int? statusCode,
    String? message,
    String? responseBody,
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
  );

  final uri = Uri.parse('$apiBaseUrl$endpoint');
  final req = http.MultipartRequest('POST', uri);
  final fileField = useMultiFilesField ? 'files' : 'file';

  for (final file in files) {
    req.files.add(await _toMultipartFile(fileField, file));
  }

  extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
    status: ExtractionJobStatus.running,
    message: 'Processing',
  );

  try {
    final streamed = await client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (_extractionCancelled) {
      return;
    }
    final now = DateTime.now();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
        status: ExtractionJobStatus.success,
        finishedAt: now,
        statusCode: res.statusCode,
        message: 'Completed',
        responseBody: res.body,
      );
      return;
    }
    extractionJobNotifier.value = extractionJobNotifier.value?.copyWith(
      status: ExtractionJobStatus.failed,
      finishedAt: now,
      statusCode: res.statusCode,
      message: 'Failed (${res.statusCode})',
      responseBody: res.body,
    );
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

