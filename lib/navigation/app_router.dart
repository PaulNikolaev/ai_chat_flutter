import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
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
        // TODO: Заменить на SettingsScreen после реализации (Этап 2)
        return MaterialPageRoute(
          builder: (context) => _buildPlaceholderScreen(
            context,
            title: 'Настройки',
            description: 'Страница настроек провайдера и API ключей',
            route: AppRoutes.settings,
          ),
        );

      case AppRoutes.statistics:
        // TODO: Заменить на StatisticsScreen после реализации (Этап 3)
        return MaterialPageRoute(
          builder: (context) => _buildPlaceholderScreen(
            context,
            title: 'Статистика',
            description: 'Статистика использования токенов моделями',
            route: AppRoutes.statistics,
          ),
        );

      case AppRoutes.expenses:
        // TODO: Заменить на ExpensesScreen после реализации (Этап 4)
        return MaterialPageRoute(
          builder: (context) => _buildPlaceholderScreen(
            context,
            title: 'Расходы',
            description: 'График расходов по дням',
            route: AppRoutes.expenses,
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

  /// Создает заглушку экрана для будущих реализаций.
  ///
  /// Используется для определения маршрутов, которые будут реализованы
  /// в следующих этапах разработки.
  ///
  /// **Параметры:**
  /// - [context]: Контекст построения виджета.
  /// - [title]: Заголовок экрана.
  /// - [description]: Описание назначения экрана.
  /// - [route]: Имя маршрута.
  ///
  /// **Возвращает:** Scaffold с заглушкой экрана.
  static Widget _buildPlaceholderScreen(
    BuildContext context, {
    required String title,
    required String description,
    required String route,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 64,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Маршрут: $route',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text(
                'Эта страница будет реализована в следующих этапах разработки.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
