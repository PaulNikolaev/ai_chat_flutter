/// Константы приложения.
///
/// Содержит все магические числа и строки, используемые в приложении,
/// для улучшения читаемости и поддержки кода.
class AppConstants {
  AppConstants._();

  // PIN код константы
  /// Минимальное значение PIN кода.
  static const int pinMinValue = 1000;

  /// Максимальное значение PIN кода.
  static const int pinMaxValue = 9999;

  /// Длина PIN кода.
  static const int pinLength = 4;

  // HTTP статус коды
  /// HTTP статус код: OK.
  static const int httpStatusOk = 200;

  /// HTTP статус код: Unauthorized.
  static const int httpStatusUnauthorized = 401;

  /// HTTP статус код: Forbidden.
  static const int httpStatusForbidden = 403;

  /// HTTP статус код: Not Found.
  static const int httpStatusNotFound = 404;

  /// HTTP статус код: Too Many Requests.
  static const int httpStatusTooManyRequests = 429;

  /// HTTP статус код: Internal Server Error.
  static const int httpStatusInternalServerError = 500;

  /// HTTP статус код: Bad Gateway.
  static const int httpStatusBadGateway = 502;

  /// HTTP статус код: Service Unavailable.
  static const int httpStatusServiceUnavailable = 503;

  // Размеры данных
  /// Количество байт в килобайте.
  static const int bytesPerKilobyte = 1024;

  /// Количество байт в мегабайте.
  static const int bytesPerMegabyte = 1024 * 1024;

  /// Порог для отображения памяти в KB.
  static const int memoryKbThreshold = 1024;

  /// Порог для отображения памяти в GB.
  static const int memoryGbThreshold = 1024;

  /// Порог для отображения токенов в K.
  static const int tokensKThreshold = 1000;

  /// Порог для отображения токенов в M.
  static const int tokensMThreshold = 1000000;

  // Ограничения данных
  /// Максимальное количество периодов для графиков.
  static const int maxPeriodsForCharts = 365;

  /// Максимальное количество записей для экспорта.
  static const int maxExportRecords = 10000;

  /// Максимальное количество сообщений истории.
  static const int maxChatHistoryMessages = 100;

  /// Максимальное количество записей аналитики по умолчанию.
  static const int defaultAnalyticsLimit = 1000;

  // Длительности анимаций (миллисекунды)
  /// Стандартная длительность анимации.
  static const int animationDurationDefault = 300;

  /// Быстрая длительность анимации.
  static const int animationDurationFast = 200;

  /// Медленная длительность анимации.
  static const int animationDurationSlow = 500;

  /// Длительность анимации загрузки.
  static const int animationDurationLoading = 1200;

  /// Длительность анимации кнопки.
  static const int animationDurationButton = 150;

  // Retry логика
  /// Задержка между повторными попытками (миллисекунды).
  static const int retryDelayMs = 300;

  /// Минимальная задержка перед dispose (миллисекунды).
  static const int disposeDelayMs = 100;

  // Дата/время
  /// Начальная дата для календарей (2000 год).
  static const int calendarStartYear = 2000;

  // Кэш
  /// Время жизни кэша статистики (секунды).
  static const int statisticsCacheLifetimeSeconds = 5;

  /// Время между обновлениями статистики (секунды).
  static const int statisticsUpdateIntervalSeconds = 1;

  // UI размеры
  /// Ширина окна логина.
  static const double loginWindowWidth = 500.0;

  /// Ширина контейнера в landscape режиме.
  static const double containerWidthLandscape = 600.0;

  /// Ширина контейнера в portrait режиме.
  static const double containerWidthPortrait = 500.0;

  /// Максимальная ширина окна.
  static const double maxWindowWidth = 600.0;

  /// Максимальная ширина для планшетов.
  static const double tabletMaxWidth = 600.0;

  /// Высота графика расходов.
  static const double expensesChartHeight = 300.0;

  /// Высота истории чата.
  static const double chatHistoryHeight = 400.0;

  // Производительность
  /// Кэш extent для ListView.
  static const double listViewCacheExtent = 500.0;

  /// Ширина среднего экрана (планшеты).
  static const double mediumScreenWidth = 600.0;

  /// Ширина большого экрана (десктопы).
  static const double largeScreenWidth = 1024.0;
}
