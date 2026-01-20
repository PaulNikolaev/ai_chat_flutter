import 'package:ai_chat/models/models.dart';
import 'package:ai_chat/utils/cache.dart';

/// Класс аналитики использования моделей.
///
/// Отвечает за сбор метрик:
/// - количество запросов к моделям
/// - суммарные токены
/// - время ответа
///
/// Данные сохраняются в SQLite через [ChatCache].
class Analytics {
  /// Экземпляр кэша для работы с БД.
  final ChatCache _cache;

  /// Время старта сессии (для агрегирования при необходимости).
  final DateTime _sessionStart;

  /// Создает экземпляр [Analytics].
  ///
  /// Использует Singleton ChatCache по умолчанию.
  Analytics({ChatCache? cache})
      : _cache = cache ?? ChatCache.instance,
        _sessionStart = DateTime.now();

  /// Фиксирует метрики для одного сообщения.
  ///
  /// Сохраняет запись в БД и обновляет статистику по модели.
  /// Рассчитывает стоимость на основе цен модели, если они предоставлены.
  ///
  /// Параметры:
  /// - [model]: Идентификатор модели AI.
  /// - [messageLength]: Длина сообщения в символах.
  /// - [responseTime]: Время ответа в секундах.
  /// - [tokensUsed]: Общее количество использованных токенов.
  /// - [promptTokens]: Количество токенов в промпте (опционально).
  /// - [completionTokens]: Количество токенов в завершении (опционально).
  /// - [promptPrice]: Цена за токен промпта (опционально, для расчета стоимости).
  /// - [completionPrice]: Цена за токен завершения (опционально, для расчета стоимости).
  Future<void> trackMessage({
    required String model,
    required int messageLength,
    required double responseTime,
    required int tokensUsed,
    int? promptTokens,
    int? completionTokens,
    double? promptPrice,
    double? completionPrice,
  }) async {
    // Рассчитываем стоимость, если есть все необходимые данные
    double? cost;
    if (promptPrice != null && completionPrice != null) {
      final promptTokensValue = promptTokens ?? 0;
      final completionTokensValue = completionTokens ?? 0;
      cost = (promptTokensValue * promptPrice) +
          (completionTokensValue * completionPrice);
    } else if (promptTokens != null &&
        completionTokens != null &&
        promptTokens == 0 &&
        completionTokens == 0 &&
        tokensUsed > 0) {
      // Если токены не разделены, но есть общее количество, используем только completionPrice если доступен
      if (completionPrice != null) {
        cost = tokensUsed * completionPrice;
      } else if (promptPrice != null) {
        cost = tokensUsed * promptPrice;
      }
    }

    await _cache.saveAnalytics(
      timestamp: DateTime.now(),
      model: model,
      messageLength: messageLength,
      responseTime: responseTime,
      tokensUsed: tokensUsed,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      cost: cost,
    );
  }

  /// Возвращает полную историю аналитики (по возрастанию времени).
  Future<List<AnalyticsRecord>> getHistory() async {
    return _cache.getAnalyticsHistory();
  }

  /// Возвращает историю аналитики для конкретной модели.
  Future<List<AnalyticsRecord>> getHistoryByModel(String model) async {
    return _cache.getAnalyticsByModel(model);
  }

  /// Возвращает агрегированную статистику по моделям.
  ///
  /// Формат:
  /// ```
  /// {
  ///   "openai/gpt-4": {"count": 10, "tokens": 12345},
  ///   "anthropic/claude": {"count": 5, "tokens": 6789},
  /// }
  /// ```
  Future<Map<String, Map<String, int>>> getModelStatistics() async {
    return _cache.getModelStatistics();
  }

  /// Возвращает агрегированную статистику по моделям с фильтрацией.
  ///
  /// Параметры:
  /// - [model]: Фильтр по модели (опционально).
  /// - [startDate]: Начальная дата фильтрации (опционально).
  /// - [endDate]: Конечная дата фильтрации (опционально).
  ///
  /// Возвращает Map с агрегированной статистикой, отфильтрованной на уровне SQL.
  Future<Map<String, Map<String, int>>> getModelStatisticsFiltered({
    String? model,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _cache.getModelStatisticsFiltered(
      model: model,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Возвращает историю аналитики с фильтрацией и пагинацией.
  ///
  /// Параметры:
  /// - [model]: Фильтр по модели (опционально).
  /// - [startDate]: Начальная дата фильтрации (опционально).
  /// - [endDate]: Конечная дата фильтрации (опционально).
  /// - [limit]: Максимальное количество записей (по умолчанию 1000).
  /// - [offset]: Смещение для пагинации (по умолчанию 0).
  ///
  /// Возвращает список [AnalyticsRecord] с примененными фильтрами и пагинацией.
  Future<List<AnalyticsRecord>> getHistoryFiltered({
    String? model,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 1000,
    int offset = 0,
  }) async {
    return _cache.getAnalyticsHistoryFiltered(
      model: model,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
  }

  /// Возвращает количество записей аналитики с фильтрацией.
  ///
  /// Параметры:
  /// - [model]: Фильтр по модели (опционально).
  /// - [startDate]: Начальная дата фильтрации (опционально).
  /// - [endDate]: Конечная дата фильтрации (опционально).
  ///
  /// Возвращает количество записей, соответствующих фильтрам.
  Future<int> getHistoryCount({
    String? model,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _cache.getAnalyticsCount(
      model: model,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Возвращает сумму токенов с фильтрацией (оптимизированный запрос).
  ///
  /// Параметры:
  /// - [model]: Фильтр по модели (опционально).
  /// - [startDate]: Начальная дата фильтрации (опционально).
  /// - [endDate]: Конечная дата фильтрации (опционально).
  ///
  /// Возвращает сумму токенов, соответствующих фильтрам.
  Future<int> getTotalTokens({
    String? model,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _cache.getTotalTokens(
      model: model,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Возвращает статистику сессии с момента создания экземпляра.
  ///
  /// Формат:
  /// ```
  /// {
  ///   "sessionStart": DateTime,
  ///   "totalRequests": int,
  ///   "totalTokens": int
  /// }
  /// ```
  Future<Map<String, dynamic>> getSessionStatistics() async {
    final history = await _cache.getAnalyticsHistory();
    final filtered = history.where((r) => r.timestamp.isAfter(_sessionStart));

    int totalRequests = 0;
    int totalTokens = 0;
    for (final record in filtered) {
      totalRequests += 1;
      totalTokens += record.tokensUsed;
    }

    return {
      'sessionStart': _sessionStart,
      'totalRequests': totalRequests,
      'totalTokens': totalTokens,
    };
  }

  /// Очищает все записи аналитики.
  Future<bool> clear() async {
    return _cache.clearAnalytics();
  }
}
