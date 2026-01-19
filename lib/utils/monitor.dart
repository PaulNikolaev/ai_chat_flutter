import 'dart:io' show ProcessInfo;

import 'platform.dart';

/// Снимок метрик производительности приложения.
class PerformanceMetrics {
  /// Использование CPU в процентах, если доступно.
  ///
  /// В чистом Dart/Flutter без нативных плагинов точное CPU% кросс-платформенно
  /// получить нельзя, поэтому по умолчанию `null`.
  final double? cpuPercent;

  /// Использование памяти процессом (Resident Set Size) в байтах, если доступно.
  final int? memoryRssBytes;

  /// Время работы приложения с момента старта мониторинга.
  final Duration uptime;

  const PerformanceMetrics({
    required this.cpuPercent,
    required this.memoryRssBytes,
    required this.uptime,
  });

  Map<String, dynamic> toJson() {
    return {
      'cpuPercent': cpuPercent,
      'memoryRssBytes': memoryRssBytes,
      'uptimeSeconds': uptime.inSeconds,
    };
  }
}

/// Результат проверки “здоровья” по метрикам.
class HealthStatus {
  final String status; // ok | warning | critical
  final List<String> warnings;

  const HealthStatus({
    required this.status,
    required this.warnings,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'warnings': warnings,
    };
  }
}

/// Мониторинг производительности приложения.
///
/// - На десктопе: uptime + RSS памяти (CPU% без плагинов недоступен).
/// - На мобильных: упрощённый набор (uptime + RSS памяти).
class PerformanceMonitor {
  final Stopwatch _stopwatch = Stopwatch()..start();

  /// Пороговые значения для проверки “здоровья”.
  ///
  /// Значения по умолчанию подобраны консервативно и могут быть изменены.
  double warningMemoryMb = 600;
  double criticalMemoryMb = 1000;

  /// Возвращает текущие метрики.
  PerformanceMetrics getMetrics() {
    final uptime = _stopwatch.elapsed;

    // Web не поддерживает dart:io, но данный проект сейчас ориентирован на
    // mobile/desktop. Если понадобится web, сделаем conditional imports.
    final int? rssBytes = PlatformUtils.isWeb() ? null : ProcessInfo.currentRss;

    return PerformanceMetrics(
      // CPU% без плагинов недоступен (кросс-платформенно).
      cpuPercent: null,
      memoryRssBytes: rssBytes,
      uptime: uptime,
    );
  }

  /// Возвращает метрики в человекочитаемом виде (МБ и секунды).
  Map<String, dynamic> getMetricsSummary() {
    final m = getMetrics();
    final rssMb =
        m.memoryRssBytes == null ? null : (m.memoryRssBytes! / (1024 * 1024));
    return {
      'cpuPercent': m.cpuPercent,
      'memoryRssMb': rssMb,
      'uptimeSeconds': m.uptime.inSeconds,
      'isMobile': PlatformUtils.isMobile(),
      'isDesktop': PlatformUtils.isDesktop(),
      'isWeb': PlatformUtils.isWeb(),
    };
  }

  /// Проверяет “здоровье” приложения по текущим метрикам.
  ///
  /// В текущей версии проверяется только память и uptime.
  HealthStatus checkHealth() {
    final m = getMetrics();
    final warnings = <String>[];

    final rssMb =
        m.memoryRssBytes == null ? null : (m.memoryRssBytes! / (1024 * 1024));

    if (rssMb != null) {
      if (rssMb >= criticalMemoryMb) {
        warnings.add('High memory usage: ${rssMb.toStringAsFixed(1)} MB');
        return HealthStatus(status: 'critical', warnings: warnings);
      }

      if (rssMb >= warningMemoryMb) {
        warnings.add('Elevated memory usage: ${rssMb.toStringAsFixed(1)} MB');
        return HealthStatus(status: 'warning', warnings: warnings);
      }
    }

    return const HealthStatus(status: 'ok', warnings: []);
  }

  /// Сбрасывает таймер uptime (например, при старте новой сессии).
  void resetUptime() {
    _stopwatch
      ..stop()
      ..reset()
      ..start();
  }
}
