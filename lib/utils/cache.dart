import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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
      // Используем where: '1=1' для удаления всех записей
      await db.delete('messages', where: '1=1');
      // Операция считается успешной, даже если удалено 0 записей
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

  /// Сохраняет несколько сообщений батчем для оптимизации производительности.
  ///
  /// Выполняет вставку нескольких сообщений в одной транзакции,
  /// что значительно быстрее чем отдельные вставки.
  ///
  /// Параметры:
  /// - [messages]: Список сообщений для сохранения.
  ///
  /// Возвращает список ID сохраненных сообщений.
  Future<List<int>> saveMessagesBatch(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return [];
    
    try {
      final db = await _db;
      final List<int> ids = [];
      
      // Используем транзакцию для батчинга
      await db.transaction((txn) async {
        final batch = txn.batch();
        final timestamp = DateTime.now().toIso8601String();
        
        for (final message in messages) {
          batch.insert(
            'messages',
            {
              'model': message['model'] as String,
              'user_message': message['userMessage'] as String,
              'ai_response': message['aiResponse'] as String,
              'timestamp': message['timestamp'] as String? ?? timestamp,
              'tokens_used': message['tokensUsed'] as int,
            },
          );
        }
        
        final result = await batch.commit(noResult: false);
        ids.addAll((result as List).cast<int>());
      });
      
      return ids;
    } catch (e) {
      return [];
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
      
      debugPrint('ChatCache.saveAnalytics: Saved analytics record with id=$id, model=$model, tokens=$tokensUsed');
      return id;
    } catch (e, stackTrace) {
      debugPrint('ChatCache.saveAnalytics error: $e');
      debugPrint('Stack trace: $stackTrace');
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

  /// Получает историю аналитики с фильтрацией и пагинацией.
  ///
  /// Параметры:
  /// - [model]: Фильтр по модели (опционально).
  /// - [startDate]: Начальная дата фильтрации (опционально).
  /// - [endDate]: Конечная дата фильтрации (опционально).
  /// - [limit]: Максимальное количество записей (по умолчанию 1000).
  /// - [offset]: Смещение для пагинации (по умолчанию 0).
  ///
  /// Возвращает список [AnalyticsRecord] или пустой список в случае ошибки.
  Future<List<AnalyticsRecord>> getAnalyticsHistoryFiltered({
    String? model,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 1000,
    int offset = 0,
  }) async {
    try {
      final db = await _db;
      
      // Строим WHERE условие
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];
      
      if (model != null && model.isNotEmpty) {
        whereConditions.add('model = ?');
        whereArgs.add(model);
      }
      
      if (startDate != null) {
        whereConditions.add('timestamp >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        // Добавляем день к конечной дате для включения всего дня
        final endDateInclusive = endDate.add(const Duration(days: 1));
        whereConditions.add('timestamp < ?');
        whereArgs.add(endDateInclusive.toIso8601String());
      }
      
      final whereClause = whereConditions.isNotEmpty
          ? whereConditions.join(' AND ')
          : null;
      
      final results = await db.query(
        'analytics_messages',
        where: whereClause,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'timestamp ASC',
        limit: limit,
        offset: offset,
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
      debugPrint('ChatCache.getAnalyticsHistoryFiltered error: $e');
      return [];
    }
  }

  /// Получает количество записей аналитики с фильтрацией.
  ///
  /// Параметры:
  /// - [model]: Фильтр по модели (опционально).
  /// - [startDate]: Начальная дата фильтрации (опционально).
  /// - [endDate]: Конечная дата фильтрации (опционально).
  ///
  /// Возвращает количество записей или 0 в случае ошибки.
  Future<int> getAnalyticsCount({
    String? model,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await _db;
      
      // Строим WHERE условие
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];
      
      if (model != null && model.isNotEmpty) {
        whereConditions.add('model = ?');
        whereArgs.add(model);
      }
      
      if (startDate != null) {
        whereConditions.add('timestamp >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        final endDateInclusive = endDate.add(const Duration(days: 1));
        whereConditions.add('timestamp < ?');
        whereArgs.add(endDateInclusive.toIso8601String());
      }
      
      final whereClause = whereConditions.isNotEmpty
          ? whereConditions.join(' AND ')
          : null;
      
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM analytics_messages'
        '${whereClause != null ? ' WHERE $whereClause' : ''}',
        whereArgs.isNotEmpty ? whereArgs : null,
      );
      
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ChatCache.getAnalyticsCount error: $e');
      return 0;
    }
  }

  /// Получает агрегированную статистику с фильтрацией на уровне SQL.
  ///
  /// Параметры:
  /// - [model]: Фильтр по модели (опционально).
  /// - [startDate]: Начальная дата фильтрации (опционально).
  /// - [endDate]: Конечная дата фильтрации (опционально).
  ///
  /// Возвращает Map с ключом - идентификатор модели, значение - Map
  /// с ключами 'count' и 'tokens'.
  Future<Map<String, Map<String, int>>> getModelStatisticsFiltered({
    String? model,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await _db;
      
      // Строим WHERE условие
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];
      
      if (model != null && model.isNotEmpty) {
        whereConditions.add('model = ?');
        whereArgs.add(model);
      }
      
      if (startDate != null) {
        whereConditions.add('timestamp >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        final endDateInclusive = endDate.add(const Duration(days: 1));
        whereConditions.add('timestamp < ?');
        whereArgs.add(endDateInclusive.toIso8601String());
      }
      
      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(' AND ')}'
          : '';
      
      final results = await db.rawQuery('''
        SELECT 
          model,
          COUNT(*) as count,
          SUM(tokens_used) as tokens
        FROM analytics_messages
        $whereClause
        GROUP BY model
      ''', whereArgs.isNotEmpty ? whereArgs : null);

      final statistics = <String, Map<String, int>>{};
      
      for (final row in results) {
        final modelName = row['model'] as String?;
        if (modelName == null) continue;
        
        final count = row['count'] as int? ?? 0;
        final tokens = row['tokens'] as int? ?? 0;
        
        statistics[modelName] = {
          'count': count,
          'tokens': tokens,
        };
      }
      
      return statistics;
    } catch (e) {
      debugPrint('ChatCache.getModelStatisticsFiltered error: $e');
      return {};
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
      
      // Проверяем, существует ли таблица
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='analytics_messages'"
      );
      
      if (tables.isEmpty) {
        // Таблица не существует, возвращаем пустую статистику
        return {};
      }
      
      final results = await db.rawQuery('''
        SELECT 
          model,
          COUNT(*) as count,
          SUM(tokens_used) as tokens
        FROM analytics_messages
        GROUP BY model
      ''');

      final statistics = <String, Map<String, int>>{};
      debugPrint('ChatCache.getModelStatistics: Found ${results.length} model groups');
      
      for (final row in results) {
        final model = row['model'] as String?;
        final count = row['count'] as int?;
        final tokens = row['tokens'] as num?;
        
        debugPrint('ChatCache.getModelStatistics: model=$model, count=$count, tokens=$tokens');
        
        if (model != null && count != null && tokens != null) {
          statistics[model] = {
            'count': count,
            'tokens': tokens.toInt(),
          };
        }
      }

      debugPrint('ChatCache.getModelStatistics: Returning ${statistics.length} models');
      return statistics;
    } catch (e, stackTrace) {
      // Логируем ошибку для отладки
      debugPrint('ChatCache.getModelStatistics error: $e');
      debugPrint('Stack trace: $stackTrace');
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
