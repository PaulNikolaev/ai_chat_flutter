import 'package:flutter/material.dart';

import '../screens/expenses_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../ui/login/login_screen.dart';
import '../ui/transitions/page_transitions.dart';
import '../api/openrouter_client.dart';
import '../utils/analytics.dart';
import '../utils/monitor.dart';
import '../utils/expenses_calculator.dart';
import '../utils/platform.dart';

/// Константы для именованных маршрутов приложения.
class AppRoutes {
  /// Маршрут страницы входа (логин).
  static const String login = '/login';

  /// Маршрут главной страницы (чат).
  static const String home = '/home';

  /// Маршрут страницы настроек провайдера и API ключей.
  static const String settings = '/settings';

  /// Маршрут страницы статистики использования токенов.
  static const String statistics = '/statistics';

  /// Маршрут страницы графика расходов.
  static const String expenses = '/expenses';
}

/// Роутер приложения для управления навигацией между экранами.
///
/// Предоставляет именованные маршруты и фабричные методы для создания
/// экранов с передачей необходимых параметров (например, API клиента).
///
/// **Использование:**
/// ```dart
/// MaterialApp(
///   initialRoute: AppRoutes.login,
///   routes: AppRouter.routes,
///   onGenerateRoute: AppRouter.onGenerateRoute,
/// )
/// ```
class AppRouter {
  /// API клиент для передачи в экраны (может быть null до аутентификации).
  static OpenRouterClient? apiClient;

  /// Callback для обработки успешного входа.
  static VoidCallback? onLoginSuccess;

  /// Callback для обработки выхода из приложения.
  static VoidCallback? onLogout;

  /// Экземпляр аналитики для передачи в экраны.
  static Analytics? analytics;

  /// Экземпляр мониторинга производительности для передачи в экраны.
  static PerformanceMonitor? performanceMonitor;

  /// Экземпляр калькулятора расходов для передачи в экраны.
  static ExpensesCalculator? expensesCalculator;

  /// Базовые маршруты приложения без параметров.
  ///
  /// Используется для экранов, которым не требуется передача параметров.
  static Map<String, WidgetBuilder> get routes {
    return {
      AppRoutes.login: (context) => LoginScreen(
            onLoginSuccess: onLoginSuccess ?? () {},
          ),
    };
  }

  /// Генератор маршрутов для экранов с параметрами.
  ///
  /// Используется для создания экранов, которым требуется передача
  /// дополнительных параметров (например, API клиент).
  /// Использует плавные переходы для улучшения UX.
  ///
  /// **Параметры:**
  /// - [settings]: Настройки маршрута с именем и аргументами.
  ///
  /// **Возвращает:** Route для навигации к соответствующему экрану.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // Определяем тип перехода в зависимости от платформы
    final isMobile = PlatformUtils.isMobile();
    
    switch (settings.name) {
      case AppRoutes.home:
        return isMobile
            ? PageTransitions.fadeSlideRoute(
                builder: (context) => HomeScreen(
                  apiClient: apiClient,
                  onLogout: onLogout ?? () {},
                ),
                settings: settings,
              )
            : PageTransitions.fadeRoute(
                builder: (context) => HomeScreen(
                  apiClient: apiClient,
                  onLogout: onLogout ?? () {},
                ),
                settings: settings,
              );

      case AppRoutes.settings:
        return PageTransitions.fadeSlideRoute(
          builder: (context) => const SettingsScreen(),
          settings: settings,
        );

      case AppRoutes.statistics:
        return PageTransitions.fadeSlideRoute(
          builder: (context) => StatisticsScreen(
            apiClient: apiClient,
            analytics: analytics,
            performanceMonitor: performanceMonitor,
          ),
          settings: settings,
        );

      case AppRoutes.expenses:
        return PageTransitions.fadeSlideRoute(
          builder: (context) => ExpensesScreen(
            apiClient: apiClient,
            analytics: analytics,
            expensesCalculator: expensesCalculator,
          ),
          settings: settings,
        );

      default:
        // Если маршрут не найден, возвращаемся на страницу входа
        return PageTransitions.fadeRoute(
          builder: (context) => LoginScreen(
            onLoginSuccess: onLoginSuccess ?? () {},
          ),
          settings: settings,
        );
    }
  }

}
