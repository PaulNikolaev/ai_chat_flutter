import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_chat/utils/cache.dart';

void main() {
  // Инициализируем sqflite_ffi для тестирования на десктопе
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ChatCache Tests', () {
    late ChatCache cache;

    setUp(() async {
      // Используем тестовую БД
      cache = ChatCache.instance;
      // Очищаем данные перед каждым тестом
      await cache.clearHistory();
      await cache.clearAnalytics();
    });

    test('saveMessage - сохраняет сообщение в БД', () async {
      final id = await cache.saveMessage(
        model: 'openai/gpt-4',
        userMessage: 'Hello',
        aiResponse: 'Hi there!',
        tokensUsed: 100,
      );

      expect(id, isNotNull);
      expect(id, greaterThan(0));
    });

    test('getChatHistory - получает историю чата с лимитом', () async {
      // Сохраняем несколько сообщений
      await cache.saveMessage(
        model: 'openai/gpt-4',
        userMessage: 'Message 1',
        aiResponse: 'Response 1',
        tokensUsed: 50,
      );

      await cache.saveMessage(
        model: 'openai/gpt-3.5-turbo',
        userMessage: 'Message 2',
        aiResponse: 'Response 2',
        tokensUsed: 30,
      );

      final history = await cache.getChatHistory(limit: 10);
      expect(history.length, equals(2));
      expect(history.first.userMessage, equals('Message 2')); // Новейшие первыми
    });

    test('clearHistory - очищает всю историю', () async {
      await cache.saveMessage(
        model: 'test-model',
        userMessage: 'Test',
        aiResponse: 'Test',
        tokensUsed: 10,
      );

      final cleared = await cache.clearHistory();
      expect(cleared, isTrue);

      final history = await cache.getChatHistory();
      expect(history, isEmpty);
    });

    test('saveAnalytics - сохраняет аналитику', () async {
      final id = await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'openai/gpt-4',
        messageLength: 100,
        responseTime: 1.5,
        tokensUsed: 200,
        promptTokens: 150,
        completionTokens: 50,
        cost: 0.002,
      );

      expect(id, isNotNull);
      expect(id, greaterThan(0));
    });

    test('getAnalyticsHistory - получает историю аналитики', () async {
      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'openai/gpt-4',
        messageLength: 100,
        responseTime: 1.0,
        tokensUsed: 100,
      );

      final analytics = await cache.getAnalyticsHistory();
      expect(analytics, isNotEmpty);
      expect(analytics.first.model, equals('openai/gpt-4'));
    });

    test('getAnalyticsCount - возвращает количество записей', () async {
      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'test-model',
        messageLength: 50,
        responseTime: 0.5,
        tokensUsed: 50,
      );

      final count = await cache.getAnalyticsCount();
      expect(count, equals(1));
    });

    test('getTotalTokens - возвращает сумму токенов', () async {
      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'test-model',
        messageLength: 50,
        responseTime: 0.5,
        tokensUsed: 100,
      );

      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'test-model',
        messageLength: 50,
        responseTime: 0.5,
        tokensUsed: 200,
      );

      final total = await cache.getTotalTokens();
      expect(total, equals(300));
    });

    test('getModelStatistics - возвращает статистику по моделям', () async {
      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'openai/gpt-4',
        messageLength: 50,
        responseTime: 0.5,
        tokensUsed: 100,
      );

      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'openai/gpt-3.5-turbo',
        messageLength: 50,
        responseTime: 0.5,
        tokensUsed: 200,
      );

      final stats = await cache.getModelStatistics();
      expect(stats.length, equals(2));
      expect(stats['openai/gpt-4']!['count'], equals(1));
      expect(stats['openai/gpt-4']!['tokens'], equals(100));
    });

    test('getAnalyticsHistoryFiltered - фильтрует по модели', () async {
      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'openai/gpt-4',
        messageLength: 50,
        responseTime: 0.5,
        tokensUsed: 100,
      );

      await cache.saveAnalytics(
        timestamp: DateTime.now(),
        model: 'openai/gpt-3.5-turbo',
        messageLength: 50,
        responseTime: 0.5,
        tokensUsed: 200,
      );

      final filtered = await cache.getAnalyticsHistoryFiltered(
        model: 'openai/gpt-4',
      );

      expect(filtered.length, equals(1));
      expect(filtered.first.model, equals('openai/gpt-4'));
    });

    test('saveMessagesBatch - сохраняет несколько сообщений в одной транзакции', () async {
      final messages = [
        {
          'model': 'test-model-1',
          'userMessage': 'Message 1',
          'aiResponse': 'Response 1',
          'tokensUsed': 50,
        },
        {
          'model': 'test-model-2',
          'userMessage': 'Message 2',
          'aiResponse': 'Response 2',
          'tokensUsed': 60,
        },
      ];

      final ids = await cache.saveMessagesBatch(messages);
      expect(ids.length, equals(2));
      expect(ids[0], greaterThan(0));
      expect(ids[1], greaterThan(ids[0]));

      final history = await cache.getChatHistory();
      expect(history.length, equals(2));
    });
  });
}
