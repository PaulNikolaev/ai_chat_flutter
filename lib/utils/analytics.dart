import '../models/analytics_record.dart';
import 'cache.dart';

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
  Future<void> trackMessage({
    required String model,
    required int messageLength,
    required double responseTime,
    required int tokensUsed,
  }) async {
    await _cache.saveAnalytics(
      timestamp: DateTime.now(),
      model: model,
      messageLength: messageLength,
      responseTime: responseTime,
      tokensUsed: tokensUsed,
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
