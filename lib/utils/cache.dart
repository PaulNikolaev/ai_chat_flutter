import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database/database.dart';
import '../models/chat_message.dart';
import '../models/analytics_record.dart';

/// Thread-safe кэш для истории чата и аналитических данных.
///
/// Предоставляет постоянное хранилище для сообщений чата с метаданными,
/// включая информацию о модели, временные метки и использование токенов.
/// Поддерживает хранение аналитических данных, получение форматированной
/// истории и управление данными аутентификации.
///
/// sqflite обеспечивает thread-safety автоматически, поэтому дополнительные
/// блокировки не требуются.
///
/// Пример использования:
/// ```dart
/// final cache = ChatCache();
/// await cache.saveMessage(
///   model: 'openai/gpt-4',
///   userMessage: 'Привет',
///   aiResponse: 'Здравствуйте!',
///   tokensUsed: 50,
/// );
/// ```
class ChatCache {
  /// Единственный экземпляр ChatCache (Singleton).
  static final ChatCache instance = ChatCache._internal();

  /// Внутренний конструктор для Singleton.
  ChatCache._internal();

  /// Получает экземпляр базы данных.
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// Сохраняет новое сообщение чата в базу данных.
  ///
  /// Сохраняет сообщение пользователя, ответ AI, используемую модель
  /// и количество использованных токенов.
  ///
  /// Параметры:
  /// - [model]: Идентификатор модели AI, использованной для ответа.
  /// - [userMessage]: Текст сообщения пользователя.
  /// - [aiResponse]: Текст ответа AI.
  /// - [tokensUsed]: Количество использованных токенов.
  ///
  /// Возвращает ID сохраненного сообщения или null в случае ошибки.
  Future<int?> saveMessage({
    required String model,
    required String userMessage,
    required String aiResponse,
    required int tokensUsed,
  }) async {
    try {
      final db = await _db;
      final timestamp = DateTime.now().toIso8601String();

      final id = await db.insert(
        'messages',
        {
          'model': model,
          'user_message': userMessage,
          'ai_response': aiResponse,
          'timestamp': timestamp,
          'tokens_used': tokensUsed,
        },
      );

      return id;
    } catch (e) {
      return null;
    }
  }

  /// Получает историю чата из базы данных.
  ///
  /// Возвращает список последних сообщений, отсортированных по времени
  /// в порядке убывания (новейшие первыми).
  ///
  /// Параметры:
  /// - [limit]: Максимальное количество сообщений для возврата. По умолчанию 50.
  ///
  /// Возвращает список [ChatMessage] или пустой список в случае ошибки.
  Future<List<ChatMessage>> getChatHistory({int limit = 50}) async {
    try {
      final db = await _db;
      final results = await db.query(
        'messages',
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return results.map((row) => ChatMessage(
            id: row['id'] as int?,
            model: row['model'] as String,
            userMessage: row['user_message'] as String,
            aiResponse: row['ai_response'] as String,
            timestamp: DateTime.parse(row['timestamp'] as String),
            tokensUsed: row['tokens_used'] as int,
          )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Получает всю историю чата в формате для экспорта.
  ///
  /// Возвращает список всех сообщений, отсортированных по времени
  /// в порядке возрастания (старейшие первыми).
  ///
  /// Возвращает список [ChatMessage] или пустой список в случае ошибки.
  Future<List<ChatMessage>> getFormattedHistory() async {
    try {
      final db = await _db;
      final results = await db.query(
        'messages',
        orderBy: 'timestamp ASC',
      );

      return results.map((row) => ChatMessage(
            id: row['id'] as int?,
            model: row['model'] as String,
            userMessage: row['user_message'] as String,
            aiResponse: row['ai_response'] as String,
            timestamp: DateTime.parse(row['timestamp'] as String),
            tokensUsed: row['tokens_used'] as int,
          )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Очищает всю историю чата из базы данных.
  ///
  /// Удаляет все записи из таблицы messages, эффективно очищая
  /// всю историю чата.
  ///
  /// Возвращает true, если операция выполнена успешно, иначе false.
  Future<bool> clearHistory() async {
    try {
      final db = await _db;
      await db.delete('messages');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Экспортирует историю чата в JSON формат.
  ///
  /// Получает всю историю чата и преобразует её в JSON строку
  /// для сохранения или передачи.
  ///
  /// Возвращает JSON строку с историей чата или null в случае ошибки.
  Future<String?> exportHistoryToJson() async {
    try {
      final history = await getFormattedHistory();
      final jsonList = history.map((message) => message.toJson()).toList();
      return jsonEncode(jsonList);
    } catch (e) {
      return null;
    }
  }

  /// Сохраняет аналитическую запись в базу данных.
  ///
  /// Сохраняет метрики использования модели, включая время ответа,
  /// длину сообщения и количество использованных токенов.
  ///
  /// Параметры:
  /// - [timestamp]: Временная метка записи.
  /// - [model]: Идентификатор модели AI.
  /// - [messageLength]: Длина сообщения в символах.
  /// - [responseTime]: Время ответа в секундах.
  /// - [tokensUsed]: Количество использованных токенов.
  ///
  /// Возвращает ID сохраненной записи или null в случае ошибки.
  Future<int?> saveAnalytics({
    required DateTime timestamp,
    required String model,
    required int messageLength,
    required double responseTime,
    required int tokensUsed,
  }) async {
    try {
      final db = await _db;
      final timestampStr = timestamp.toIso8601String();

      final id = await db.insert(
        'analytics_messages',
        {
          'timestamp': timestampStr,
          'model': model,
          'message_length': messageLength,
          'response_time': responseTime,
          'tokens_used': tokensUsed,
        },
      );

      return id;
    } catch (e) {
      return null;
    }
  }

  /// Получает всю историю аналитики из базы данных.
  ///
  /// Возвращает список всех аналитических записей, отсортированных
  /// по времени в порядке возрастания (старейшие первыми).
  ///
  /// Возвращает список [AnalyticsRecord] или пустой список в случае ошибки.
  Future<List<AnalyticsRecord>> getAnalyticsHistory() async {
    try {
      final db = await _db;
      final results = await db.query(
        'analytics_messages',
        orderBy: 'timestamp ASC',
      );

      return results.map((row) => AnalyticsRecord(
            id: row['id'] as int?,
            timestamp: DateTime.parse(row['timestamp'] as String),
            model: row['model'] as String,
            messageLength: row['message_length'] as int,
            responseTime: (row['response_time'] as num).toDouble(),
            tokensUsed: row['tokens_used'] as int,
          )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Получает аналитику по модели.
  ///
  /// Возвращает список аналитических записей для указанной модели,
  /// отсортированных по времени в порядке возрастания.
  ///
  /// Параметры:
  /// - [model]: Идентификатор модели AI.
  ///
  /// Возвращает список [AnalyticsRecord] или пустой список в случае ошибки.
  Future<List<AnalyticsRecord>> getAnalyticsByModel(String model) async {
    try {
      final db = await _db;
      final results = await db.query(
        'analytics_messages',
        where: 'model = ?',
        whereArgs: [model],
        orderBy: 'timestamp ASC',
      );

      return results.map((row) => AnalyticsRecord(
            id: row['id'] as int?,
            timestamp: DateTime.parse(row['timestamp'] as String),
            model: row['model'] as String,
            messageLength: row['message_length'] as int,
            responseTime: (row['response_time'] as num).toDouble(),
            tokensUsed: row['tokens_used'] as int,
          )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Получает статистику использования моделей.
  ///
  /// Возвращает Map, где ключ - идентификатор модели, а значение - Map
  /// с ключами 'count' (количество использований) и 'tokens' (общее количество токенов).
  ///
  /// Возвращает Map<String, Map<String, int>> или пустой Map в случае ошибки.
  Future<Map<String, Map<String, int>>> getModelStatistics() async {
    try {
      final db = await _db;
      final results = await db.rawQuery('''
        SELECT 
          model,
          COUNT(*) as count,
          SUM(tokens_used) as tokens
        FROM analytics_messages
        GROUP BY model
      ''');

      final statistics = <String, Map<String, int>>{};
      for (final row in results) {
        statistics[row['model'] as String] = {
          'count': row['count'] as int,
          'tokens': (row['tokens'] as num).toInt(),
        };
      }

      return statistics;
    } catch (e) {
      return {};
    }
  }

  /// Очищает всю аналитику из базы данных.
  ///
  /// Удаляет все записи из таблицы analytics_messages.
  ///
  /// Возвращает true, если операция выполнена успешно, иначе false.
  Future<bool> clearAnalytics() async {
    try {
      final db = await _db;
      await db.delete('analytics_messages');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Выполняет операцию в транзакции для обеспечения атомарности.
  ///
  /// Используется для операций, которые должны выполняться атомарно.
  /// Если операция выбрасывает исключение, транзакция откатывается.
  ///
  /// Параметры:
  /// - [action]: Функция, выполняемая в транзакции. Принимает [Transaction] и возвращает результат.
  ///
  /// Возвращает результат выполнения [action] или null в случае ошибки.
  Future<T?> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      final db = await _db;
      return await db.transaction(action);
    } catch (e) {
      return null;
    }
  }

  /// Закрывает базу данных и освобождает ресурсы.
  ///
  /// Должен вызываться при завершении работы приложения.
  Future<void> close() async {
    await DatabaseHelper.instance.close();
  }
}
