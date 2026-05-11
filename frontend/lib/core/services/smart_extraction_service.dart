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

  Map<String, dynamic> _body(
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
      extractTask(
    String text,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_apiBaseUrl/api/extract/task-text',
        ),
        headers: {
          'Content-Type':
              'application/json',
        },
        body: jsonEncode(
          {
            ..._body(text)
          },
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?>
      extractClass(
    String text,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_apiBaseUrl/api/extract/timetable-text',
        ),
        headers: {
          'Content-Type':
              'application/json',
        },
        body: jsonEncode(
          _body(text),
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?>
      extractEvent(
    String text,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_apiBaseUrl/api/extract/event-text',
        ),
        headers: {
          'Content-Type':
              'application/json',
        },
        body: jsonEncode(
          _body(text),
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }
}