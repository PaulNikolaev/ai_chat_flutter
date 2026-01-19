import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфигурация окружения приложения.
///
/// Загружает переменные из `.env` с помощью `flutter_dotenv`.
/// Сам файл `.env` должен оставаться локальным (он в `.gitignore`).
///
/// Рекомендуется хранить в репозитории шаблон конфигурации (например, `.env.example`).
class EnvConfig {
  static bool _loaded = false;

  /// Загружает `.env` из корня проекта.
  ///
  /// Если `.env` отсутствует, выбрасывает [EnvConfigException] с понятным сообщением.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (e) {
      throw EnvConfigException(
        'Failed to load .env. Create a .env file in the project root (it is gitignored).',
      );
    }
  }

  /// Получает строковую переменную окружения.
  ///
  /// Если переменная обязательная и отсутствует — выбрасывает [EnvConfigException].
  static String getString(String key, {bool required = false, String? fallback}) {
    final value = dotenv.env[key] ?? fallback;
    if (required && (value == null || value.trim().isEmpty)) {
      throw EnvConfigException('Missing required env var: $key');
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
  static String get openRouterBaseUrl =>
      getString('OPENROUTER_BASE_URL', fallback: 'https://openrouter.ai/api/v1');

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
  /// На текущем этапе мы не заставляем иметь оба ключа сразу — достаточно одного.
  static void validate() {
    final openRouterKey = openRouterApiKey.trim();
    final vsegptKey = vsegptApiKey.trim();

    if (openRouterKey.isEmpty && vsegptKey.isEmpty) {
      throw EnvConfigException(
        'Missing API key. Provide OPENROUTER_API_KEY or VSEGPT_API_KEY in .env.',
      );
    }
  }
}

class EnvConfigException implements Exception {
  final String message;
  EnvConfigException(this.message);

  @override
  String toString() => 'EnvConfigException: $message';
}

