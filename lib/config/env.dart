import 'dart:io' show FileSystemException;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфигурация окружения приложения.
///
/// Загружает переменные из `.env` с помощью `flutter_dotenv`.
/// Сам файл `.env` должен оставаться локальным (он в `.gitignore`).
///
/// Рекомендуется хранить в репозитории шаблон конфигурации (например, `.env.example`).
class EnvConfig {
  static bool _loaded = false;

  /// Проверяет, загружена ли конфигурация окружения.
  static bool get isLoaded => _loaded;

  /// Загружает `.env` из корня проекта.
  ///
  /// Если `.env` отсутствует, выбрасывает [EnvConfigException] с понятным сообщением.
  /// Рекомендуется создать `.env` файл на основе `.env.example` в корне проекта.
  ///
  /// **Пример использования:**
  /// ```dart
  /// try {
  ///   await EnvConfig.load();
  /// } on EnvConfigException catch (e) {
  ///   print('Error loading config: $e');
  ///   // Предложить пользователю создать .env файл
  /// }
  /// ```
  ///
  /// **Обработка отсутствия .env:**
  /// Метод выбрасывает исключение, если файл `.env` не найден.
  /// Это позволяет приложению явно обработать ситуацию и показать
  /// пользователю понятное сообщение с инструкциями.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } on FileSystemException catch (e) {
      // Файл не найден
      throw EnvConfigException(
        'Failed to load .env file: ${e.message}. '
        'Create a .env file in the project root based on .env.example. '
        'The .env file is gitignored and should contain your API keys.',
      );
    } catch (e) {
      // Другие ошибки (неверный формат и т.д.)
      throw EnvConfigException(
        'Failed to load .env file: $e. '
        'Check the .env file format and ensure it is valid. '
        'See .env.example for reference.',
      );
    }
  }

  /// Получает строковую переменную окружения.
  ///
  /// Если переменная обязательная и отсутствует — выбрасывает [EnvConfigException].
  /// Если `.env` не загружен, использует fallback или возвращает пустую строку.
  ///
  /// **Параметры:**
  /// - [key]: Ключ переменной окружения.
  /// - [required]: Если `true`, переменная обязательна и должно быть выбрашено исключение при отсутствии.
  /// - [fallback]: Значение по умолчанию, если переменная не найдена.
  ///
  /// **Примеры:**
  /// ```dart
  /// // Обязательная переменная
  /// final apiKey = EnvConfig.getString('API_KEY', required: true);
  ///
  /// // Опциональная переменная с fallback
  /// final baseUrl = EnvConfig.getString('BASE_URL', fallback: 'https://api.example.com');
  /// ```
  static String getString(String key,
      {bool required = false, String? fallback}) {
    String? value;
    if (_loaded) {
      value = dotenv.env[key] ?? fallback;
    } else {
      value = fallback;
    }
    if (required && (value == null || value.trim().isEmpty)) {
      throw EnvConfigException(
        'Missing required environment variable: $key. '
        'Add it to your .env file (see .env.example for reference).',
      );
    }
    return value ?? '';
  }

  /// Получает bool переменную окружения.
  ///
  /// Допустимые значения: true/false/1/0/yes/no (в любом регистре).
  static bool getBool(String key, {bool fallback = false}) {
    final raw = dotenv.env[key];
    if (raw == null) return fallback;
    final v = raw.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
    return fallback;
  }

  /// Базовый URL OpenRouter.
  static String get openRouterBaseUrl => getString('OPENROUTER_BASE_URL',
      fallback: 'https://openrouter.ai/api/v1');

  /// API ключ OpenRouter (если используется).
  static String get openRouterApiKey => getString('OPENROUTER_API_KEY');

  /// Базовый URL VSEGPT (если используется).
  static String get vsegptBaseUrl => getString('VSEGPT_BASE_URL');

  /// API ключ VSEGPT (если используется).
  static String get vsegptApiKey => getString('VSEGPT_API_KEY');

  /// Уровень логирования (DEBUG/INFO/WARNING/ERROR).
  static String get logLevel => getString('LOG_LEVEL', fallback: 'INFO');

  /// Режим отладки.
  static bool get debug => getBool('DEBUG', fallback: false);

  /// Максимальное количество токенов для генерации.
  static int get maxTokens {
    final value = getString('MAX_TOKENS');
    if (value.isEmpty) return 1000;
    return int.tryParse(value) ?? 1000;
  }

  /// Температура для генерации (0.0 - 2.0).
  static double get temperature {
    final value = getString('TEMPERATURE');
    if (value.isEmpty) return 0.7;
    return double.tryParse(value) ?? 0.7;
  }

  /// Валидация обязательных переменных окружения.
  ///
  /// Проверяет, что хотя бы один API ключ предоставлен (OpenRouter или VSEGPT).
  /// На текущем этапе не требуется иметь оба ключа одновременно.
  ///
  /// **Выбрасывает:**
  /// [EnvConfigException] если ни один API ключ не предоставлен.
  ///
  /// **Пример использования:**
  /// ```dart
  /// await EnvConfig.load();
  /// try {
  ///   EnvConfig.validate();
  /// } on EnvConfigException catch (e) {
  ///   print('Configuration error: $e');
  ///   // Показать пользователю сообщение об ошибке
  /// }
  /// ```
  static void validate() {
    final openRouterKey = openRouterApiKey.trim();
    final vsegptKey = vsegptApiKey.trim();

    if (openRouterKey.isEmpty && vsegptKey.isEmpty) {
      throw EnvConfigException(
        'Missing required API key. '
        'Provide at least one of the following in .env: '
        'OPENROUTER_API_KEY or VSEGPT_API_KEY. '
        'See .env.example for reference.',
      );
    }
  }

  /// Получает режим окружения (development или production).
  ///
  /// Определяется на основе переменной окружения `ENVIRONMENT` или значения `DEBUG`.
  /// Если `DEBUG=true`, возвращается 'development'.
  /// Если `ENVIRONMENT` не задан и `DEBUG=false`, возвращается 'production'.
  ///
  /// **Возвращает:**
  /// - 'development' - для разработки (DEBUG=true или ENVIRONMENT=development)
  /// - 'production' - для production (по умолчанию)
  static String get environment {
    final env = getString('ENVIRONMENT', fallback: '').toLowerCase();
    if (env == 'development' || env == 'dev' || debug) {
      return 'development';
    }
    if (env == 'production' || env == 'prod') {
      return 'production';
    }
    // По умолчанию production, если не указано явно
    return 'production';
  }

  /// Проверяет, запущено ли приложение в режиме разработки.
  ///
  /// Возвращает `true`, если `ENVIRONMENT=development` или `DEBUG=true`.
  static bool get isDevelopment => environment == 'development';

  /// Проверяет, запущено ли приложение в production режиме.
  ///
  /// Возвращает `true`, если `ENVIRONMENT=production` или по умолчанию.
  static bool get isProduction => environment == 'production';
}

class EnvConfigException implements Exception {
  final String message;
  EnvConfigException(this.message);

  @override
  String toString() => 'EnvConfigException: $message';
}
