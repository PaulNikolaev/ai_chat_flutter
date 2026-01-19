import 'package:flutter/material.dart';

import 'api/openrouter_client.dart';
import 'auth/auth_manager.dart';
import 'config/env.dart';
import 'screens/chat_screen.dart';
import 'ui/login/login_screen.dart';
import 'ui/styles.dart';
import 'ui/theme.dart';
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
  final AuthManager _authManager = AuthManager();
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
    super.dispose();
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
    try {
      _logger?.debug('Checking authentication status...');
      final isAuthenticated = await _authManager.isAuthenticated();
      
      if (isAuthenticated) {
        _logger?.info('User is authenticated, initializing API client');
        // Получаем сохраненный API ключ и создаем клиент
        try {
          final apiKey = await _authManager.getStoredApiKey();
          if (apiKey.isNotEmpty) {
            _apiClient = OpenRouterClient(apiKey: apiKey);
            _logger?.info('API client initialized successfully');
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
    try {
      _logger?.info('Login successful, initializing API client');
      final apiKey = await _authManager.getStoredApiKey();
      if (apiKey.isNotEmpty) {
        if (mounted) {
          setState(() {
            _apiClient = OpenRouterClient(apiKey: apiKey);
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
      // Освобождаем ресурсы API клиента
      _apiClient?.dispose();
      
      if (mounted) {
        setState(() {
          _apiClient = null;
          _isAuthenticated = false;
        });
      }
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
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _isAuthenticated
              ? ChatScreen(
                  apiClient: _apiClient,
                  onLogout: _handleLogout,
                )
              : LoginScreen(
                  onLoginSuccess: _handleLoginSuccess,
                ),
    );
  }
}
