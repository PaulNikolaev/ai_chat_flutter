import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_chat/api/openrouter_client.dart';

void main() {
  group('OpenRouterClient logging', () {
    final defaultResponseBody = jsonEncode({
      'choices': [
        {
          'message': {'content': 'hello'}
        }
      ]
    });

    setUp(() {
      dotenv.testLoad(fileInput: ''); // reset env
    });

    test('debug logging is disabled by default', () async {
      final logs = <String?>[];
      final old = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message);
      };

      final client = OpenRouterClient(
        apiKey: 'sk-or-v1-test',
        baseUrl: 'https://api.test',
        provider: 'openrouter',
        httpClient: MockClient(
          (request) async => http.Response(defaultResponseBody, 200),
        ),
      );

      await client.sendMessage(message: 'user text', model: 'm1');

      debugPrint = old;

      // По умолчанию логируются только попытки/статусы, без user text и без JSON тела
      final joined = logs.whereType<String>().join('\n');
      expect(joined.contains('user text'), isFalse);
      expect(joined.contains('"event":"request_start"'), isFalse);
      expect(joined.contains('Response body'), isFalse);
    });

    test('debug logging enabled only when DEBUG, LOG_LEVEL=DEBUG and flag set',
        () async {
      final logs = <String?>[];
      final old = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message);
      };

      dotenv.testLoad(fileInput: '', mergeWith: {
        'DEBUG': 'true',
        'LOG_LEVEL': 'DEBUG',
        'DEBUG_LOG_HTTP': 'true',
      });

      final client = OpenRouterClient(
        apiKey: 'sk-or-v1-test',
        baseUrl: 'https://api.test',
        provider: 'openrouter',
        httpClient: MockClient(
          (request) async => http.Response(defaultResponseBody, 200),
        ),
      );

      await client.sendMessage(message: 'user text', model: 'm1');

      debugPrint = old;

      final joined = logs.whereType<String>().join('\n');
      // Логи есть, но текст пользователя не выводится
      expect(joined.isNotEmpty, isTrue);
      expect(joined.contains('user text'), isFalse);
      // Должен быть статус
      expect(joined.contains('Response received: 200'), isTrue);
    });
  });
}
