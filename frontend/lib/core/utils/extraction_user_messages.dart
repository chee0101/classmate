import 'dart:convert';

/// Short, user-facing text for extraction failures (HTTP or in-app).
String friendlyExtractionErrorMessage({
  String? technicalMessage,
  String? responseBody,
  int? httpStatusCode,
}) {
  final raw = (technicalMessage ?? '').trim();
  final body = (responseBody ?? '').trim();
  final combined = '$raw\n$body'.toLowerCase();

  if (combined.contains('std::bad_alloc') ||
      combined.contains('out of memory') ||
      combined.contains('memory')) {
    return 'The file is too large or complex to process right now. '
        'Try a smaller file, lower-quality PDF or image, or fewer pages.';
  }
  if (combined.contains('413') || combined.contains('exceeds max size')) {
    return 'This file is too large to upload. Please choose a smaller file.';
  }
  if (combined.contains('timeout') ||
      combined.contains('timed out') ||
      combined.contains('connection') ||
      combined.contains('socketexception')) {
    return 'Connection issue while extracting. Please check your network and try again.';
  }
  if (combined.contains('service unavailable') ||
      combined.contains('temporarily unavailable') ||
      combined.contains('503') ||
      combined.contains('resource_exhausted') ||
      combined.contains('try again later') ||
      combined.contains('429')) {
    return 'The AI service is temporarily unavailable. Please try again shortly.';
  }
  if (combined.contains('validation_error') ||
      combined.contains('validationerror') ||
      combined.contains('field required') ||
      combined.contains('json decode')) {
    return 'We could not read a clear schedule from this file. Try a clearer photo or a different export.';
  }
  if (combined.contains('500') ||
      combined.contains('internal server error') ||
      combined.contains('preprocess failed')) {
    return 'We could not process this file. Please try again with a clearer file.';
  }
  if (combined.contains('400') ||
      combined.contains('no file uploaded') ||
      combined.contains('empty file') ||
      combined.contains('must be provided')) {
    return 'The request could not be sent correctly. Please choose your files again and retry.';
  }

  final fromHttp = _tryFastApiDetail(body);
  if (fromHttp != null && fromHttp.trim().isNotEmpty) {
    return _truncateSingleLine(fromHttp, 200);
  }

  if (raw.isNotEmpty) {
    return 'Extraction failed. ${_truncateSingleLine(raw, 160)}';
  }
  if (httpStatusCode != null) {
    return 'Extraction failed (HTTP $httpStatusCode). Please try again.';
  }
  return 'Extraction failed. Please try again.';
}

String? _tryFastApiDetail(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        final parts = <String>[];
        for (final item in detail) {
          if (item is Map<String, dynamic>) {
            final msg = item['msg']?.toString();
            if (msg != null && msg.isNotEmpty) parts.add(msg);
          } else {
            parts.add(item.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join('; ');
      }
    }
  } catch (_) {}
  return null;
}

String _truncateSingleLine(String s, int maxChars) {
  final oneLine = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (oneLine.length <= maxChars) return oneLine;
  return '${oneLine.substring(0, maxChars)}…';
}
