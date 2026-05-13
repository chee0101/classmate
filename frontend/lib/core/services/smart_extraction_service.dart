import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SmartExtractionService {
  String get _apiBaseUrl {
    final fromEnv =
        (dotenv.env['API_BASE_URL'] ?? '')
            .trim();

    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    return const String.fromEnvironment(
      'API_BASE_URL',
    ).trim();
  }

  Map<String, String> _fields(
    String text,
  ) {
    return {
      'text': text,
      'current_datetime':
          DateTime.now()
              .toIso8601String(),
    };
  }

  Future<Map<String, dynamic>?>
      _postMultipart({
    required String endpoint,
    required Map<String, String>
    fields,
  }) async {
    try {
      final request =
          http.MultipartRequest(
            'POST',
            Uri.parse(
              '$_apiBaseUrl/api$endpoint',
            ),
          );

      request.fields.addAll(fields);

      final streamed =
          await request.send();

      final response =
          await http.Response.fromStream(
            streamed,
          );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final status = (decoded['status'] as String?)?.trim().toLowerCase();
      if (status != null && status.isNotEmpty && status != 'ok') {
        return null;
      }
      return decoded;

    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?>
      extractTask(
    String text,
  ) async {
    return _postMultipart(
      endpoint: '/gemini/task',
      fields: _fields(text),
    );
  }

  Future<Map<String, dynamic>?>
      extractClass(
    String text,
  ) async {
    return _postMultipart(
      endpoint: '/gemini/timetable',
      fields: _fields(text),
    );
  }

  Future<Map<String, dynamic>?>
      extractEvent(
    String text,
  ) async {
    return _postMultipart(
      endpoint: '/gemini/event',
      fields: _fields(text),
    );
  }
}