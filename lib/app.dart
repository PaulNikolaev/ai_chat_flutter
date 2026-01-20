import 'package:flutter/material.dart';

import 'package:ai_chat/api/api.dart';
import 'package:ai_chat/auth/auth.dart';
import 'package:ai_chat/config/config.dart';
import 'package:ai_chat/navigation/navigation.dart';
import 'package:ai_chat/ui/ui.dart';
import 'package:ai_chat/utils/utils.dart';

/// Главный класс приложения с управлением состоянием и навигацией.
///
/// Отвечает за:
/// - Проверку аутентификации при запуске
/// - Навигацию между экранами логина и главной страницы (HomeScreen)
/// - Управление API клиентом и его синхронизацию между всеми экранами через AppRouter
/// - Оптимизированную инициализацию приложения с переиспользованием логики создания клиента
/// - Обработку выхода из приложения с корректным освобождением ресурсов
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AuthManager? _authManager;
  OpenRouterClient? _apiClient;
  bool _isAuthenticated = false;
  AppLogger? _logger;

  /// Глобальный ключ навигатора для программной навигации.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _logger?.info('Application shutting down');
    // Запускаем асинхронное освобождение ресурсов
    // Не ждем завершения, чтобы не блокировать dispose()
    _disposeResources().catchError((e) {
      debugPrint('Error disposing resources: $e');
    });
    super.dispose();
  }

  /// Освобождает ресурсы приложения: закрывает БД, логгер и API клиент.
  ///
  /// Вызывается автоматически при dispose() виджета.
  /// Гарантирует корректное освобождение всех ресурсов.
  /// Выполняется асинхронно, чтобы не блокировать dispose().
  Future<void> _disposeResources() async {
    try {
      // Закрываем API клиент (синхронно)
      _apiClient?.dispose();
      _apiClient = null;

      // Закрываем базу данных (асинхронно)
      await DatabaseHelper.instance.close();

      // Закрываем логгер (освобождает файловые потоки, асинхронно)
      await _logger?.dispose();
      _logger = null;
    } catch (e) {
      // Игнорируем ошибки при освобождении ресурсов
      // чтобы не прерывать процесс завершения приложения
      debugPrint('Error disposing resources: $e');
    }
  }

  /// Инициализирует приложение: загружает конфигурацию и проверяет аутентификацию.
  Future<void> _initializeApp() async {
    try {
      // Инициализируем логирование
      _logger = await AppLogger.create();
      _logger?.info('Application starting...');

      // Загружаем конфигурацию окружения
      try {
        await EnvConfig.load();
        _logger?.info('Environment configuration loaded');
      } catch (e) {
        _logger?.warning('Failed to load .env file: $e');
        // Игнорируем ошибки загрузки .env, если он не обязателен
      }

      // Создаем AuthManager после загрузки конфигурации
      _authManager = AuthManager();

      // Проверяем аутентификацию
      await _checkAuthentication();
    } catch (e, stackTrace) {
      _logger?.error(
        'Fatal error during application initialization',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Создает API клиент на основе сохраненных данных аутентификации.
  ///
  /// Оптимизированный метод для создания клиента с учетом провайдера.
  /// Используется как при инициализации, так и при обновлении клиента.
  Future<OpenRouterClient?> _createApiClient() async {
    if (_authManager == null) return null;

    try {
      final apiKey = await _authManager!.getStoredApiKey();
      final provider = await _authManager!.getStoredProvider();

      if (apiKey.isEmpty) {
        _logger?.warning('API key is empty, cannot initialize client');
        return null;
      }

      // Создаем клиент в зависимости от провайдера
      if (provider == 'vsegpt') {
        // Для VSEGPT базовый URL должен быть https://api.vsegpt.ru/v1
        // (без /chat в конце, так как endpoint добавляется автоматически)
        final vsegptBaseUrl = EnvConfig.vsegptBaseUrl.trim().isNotEmpty
            ? EnvConfig.vsegptBaseUrl.trim()
            : 'https://api.vsegpt.ru/v1';
        // Если пользователь указал URL с /chat, убираем его
        final cleanBaseUrl = vsegptBaseUrl.endsWith('/chat')
            ? vsegptBaseUrl.substring(
                0, vsegptBaseUrl.length - 5) // убираем '/chat'
            : vsegptBaseUrl;
        final client = OpenRouterClient(
          apiKey: apiKey,
          baseUrl: cleanBaseUrl,
          provider: 'vsegpt',
        );
        _logger?.info('VSEGPT API client created with baseUrl: $cleanBaseUrl');
        return client;
      } else {
        final client = OpenRouterClient(
          apiKey: apiKey,
          provider: 'openrouter',
        );
        _logger?.info('OpenRouter API client created');
        return client;
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to create API client',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Обновляет API клиент в роутере и всех зависимых компонентах.
  ///
  /// Гарантирует синхронизацию API клиента между всеми экранами приложения.
  void _updateApiClientInRouter(OpenRouterClient? client) {
    AppRouter.apiClient = client;
    _logger?.debug('API client updated in router');
  }

  /// Обновляет API клиент при изменении провайдера.
  ///
  /// Вызывается из SettingsScreen после успешного переключения провайдера.
  /// Пересоздает API клиент с новым провайдером и обновляет его во всех экранах.
  /// Очищает историю чата, так как модели разных провайдеров несовместимы.
  Future<void> _refreshApiClient() async {
    if (_authManager == null) return;

    try {
      _logger?.info('Refreshing API client after provider change');

      // Очищаем кэш моделей в старом клиенте перед освобождением
      _apiClient?.clearModelCache();

      // Очищаем историю чата при переключении провайдера,
      // так как модели разных провайдеров несовместимы
      _logger?.info('Clearing chat history due to provider change');
      await ChatCache.instance.clearHistory();

      // Освобождаем старый клиент
      _apiClient?.dispose();

      // Создаем новый клиент с обновленным провайдером
      final newClient = await _createApiClient();

      if (mounted) {
        setState(() {
          _apiClient = newClient;
        });

        // Обновляем клиент в роутере и всех экранах
        _updateApiClientInRouter(_apiClient);

        _logger?.info(
            'API client refreshed successfully with provider: ${newClient?.provider}');
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to refresh API client',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Проверяет статус аутентификации и инициализирует API клиент при необходимости.
  Future<void> _checkAuthentication() async {
    if (_authManager == null) return;

    try {
      _logger?.debug('Checking authentication status...');
      final isAuthenticated = await _authManager!.isAuthenticated();

      if (isAuthenticated) {
        _logger?.info('User is authenticated, initializing API client');
        final client = await _createApiClient();

        if (mounted) {
          setState(() {
            _apiClient = client;
            _isAuthenticated = true;
          });
          // Обновляем клиент в роутере после обновления состояния
          _updateApiClientInRouter(_apiClient);
        }
      } else {
        _logger?.info('User is not authenticated, showing login screen');
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
          });
        }
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Error during authentication check',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
  }

  /// Обрабатывает успешный вход пользователя.
  ///
  /// Создает API клиент из сохраненного ключа и переходит к экрану чата.
  /// Оптимизирован для использования общего метода создания клиента.
  Future<void> _handleLoginSuccess() async {
    if (_authManager == null) return;

    try {
      _logger?.info('Login successful, initializing API client');
      final client = await _createApiClient();

      if (client != null) {
        if (mounted) {
          setState(() {
            _apiClient = client;
            _isAuthenticated = true;
          });
          // Обновляем клиент в роутере после обновления состояния
          _updateApiClientInRouter(_apiClient);
          _logger?.info('User logged in successfully');

          // Переходим на главный экран после успешного входа
          _navigatorKey.currentState?.pushReplacementNamed(AppRoutes.home);
        }
      } else {
        _logger?.warning('API key is empty or invalid after login');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка: API ключ не найден или недействителен'),
              backgroundColor: AppStyles.errorColor,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Error during login success handling',
        error: e,
        stackTrace: stackTrace,
      );
      // Обработка ошибок при создании клиента
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка инициализации API клиента: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Обрабатывает выход из приложения.
  ///
  /// Очищает состояние аутентификации и возвращает к экрану логина.
  /// Гарантирует корректное освобождение ресурсов и обновление роутера.
  Future<void> _handleLogout() async {
    try {
      _logger?.info('User logging out');

      // Сохраняем ссылку на клиент перед очисткой состояния
      final clientToDispose = _apiClient;

      if (mounted) {
        setState(() {
          _apiClient = null;
          _isAuthenticated = false;
        });
        // Обновляем роутер после очистки состояния
        _updateApiClientInRouter(null);

        // Переходим на экран входа после выхода
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }

      // Освобождаем ресурсы API клиента после обновления состояния
      // Это предотвращает закрытие клиента во время активных запросов
      await Future.delayed(const Duration(milliseconds: 100));
      clientToDispose?.dispose();

      _logger?.info('Logout completed');
    } catch (e, stackTrace) {
      _logger?.error(
        'Error during logout',
        error: e,
        stackTrace: stackTrace,
      );
      // Все равно очищаем состояние даже при ошибке
      if (mounted) {
        setState(() {
          _apiClient = null;
          _isAuthenticated = false;
        });
        _updateApiClientInRouter(null);

        // Переходим на экран входа даже при ошибке
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Обновляем роутер с текущими значениями перед построением
    // Это гарантирует, что все экраны получат актуальные данные
    _updateApiClientInRouter(_apiClient);
    AppRouter.onLoginSuccess = _handleLoginSuccess;
    AppRouter.onLogout = _handleLogout;
    AppRouter.onProviderChanged = _refreshApiClient;

    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: _navigatorKey,
      // Используем initialRoute для правильной навигации в многостраничном режиме
      initialRoute: _isAuthenticated ? AppRoutes.home : AppRoutes.login,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // Убираем home, так как используем initialRoute для навигации
      // Это обеспечивает правильную работу навигации в многостраничном режиме
    );
  }
}
