import 'package:intl/intl.dart';

import '../models/analytics_record.dart';
import '../models/model_info.dart';
import 'analytics.dart';

/// Модель данных для представления расходов за период.
class ExpensesPeriod {
  /// Дата начала периода.
  final DateTime startDate;

  /// Дата окончания периода.
  final DateTime endDate;

  /// Сумма расходов за период в долларах.
  final double totalCost;

  /// Количество запросов за период.
  final int requestCount;

  /// Расходы по моделям (ключ - модель, значение - стоимость).
  final Map<String, double> costsByModel;

  /// Создает экземпляр [ExpensesPeriod].
  const ExpensesPeriod({
    required this.startDate,
    required this.endDate,
    required this.totalCost,
    required this.requestCount,
    required this.costsByModel,
  });

  /// Создает пустой период.
  factory ExpensesPeriod.empty(DateTime startDate, DateTime endDate) {
    return ExpensesPeriod(
      startDate: startDate,
      endDate: endDate,
      totalCost: 0.0,
      requestCount: 0,
      costsByModel: {},
    );
  }

  /// Форматирует дату для отображения.
  String get formattedDate {
    return DateFormat('yyyy-MM-dd').format(startDate);
  }

  /// Форматирует дату с учетом периода.
  String getFormattedDateLabel(String periodType) {
    switch (periodType) {
      case 'day':
        return DateFormat('yyyy-MM-dd').format(startDate);
      case 'week':
        return '${DateFormat('yyyy-MM-dd').format(startDate)} - ${DateFormat('yyyy-MM-dd').format(endDate)}';
      case 'month':
        return DateFormat('yyyy-MM').format(startDate);
      default:
        return formattedDate;
    }
  }
}

/// Сервис для расчета расходов на основе аналитических данных.
///
/// Предоставляет методы для агрегации расходов по различным временным периодам:
/// - По дням
/// - По неделям
/// - По месяцам
///
/// Поддерживает пересчет стоимости на основе цен моделей из [ModelInfo],
/// если стоимость не была сохранена в записях аналитики.
class ExpensesCalculator {
  /// Экземпляр аналитики для получения данных.
  final Analytics _analytics;

  /// Кэш информации о моделях (ключ - ID модели, значение - ModelInfo).
  final Map<String, ModelInfo> _modelInfoCache;

  /// Создает экземпляр [ExpensesCalculator].
  ///
  /// Параметры:
  /// - [analytics]: Экземпляр [Analytics] для получения данных (опционально).
  /// - [modelInfoList]: Список моделей для кэширования цен (опционально).
  ExpensesCalculator({
    Analytics? analytics,
    List<ModelInfo>? modelInfoList,
  })  : _analytics = analytics ?? Analytics(),
        _modelInfoCache = {
          if (modelInfoList != null)
            for (final model in modelInfoList) model.id: model
        };

  /// Обновляет кэш информации о моделях.
  ///
  /// Параметры:
  /// - [modelInfoList]: Список моделей для кэширования.
  void updateModelInfoCache(List<ModelInfo> modelInfoList) {
    _modelInfoCache.clear();
    for (final model in modelInfoList) {
      _modelInfoCache[model.id] = model;
    }
  }

  /// Рассчитывает стоимость записи, используя цены из ModelInfo если необходимо.
  ///
  /// Параметры:
  /// - [record]: Запись аналитики.
  ///
  /// Возвращает стоимость записи в долларах или null, если расчет невозможен.
  double? _calculateRecordCost(AnalyticsRecord record) {
    // Если стоимость уже сохранена, используем её
    if (record.cost != null) {
      return record.cost;
    }

    // Если стоимость не сохранена, пытаемся пересчитать по ценам модели
    final modelInfo = _modelInfoCache[record.model];
    if (modelInfo == null) {
      return null;
    }

    final promptPrice = modelInfo.promptPrice ?? 0.0;
    final completionPrice = modelInfo.completionPrice ?? 0.0;

    // Если есть разделение на prompt и completion токены
    if (record.promptTokens != null && record.completionTokens != null) {
      return (record.promptTokens! * promptPrice) +
          (record.completionTokens! * completionPrice);
    }

    // Если есть только общее количество токенов, используем среднюю цену
    // Для бесплатных моделей (обе цены = 0.0) возвращаем 0.0, а не null
    final avgPrice = (promptPrice + completionPrice) / 2.0;
    return record.tokensUsed * avgPrice;
  }

  /// Получает расходы по дням за указанный период.
  ///
  /// Параметры:
  /// - [startDate]: Начальная дата периода (включительно).
  /// - [endDate]: Конечная дата периода (включительно).
  /// - [model]: Фильтр по модели (опционально).
  ///
  /// Возвращает список [ExpensesPeriod], отсортированных по дате.
  Future<List<ExpensesPeriod>> getExpensesByDays({
    required DateTime startDate,
    required DateTime endDate,
    String? model,
  }) async {
    // Нормализуем даты (убираем время, оставляем только дату)
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day).add(
      const Duration(days: 1),
    );

    // Получаем записи за период
    final records = await _analytics.getHistoryFiltered(
      model: model,
      startDate: start,
      endDate: end.subtract(const Duration(days: 1)),
    );

    // Группируем по дням
    final Map<String, ExpensesPeriod> dailyExpenses = {};
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final record in records) {
      final recordDate = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      final dateKey = dateFormat.format(recordDate);

      final cost = _calculateRecordCost(record);
      if (cost == null) continue;

      final dayStart = recordDate;
      final dayEnd = dayStart.add(const Duration(days: 1));

      dailyExpenses[dateKey] ??= ExpensesPeriod.empty(dayStart, dayEnd);

      final existing = dailyExpenses[dateKey]!;
      dailyExpenses[dateKey] = ExpensesPeriod(
        startDate: existing.startDate,
        endDate: existing.endDate,
        totalCost: existing.totalCost + cost,
        requestCount: existing.requestCount + 1,
        costsByModel: {
          ...existing.costsByModel,
          record.model: (existing.costsByModel[record.model] ?? 0.0) + cost,
        },
      );
    }

    // Создаем периоды для всех дней в диапазоне, даже если расходов не было
    final result = <ExpensesPeriod>[];
    var currentDate = start;
    while (currentDate.isBefore(end)) {
      final dateKey = dateFormat.format(currentDate);
      final dayEnd = currentDate.add(const Duration(days: 1));

      result.add(
        dailyExpenses[dateKey] ??
            ExpensesPeriod.empty(currentDate, dayEnd),
      );

      currentDate = dayEnd;
    }

    return result;
  }

  /// Получает расходы по неделям за указанный период.
  ///
  /// Параметры:
  /// - [startDate]: Начальная дата периода (включительно).
  /// - [endDate]: Конечная дата периода (включительно).
  /// - [model]: Фильтр по модели (опционально).
  ///
  /// Возвращает список [ExpensesPeriod], отсортированных по дате начала недели.
  Future<List<ExpensesPeriod>> getExpensesByWeeks({
    required DateTime startDate,
    required DateTime endDate,
    String? model,
  }) async {
    // Нормализуем даты
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day).add(
      const Duration(days: 1),
    );

    // Получаем записи за период
    final records = await _analytics.getHistoryFiltered(
      model: model,
      startDate: start,
      endDate: end.subtract(const Duration(days: 1)),
    );

    // Группируем по неделям (неделя начинается с понедельника)
    final Map<String, ExpensesPeriod> weeklyExpenses = {};

    for (final record in records) {
      final recordDate = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );

      // Находим начало недели (понедельник)
      final daysFromMonday = recordDate.weekday - 1;
      final weekStart = recordDate.subtract(Duration(days: daysFromMonday));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final weekKey = '${weekStart.year}-W${_getWeekNumber(weekStart)}';

      final cost = _calculateRecordCost(record);
      if (cost == null) continue;

      weeklyExpenses[weekKey] ??= ExpensesPeriod.empty(weekStart, weekEnd);

      final existing = weeklyExpenses[weekKey]!;
      weeklyExpenses[weekKey] = ExpensesPeriod(
        startDate: existing.startDate,
        endDate: existing.endDate,
        totalCost: existing.totalCost + cost,
        requestCount: existing.requestCount + 1,
        costsByModel: {
          ...existing.costsByModel,
          record.model: (existing.costsByModel[record.model] ?? 0.0) + cost,
        },
      );
    }

    // Сортируем по дате начала недели
    final result = weeklyExpenses.values.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return result;
  }

  /// Получает расходы по месяцам за указанный период.
  ///
  /// Параметры:
  /// - [startDate]: Начальная дата периода (включительно).
  /// - [endDate]: Конечная дата периода (включительно).
  /// - [model]: Фильтр по модели (опционально).
  ///
  /// Возвращает список [ExpensesPeriod], отсортированных по дате начала месяца.
  Future<List<ExpensesPeriod>> getExpensesByMonths({
    required DateTime startDate,
    required DateTime endDate,
    String? model,
  }) async {
    // Нормализуем даты
    final start = DateTime(startDate.year, startDate.month, 1);
    final end = DateTime(endDate.year, endDate.month + 1, 1);

    // Получаем записи за период
    final records = await _analytics.getHistoryFiltered(
      model: model,
      startDate: start,
      endDate: end.subtract(const Duration(days: 1)),
    );

    // Группируем по месяцам
    final Map<String, ExpensesPeriod> monthlyExpenses = {};

    for (final record in records) {
      final recordDate = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        1,
      );

      final monthEnd = DateTime(
        record.timestamp.year,
        record.timestamp.month + 1,
        1,
      );

      final monthKey = '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}';

      final cost = _calculateRecordCost(record);
      if (cost == null) continue;

      monthlyExpenses[monthKey] ??= ExpensesPeriod.empty(recordDate, monthEnd);

      final existing = monthlyExpenses[monthKey]!;
      monthlyExpenses[monthKey] = ExpensesPeriod(
        startDate: existing.startDate,
        endDate: existing.endDate,
        totalCost: existing.totalCost + cost,
        requestCount: existing.requestCount + 1,
        costsByModel: {
          ...existing.costsByModel,
          record.model: (existing.costsByModel[record.model] ?? 0.0) + cost,
        },
      );
    }

    // Создаем периоды для всех месяцев в диапазоне
    final result = <ExpensesPeriod>[];
    var currentDate = start;
    while (currentDate.isBefore(end)) {
      final monthEnd = DateTime(
        currentDate.year,
        currentDate.month + 1,
        1,
      );
      final monthKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';

      result.add(
        monthlyExpenses[monthKey] ??
            ExpensesPeriod.empty(currentDate, monthEnd),
      );

      currentDate = monthEnd;
    }

    return result;
  }

  /// Получает общую сумму расходов за период.
  ///
  /// Параметры:
  /// - [startDate]: Начальная дата периода (включительно).
  /// - [endDate]: Конечная дата периода (включительно).
  /// - [model]: Фильтр по модели (опционально).
  ///
  /// Возвращает общую сумму расходов в долларах.
  Future<double> getTotalExpenses({
    required DateTime startDate,
    required DateTime endDate,
    String? model,
  }) async {
    final records = await _analytics.getHistoryFiltered(
      model: model,
      startDate: startDate,
      endDate: endDate,
    );

    double total = 0.0;
    for (final record in records) {
      final cost = _calculateRecordCost(record);
      if (cost != null) {
        total += cost;
      }
    }

    return total;
  }

  /// Получает номер недели в году.
  int _getWeekNumber(DateTime date) {
    final firstJan = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstJan).inDays;
    final weekNumber = ((daysDiff + firstJan.weekday - 1) / 7).ceil();
    return weekNumber;
  }
}
