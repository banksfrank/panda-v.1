import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAiConfig {
  const OpenAiConfig();

  static const apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');

  static Uri get _uri => Uri.parse(endpoint);

  Future<String> chat({required List<Map<String, Object?>> messages, String model = 'gpt-4o-mini', double temperature = 0.7}) async {
    if (apiKey.isEmpty || endpoint.isEmpty) {
      throw StateError('OpenAI proxy environment variables are missing.');
    }

    final body = <String, Object?>{
      'model': model,
      'temperature': temperature,
      'messages': messages,
    };

    try {
      final resp = await http
          .post(
            _uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      final decodedBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('OpenAI error ${resp.statusCode}: $decodedBody');
        throw StateError('OpenAI request failed (${resp.statusCode}).');
      }

      final json = jsonDecode(decodedBody) as Map<String, dynamic>;
      final choices = (json['choices'] as List?) ?? const [];
      if (choices.isEmpty) throw StateError('OpenAI returned no choices.');
      final msg = choices.first as Map<String, dynamic>;
      final message = msg['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.trim().isEmpty) throw StateError('OpenAI returned empty content.');
      return content.trim();
    } catch (e) {
      debugPrint('OpenAI chat failed: $e');
      rethrow;
    }
  }
}
