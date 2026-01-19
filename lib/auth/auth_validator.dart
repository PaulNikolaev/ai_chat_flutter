import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Результат валидации API ключа.
class ApiKeyValidationResult {
  /// Успешна ли валидация.
  final bool isValid;

  /// Сообщение (баланс или ошибка).
  final String message;

  /// Баланс в виде числа (если валидно).
  final double balance;

  /// Провайдер API ('openrouter' или 'vsegpt').
  final String provider;

  const ApiKeyValidationResult({
    required this.isValid,
    required this.message,
    required this.balance,
    required this.provider,
  });
}

/// Валидатор для учетных данных аутентификации.
///
/// Предоставляет методы для валидации API ключей, генерации PIN кодов,
/// и хэширования/проверки PIN кодов.
///
/// Пример использования:
/// ```dart
/// final validator = AuthValidator();
/// final result = await validator.validateApiKey('sk-or-v1-...');
/// if (result.isValid) {
///   print('Баланс: ${result.message}');
/// }
/// ```
class AuthValidator {
  /// Базовый URL для OpenRouter API.
  final String openRouterBaseUrl;

  /// Базовый URL для VSEGPT API.
  final String? vsegptBaseUrl;

  /// HTTP клиент для запросов.
  final http.Client _client;

  /// Создает экземпляр [AuthValidator].
  ///
  /// Параметры:
  /// - [openRouterBaseUrl]: Базовый URL для OpenRouter API.
  ///   По умолчанию: 'https://openrouter.ai/api/v1'.
  /// - [vsegptBaseUrl]: Базовый URL для VSEGPT API (опционально).
  /// - [httpClient]: HTTP клиент для запросов (опционально).
  AuthValidator({
    String? openRouterBaseUrl,
    this.vsegptBaseUrl,
    http.Client? httpClient,
  })  : openRouterBaseUrl = openRouterBaseUrl ?? 'https://openrouter.ai/api/v1',
        _client = httpClient ?? http.Client();

  /// Определяет провайдера API по префиксу ключа.
  ///
  /// - Ключи VSEGPT начинаются с 'sk-or-vv-...'
  /// - Ключи OpenRouter начинаются с 'sk-or-v1-...'
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для проверки.
  ///
  /// Возвращает 'vsegpt' или 'openrouter', или null, если префикс не распознан.
  static String? detectProvider(String apiKey) {
    final trimmed = apiKey.trim();
    if (trimmed.startsWith('sk-or-vv-')) {
      return 'vsegpt';
    } else if (trimmed.startsWith('sk-or-v1-')) {
      return 'openrouter';
    }
    return null;
  }

  /// Валидирует API ключ путем проверки баланса через API.
  ///
  /// Делает запрос к API для проверки валидности ключа и получения баланса.
  /// Определяет провайдера по префиксу ключа и использует соответствующий endpoint.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для валидации.
  ///
  /// Возвращает [ApiKeyValidationResult] с результатом валидации.
  Future<ApiKeyValidationResult> validateApiKey(String apiKey) async {
    final provider = detectProvider(apiKey);
    if (provider == null) {
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'Invalid API key format. Key must start with sk-or-vv- (VSEGPT) or sk-or-v1- (OpenRouter)',
        balance: 0.0,
        provider: 'unknown',
      );
    }

    try {
      if (provider == 'vsegpt') {
        return await _validateVsegptKey(apiKey);
      } else {
        return await _validateOpenRouterKey(apiKey);
      }
    } catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Error validating key: $e',
        balance: 0.0,
        provider: provider,
      );
    }
  }

  /// Валидирует OpenRouter API ключ через проверку баланса.
  Future<ApiKeyValidationResult> _validateOpenRouterKey(String apiKey) async {
    final uri = Uri.parse('$openRouterBaseUrl/credits');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;

        if (data != null) {
          final totalCredits = (data['total_credits'] as num?)?.toDouble() ?? 0.0;
          final totalUsage = (data['total_usage'] as num?)?.toDouble() ?? 0.0;
          final balance = totalCredits - totalUsage;
          final balanceStr = balance.toStringAsFixed(2);

          return ApiKeyValidationResult(
            isValid: balance >= 0,
            message: balanceStr,
            balance: balance,
            provider: 'openrouter',
          );
        }
      }

      return const ApiKeyValidationResult(
        isValid: false,
        message: 'Invalid API key or insufficient permissions',
        balance: 0.0,
        provider: 'openrouter',
      );
    } catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Error validating key: $e',
        balance: 0.0,
        provider: 'openrouter',
      );
    }
  }

  /// Валидирует VSEGPT API ключ через проверку баланса.
  ///
  /// Использует endpoint VSEGPT для проверки баланса.
  /// Если vsegptBaseUrl не задан, возвращает ошибку.
  Future<ApiKeyValidationResult> _validateVsegptKey(String apiKey) async {
    if (vsegptBaseUrl == null || vsegptBaseUrl!.isEmpty) {
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'VSEGPT base URL is not configured',
        balance: 0.0,
        provider: 'vsegpt',
      );
    }

    // VSEGPT может иметь другой endpoint для баланса
    // Здесь используется базовый URL, но может потребоваться адаптация
    final uri = Uri.parse(vsegptBaseUrl!);
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      // Для VSEGPT может потребоваться другой метод проверки
      // Пока используем простую проверку доступности API
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      // Если запрос успешен, считаем ключ валидным
      // В реальной реализации здесь должна быть проверка баланса через VSEGPT API
      if (response.statusCode == 200 || response.statusCode == 401) {
        // 401 означает, что ключ неверный
        if (response.statusCode == 401) {
          return const ApiKeyValidationResult(
            isValid: false,
            message: 'Invalid VSEGPT API key',
            balance: 0.0,
            provider: 'vsegpt',
          );
        }

        // Для VSEGPT баланс может быть в другом формате
        // Пока возвращаем успешную валидацию без конкретного баланса
        return const ApiKeyValidationResult(
          isValid: true,
          message: 'Valid VSEGPT API key',
          balance: 0.0,
          provider: 'vsegpt',
        );
      }

      return const ApiKeyValidationResult(
        isValid: false,
        message: 'Invalid VSEGPT API key or insufficient permissions',
        balance: 0.0,
        provider: 'vsegpt',
      );
    } catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Error validating VSEGPT key: $e',
        balance: 0.0,
        provider: 'vsegpt',
      );
    }
  }

  /// Генерирует случайный 4-значный PIN код.
  ///
  /// Возвращает PIN код в виде строки (1000-9999).
  ///
  /// Пример:
  /// ```dart
  /// final pin = validator.generatePin();
  /// print('Сгенерированный PIN: $pin');
  /// ```
  static String generatePin() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Хэширует PIN код через SHA-256.
  ///
  /// Используется для создания хэша PIN перед сохранением.
  ///
  /// Параметры:
  /// - [pin]: PIN код для хэширования.
  ///
  /// Возвращает хэш PIN в виде шестнадцатеричной строки.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Проверяет PIN код против сохраненного хэша.
  ///
  /// Параметры:
  /// - [inputPin]: PIN код для проверки.
  /// - [storedHash]: Сохраненный хэш для сравнения.
  ///
  /// Возвращает true, если PIN совпадает с хэшем, иначе false.
  static bool verifyPin(String inputPin, String storedHash) {
    final inputHash = hashPin(inputPin);
    return inputHash == storedHash;
  }

  /// Валидирует формат PIN кода.
  ///
  /// PIN должен быть 4-значным числом (1000-9999).
  ///
  /// Параметры:
  /// - [pin]: PIN код для проверки.
  ///
  /// Возвращает true, если формат валиден, иначе false.
  static bool validatePinFormat(String pin) {
    if (pin.length != 4) {
      return false;
    }

    // Проверяем, что все символы - цифры
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return false;
    }

    // Проверяем, что PIN в диапазоне 1000-9999
    final pinNumber = int.tryParse(pin);
    if (pinNumber == null || pinNumber < 1000 || pinNumber > 9999) {
      return false;
    }

    return true;
  }

  /// Освобождает ресурсы HTTP клиента.
  void dispose() {
    _client.close();
  }
}
