import 'package:flutter/material.dart';

import 'api/openrouter_client.dart';
import 'auth/auth_manager.dart';
import 'config/env.dart';
import 'navigation/app_router.dart';
import 'screens/home_screen.dart';
import 'ui/login/login_screen.dart';
import 'ui/styles.dart';
import 'ui/theme.dart';
import 'utils/database/database.dart';
import 'utils/logger.dart';

/// Главный класс приложения с управлением состоянием и навигацией.
///
/// Отвечает за:
/// - Проверку аутентификации при запуске
/// - Навигацию между экранами логина и чата
/// - Управление API клиентом
/// - Обработку выхода из приложения
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AuthManager? _authManager;
  OpenRouterClient? _apiClient;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  AppLogger? _logger;

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        // Получаем сохраненный API ключ и провайдера, создаем соответствующий клиент
        try {
          final apiKey = await _authManager!.getStoredApiKey();
          final provider = await _authManager!.getStoredProvider();
          
          if (apiKey.isNotEmpty) {
            // Создаем клиент в зависимости от провайдера
            if (provider == 'vsegpt') {
              // Для VSEGPT используем OpenRouterClient с VSEGPT base URL
              // Если baseUrl уже содержит путь (например /v1/chat), используем его как есть
              final vsegptBaseUrl = EnvConfig.vsegptBaseUrl.trim().isNotEmpty
                  ? EnvConfig.vsegptBaseUrl.trim()
                  : 'https://api.vsegpt.ru/v1/chat';
              _apiClient = OpenRouterClient(
                apiKey: apiKey,
                baseUrl: vsegptBaseUrl,
                provider: 'vsegpt',
              );
              _logger?.info('VSEGPT API client initialized successfully with baseUrl: $vsegptBaseUrl');
            } else {
              // Для OpenRouter используем стандартный клиент
              _apiClient = OpenRouterClient(
                apiKey: apiKey,
                provider: 'openrouter',
              );
              _logger?.info('OpenRouter API client initialized successfully');
            }
          } else {
            _logger?.warning('API key is empty, cannot initialize client');
          }
        } catch (e, stackTrace) {
          _logger?.error(
            'Failed to initialize API client',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } else {
        _logger?.info('User is not authenticated, showing login screen');
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
          _isLoading = false;
        });
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
          _isLoading = false;
        });
      }
    }
  }

  /// Обрабатывает успешный вход пользователя.
  ///
  /// Создает API клиент из сохраненного ключа и переходит к экрану чата.
  Future<void> _handleLoginSuccess() async {
    if (_authManager == null) return;
    
    try {
      _logger?.info('Login successful, initializing API client');
      final apiKey = await _authManager!.getStoredApiKey();
      final provider = await _authManager!.getStoredProvider();
      
      if (apiKey.isNotEmpty) {
        if (mounted) {
          setState(() {
            // Создаем клиент в зависимости от провайдера
            if (provider == 'vsegpt') {
              // Для VSEGPT используем OpenRouterClient с VSEGPT base URL
              // Если baseUrl уже содержит путь (например /v1/chat), используем его как есть
              final vsegptBaseUrl = EnvConfig.vsegptBaseUrl.trim().isNotEmpty
                  ? EnvConfig.vsegptBaseUrl.trim()
                  : 'https://api.vsegpt.ru/v1/chat';
              _apiClient = OpenRouterClient(
                apiKey: apiKey,
                baseUrl: vsegptBaseUrl,
                provider: 'vsegpt',
              );
              _logger?.info('VSEGPT API client initialized after login with baseUrl: $vsegptBaseUrl');
            } else {
              // Для OpenRouter используем стандартный клиент
              _apiClient = OpenRouterClient(
                apiKey: apiKey,
                provider: 'openrouter',
              );
              _logger?.info('OpenRouter API client initialized after login');
            }
            _isAuthenticated = true;
          });
          _logger?.info('User logged in successfully');
        }
      } else {
        _logger?.warning('API key is empty after login');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка: API ключ не найден'),
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Обновляем роутер с текущими значениями перед построением
    AppRouter.apiClient = _apiClient;
    AppRouter.onLoginSuccess = _handleLoginSuccess;
    AppRouter.onLogout = _handleLogout;

    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: _isAuthenticated ? AppRoutes.home : AppRoutes.login,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _isAuthenticated
              ? HomeScreen(
                  apiClient: _apiClient,
                  onLogout: _handleLogout,
                )
              : LoginScreen(
                  onLoginSuccess: _handleLoginSuccess,
                ),
    );
  }
}
