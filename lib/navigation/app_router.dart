import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../ui/login/login_screen.dart';
import '../api/openrouter_client.dart';

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
  ///
  /// **Параметры:**
  /// - [settings]: Настройки маршрута с именем и аргументами.
  ///
  /// **Возвращает:** Route для навигации к соответствующему экрану.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (context) => ChatScreen(
            apiClient: apiClient,
            onLogout: onLogout ?? () {},
          ),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (context) => const SettingsScreen(),
        );

      case AppRoutes.statistics:
        return MaterialPageRoute(
          builder: (context) => StatisticsScreen(
            apiClient: apiClient,
          ),
        );

      case AppRoutes.expenses:
        return MaterialPageRoute(
          builder: (context) => ExpensesScreen(
            apiClient: apiClient,
          ),
        );

      default:
        // Если маршрут не найден, возвращаемся на страницу входа
        return MaterialPageRoute(
          builder: (context) => LoginScreen(
            onLoginSuccess: onLoginSuccess ?? () {},
          ),
        );
    }
  }

}
