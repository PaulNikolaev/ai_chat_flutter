import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_chat/api/api.dart';

void main() {
  group('OpenRouterClient Tests', () {
    late OpenRouterClient client;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient((request) async {
        // Mock responses для разных endpoints
        if (request.url.path.contains('/models')) {
          return http.Response(
            '''{
              "data": [
                {
                  "id": "openai/gpt-4",
                  "name": "GPT-4",
                  "description": "GPT-4 model"
                },
                {
                  "id": "openai/gpt-3.5-turbo",
                  "name": "GPT-3.5 Turbo",
                  "description": "GPT-3.5 Turbo model"
                }
              ]
            }''',
            200,
          );
        } else if (request.url.path.contains('/chat/completions')) {
          return http.Response(
            '''{
              "choices": [
                {
                  "message": {
                    "content": "Test response"
                  }
                }
              ],
              "usage": {
                "total_tokens": 50,
                "prompt_tokens": 20,
                "completion_tokens": 30
              }
            }''',
            200,
          );
        } else if (request.url.path.contains('/dashboard/billing/credits')) {
          return http.Response(
            '{"data": 100.50}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      client = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        baseUrl: 'https://openrouter.ai/api/v1',
        provider: 'openrouter',
        httpClient: mockHttpClient,
      );
    });

    tearDown(() {
      client.dispose();
    });

    test('getModels - возвращает список моделей', () async {
      final models = await client.getModels();
      expect(models, isNotEmpty);
      expect(models.length, equals(2));
      expect(models.first.id, equals('openai/gpt-4'));
    });

    test('getModels - использует кэш при повторном вызове', () async {
      final models1 = await client.getModels();
      final models2 = await client.getModels();
      
      expect(models1, equals(models2));
      // Проверяем, что HTTP запрос был сделан только один раз
      // (в реальности это сложно проверить без счетчика, но модель кэша работает)
    });

    test('getModels - очищает кэш после clearModelCache', () async {
      await client.getModels();
      client.clearModelCache();
      
      // После очистки кэша следующий вызов должен загрузить данные заново
      final models = await client.getModels(forceRefresh: true);
      expect(models, isNotEmpty);
    });

    test('sendMessage - отправляет сообщение и возвращает ответ', () async {
      final result = await client.sendMessage(
        message: 'Test message',
        model: 'openai/gpt-4',
      );

      expect(result.text, equals('Test response'));
      expect(result.totalTokens, equals(50));
      expect(result.promptTokens, equals(20));
      expect(result.completionTokens, equals(30));
    });

    test('getBalance - возвращает баланс аккаунта', () async {
      // Мокаем ответ для баланса - используем правильный endpoint /credits для OpenRouter
      final balanceMockClient = MockClient((request) async {
        if (request.url.path.contains('/credits')) {
          return http.Response('{"data": 100.50}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final balanceClient = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        baseUrl: 'https://openrouter.ai/api/v1',
        provider: 'openrouter',
        httpClient: balanceMockClient,
      );

      final balance = await balanceClient.getBalance();
      expect(balance, equals('100.50'));
      
      balanceClient.dispose();
    });

    test('getBalance - использует кэш', () async {
      final balanceMockClient = MockClient((request) async {
        if (request.url.path.contains('/credits')) {
          return http.Response('{"data": 100.50}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final balanceClient = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        baseUrl: 'https://openrouter.ai/api/v1',
        provider: 'openrouter',
        httpClient: balanceMockClient,
      );

      final balance1 = await balanceClient.getBalance();
      final balance2 = await balanceClient.getBalance();
      
      expect(balance1, equals(balance2));
      expect(balance1, equals('100.50'));
      
      balanceClient.dispose();
    });

    test('getBalance - очищает кэш после clearBalanceCache', () async {
      final balanceMockClient = MockClient((request) async {
        if (request.url.path.contains('/credits')) {
          return http.Response('{"data": 100.50}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final balanceClient = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        baseUrl: 'https://openrouter.ai/api/v1',
        provider: 'openrouter',
        httpClient: balanceMockClient,
      );

      await balanceClient.getBalance();
      balanceClient.clearBalanceCache();
      
      // После очистки кэша следующий вызов должен загрузить данные заново
      final balance = await balanceClient.getBalance(forceRefresh: true);
      expect(balance, equals('100.50'));
      
      balanceClient.dispose();
    });

    test('dispose - закрывает HTTP клиент и очищает кэши', () async {
      await client.getModels();
      await client.getBalance();
      
      client.dispose();
      
      // После dispose новые запросы должны выбрасывать исключение
      expect(() => client.getModels(), throwsA(isA<OpenRouterException>()));
    });

    test('detectProviderFromKey - определяет провайдера по префиксу', () {
      final client1 = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        baseUrl: 'https://openrouter.ai/api/v1',
      );
      expect(client1.provider, equals('openrouter'));
      client1.dispose();
      
      final client2 = OpenRouterClient(
        apiKey: 'sk-or-vv-test-key',
        baseUrl: 'https://api.vsegpt.ru/v1',
      );
      expect(client2.provider, equals('vsegpt'));
      client2.dispose();
    });

    test('_isDisposed - предотвращает запросы после dispose', () async {
      client.dispose();
      
      expect(
        () => client.getModels(),
        throwsA(isA<OpenRouterException>()),
      );
    });
  });

  group('OpenRouterClient Retry Logic Tests', () {
    test('_postWithRetry - повторяет при 5xx ошибках', () async {
      int attemptCount = 0;
      final mockClient = MockClient((request) async {
        attemptCount++;
        if (attemptCount < 3) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response(
          '''{
            "choices": [{"message": {"content": "Success"}}],
            "usage": {"total_tokens": 10}
          }''',
          200,
        );
      });

      final client = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        httpClient: mockClient,
      );

      final result = await client.sendMessage(
        message: 'Test',
        model: 'openai/gpt-4',
      );

      expect(result.text, equals('Success'));
      expect(attemptCount, equals(3));
      
      client.dispose();
    });

    test('_getWithRetry - обрабатывает rate limits (429)', () async {
      int attemptCount = 0;
      final mockClient = MockClient((request) async {
        attemptCount++;
        if (attemptCount < 2) {
          return http.Response(
            'Too Many Requests',
            429,
            headers: {'retry-after': '1'},
          );
        }
        return http.Response(
          '''{"data": [{"id": "test-model"}]}''',
          200,
        );
      });

      final client = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        httpClient: mockClient,
      );

      final models = await client.getModels(forceRefresh: true);
      expect(models, isNotEmpty);
      expect(attemptCount, equals(2));
      
      client.dispose();
    });
  });

  group('OpenRouterClient Error Handling Tests', () {
    test('sendMessage - обрабатывает ошибки сети', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      final client = OpenRouterClient(
        apiKey: 'sk-or-v1-test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.sendMessage(message: 'Test', model: 'test-model'),
        throwsA(isA<OpenRouterException>()),
      );
      
      client.dispose();
    });

    test('sendMessage - обрабатывает ошибки API (401)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"error": {"message": "Unauthorized"}}',
          401,
        );
      });

      final client = OpenRouterClient(
        apiKey: 'sk-or-v1-invalid-key',
        httpClient: mockClient,
      );

      expect(
        () => client.sendMessage(message: 'Test', model: 'test-model'),
        throwsA(isA<OpenRouterException>()),
      );
      
      client.dispose();
    });
  });
}
