import 'package:flutter/material.dart';

import 'api/openrouter_client.dart';
import 'auth/auth_manager.dart';
import 'config/env.dart';
import 'screens/chat_screen.dart';
import 'ui/login/login_screen.dart';
import 'ui/theme.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Инициализирует приложение: загружает конфигурацию и проверяет аутентификацию.
  Future<void> _initializeApp() async {
    try {
      // Загружаем конфигурацию окружения
      await EnvConfig.load();
    } catch (e) {
      // Игнорируем ошибки загрузки .env, если он не обязателен
    }

    // Проверяем аутентификацию
    await _checkAuthentication();
  }

  /// Проверяет статус аутентификации и инициализирует API клиент при необходимости.
  Future<void> _checkAuthentication() async {
    try {
      final isAuthenticated = await _authManager.isAuthenticated();
      
      if (isAuthenticated) {
        // Получаем сохраненный API ключ и создаем клиент
        final apiKey = await _authManager.getStoredApiKey();
        if (apiKey.isNotEmpty) {
          _apiClient = OpenRouterClient(apiKey: apiKey);
        }
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
          _isLoading = false;
        });
      }
    } catch (e) {
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
      final apiKey = await _authManager.getStoredApiKey();
      if (apiKey.isNotEmpty) {
        if (mounted) {
          setState(() {
            _apiClient = OpenRouterClient(apiKey: apiKey);
            _isAuthenticated = true;
          });
        }
      }
    } catch (e) {
      // Обработка ошибок при создании клиента
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка инициализации API клиента: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Обрабатывает выход из приложения.
  ///
  /// Очищает состояние аутентификации и возвращает к экрану логина.
  Future<void> _handleLogout() async {
    if (mounted) {
      setState(() {
        _apiClient = null;
        _isAuthenticated = false;
      });
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
