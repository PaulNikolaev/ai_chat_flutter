import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:ai_chat/utils/utils.dart';

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
/// **Основные функции:**
/// - Валидация API ключей через соответствующие API endpoints
/// - Проверка баланса аккаунта (должен быть >= 0)
/// - Генерация случайных 4-значных PIN кодов (1000-9999)
/// - Хэширование PIN кодов через SHA-256
/// - Проверка формата PIN кодов
///
/// **Поддерживаемые провайдеры:**
/// - **OpenRouter**: использует endpoint `/credits` для проверки баланса
///   - Ключи начинаются с `sk-or-v1-...`
///   - Баланс вычисляется как `total_credits - total_usage`
/// - **VSEGPT**: использует endpoint `/v1/balance` для проверки баланса
///   - Ключи начинаются с `sk-or-vv-...`
///   - Поддерживает различные форматы ответа API
///
/// **Обработка ошибок:**
/// - Сетевые ошибки (таймауты, отсутствие соединения)
/// - HTTP ошибки (401, 403, 404, 429, 5xx)
/// - Ошибки парсинга ответов API
/// - Неверные форматы ключей
///
/// **Пример использования:**
/// ```dart
/// final validator = AuthValidator();
///
/// // Валидация API ключа
/// final result = await validator.validateApiKey('sk-or-v1-...');
/// if (result.isValid) {
///   print('Баланс: ${result.message}');
///   print('Провайдер: ${result.provider}');
/// } else {
///   print('Ошибка: ${result.message}');
/// }
///
/// // Генерация PIN
/// final pin = AuthValidator.generatePin();
/// final pinHash = AuthValidator.hashPin(pin);
///
/// // Проверка формата PIN
/// final isValid = AuthValidator.validatePinFormat('1234');
/// ```
class AuthValidator {
  /// Базовый URL для OpenRouter API.
  ///
  /// Используется для валидации OpenRouter API ключей.
  /// По умолчанию: 'https://openrouter.ai/api/v1'.
  final String openRouterBaseUrl;

  /// Базовый URL для VSEGPT API.
  ///
  /// Используется для валидации VSEGPT API ключей.
  /// Если не указан, валидация VSEGPT ключей будет недоступна.
  final String? vsegptBaseUrl;

  /// HTTP клиент для выполнения запросов к API.
  ///
  /// Используется для всех HTTP запросов к провайдерам.
  /// Должен быть закрыт через метод [dispose()] после использования.
  final http.Client _client;

  /// Создает экземпляр [AuthValidator].
  ///
  /// Параметры:
  /// - [openRouterBaseUrl]: Базовый URL для OpenRouter API.
  ///   По умолчанию: 'https://openrouter.ai/api/v1'.
  /// - [vsegptBaseUrl]: Базовый URL для VSEGPT API (опционально).
  ///   Если не указан, валидация VSEGPT ключей будет недоступна.
  /// - [httpClient]: HTTP клиент для запросов (опционально).
  ///   Если не указан, создается новый экземпляр http.Client().
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
    // Валидация входных данных: проверка на null и пустую строку
    if (apiKey.isEmpty || apiKey.trim().isEmpty) {
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'API key cannot be empty',
        balance: 0.0,
        provider: 'unknown',
      );
    }

    final provider = detectProvider(apiKey);
    if (provider == null) {
      return const ApiKeyValidationResult(
        isValid: false,
        message:
            'Invalid API key format. Key must start with sk-or-vv- (VSEGPT) or sk-or-v1- (OpenRouter)',
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
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            return const ApiKeyValidationResult(
              isValid: false,
              message: 'Invalid response format from OpenRouter API',
              balance: 0.0,
              provider: 'openrouter',
            );
          }

          final data = decoded['data'] as Map<String, dynamic>?;

          if (data == null) {
            // Пытаемся извлечь сообщение об ошибке, если есть
            String errorMessage =
                'Missing data field in OpenRouter API response';
            if (decoded.containsKey('error')) {
              final error = decoded['error'];
              if (error is Map<String, dynamic> &&
                  error.containsKey('message')) {
                errorMessage = error['message'] as String;
              } else if (error is String) {
                errorMessage = error;
              }
            } else if (decoded.containsKey('message')) {
              errorMessage = decoded['message'] as String;
            }

            return ApiKeyValidationResult(
              isValid: false,
              message: errorMessage,
              balance: 0.0,
              provider: 'openrouter',
            );
          }

          // Извлекаем баланс с проверкой на null и валидность типов
          final totalCreditsValue = data['total_credits'];
          final totalUsageValue = data['total_usage'];

          double totalCredits = 0.0;
          double totalUsage = 0.0;

          if (totalCreditsValue != null) {
            if (totalCreditsValue is num) {
              totalCredits = totalCreditsValue.toDouble();
            } else if (totalCreditsValue is String) {
              totalCredits = double.tryParse(totalCreditsValue) ?? 0.0;
            }
          }

          if (totalUsageValue != null) {
            if (totalUsageValue is num) {
              totalUsage = totalUsageValue.toDouble();
            } else if (totalUsageValue is String) {
              totalUsage = double.tryParse(totalUsageValue) ?? 0.0;
            }
          }

          final balance = totalCredits - totalUsage;
          final balanceStr = balance.toStringAsFixed(2);

          // Проверяем, что баланс неотрицательный (больше или равен нулю)
          final isValid = balance >= 0;

          return ApiKeyValidationResult(
            isValid: isValid,
            message: balanceStr,
            balance: balance,
            provider: 'openrouter',
          );
        } catch (e) {
          return ApiKeyValidationResult(
            isValid: false,
            message: 'Invalid response format from OpenRouter API: $e',
            balance: 0.0,
            provider: 'openrouter',
          );
        }
      }

      // Обработка различных HTTP статусов для лучшей диагностики
      // Пытаемся извлечь сообщение об ошибке из ответа
      String errorMessage =
          'Failed to validate OpenRouter key: HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        if (decoded != null) {
          if (decoded.containsKey('error')) {
            final error = decoded['error'];
            if (error is Map<String, dynamic> && error.containsKey('message')) {
              errorMessage = error['message'] as String;
            } else if (error is String) {
              errorMessage = error;
            }
          } else if (decoded.containsKey('message')) {
            errorMessage = decoded['message'] as String;
          }
        }
      } catch (e) {
        // Если не удалось распарсить, используем стандартное сообщение
      }

      if (response.statusCode == 401) {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorMessage.contains('401') ||
                  errorMessage.contains('Unauthorized')
              ? errorMessage
              : 'Invalid OpenRouter API key. ${errorMessage.isNotEmpty ? "Details: $errorMessage" : ""}',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else if (response.statusCode == 403) {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorMessage.contains('403') ||
                  errorMessage.contains('Forbidden')
              ? errorMessage
              : 'Insufficient permissions to check OpenRouter balance. ${errorMessage.isNotEmpty ? "Details: $errorMessage" : ""}',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else if (response.statusCode == 429) {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorMessage.contains('429') ||
                  errorMessage.contains('rate limit')
              ? errorMessage
              : 'Rate limit exceeded. Please try again later. ${errorMessage.isNotEmpty ? "Details: $errorMessage" : ""}',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else if (response.statusCode == 404) {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorMessage.contains('404') ||
                  errorMessage.contains('Not Found')
              ? errorMessage
              : 'OpenRouter API endpoint not found. Please check your base URL configuration. ${errorMessage.isNotEmpty ? "Details: $errorMessage" : ""}',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorMessage.contains('500') ||
                  errorMessage.contains('server error')
              ? errorMessage
              : 'OpenRouter server error (HTTP ${response.statusCode}). Please try again later. ${errorMessage.isNotEmpty ? "Details: $errorMessage" : ""}',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorMessage,
          balance: 0.0,
          provider: 'openrouter',
        );
      }
    } on http.ClientException catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Network error while validating OpenRouter key: $e',
        balance: 0.0,
        provider: 'openrouter',
      );
    } on TimeoutException catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Request timeout while validating OpenRouter key: $e',
        balance: 0.0,
        provider: 'openrouter',
      );
    } catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Error validating OpenRouter key: $e',
        balance: 0.0,
        provider: 'openrouter',
      );
    }
  }

  /// Валидирует VSEGPT API ключ через проверку баланса.
  ///
  /// Использует endpoint VSEGPT для проверки баланса.
  /// Если vsegptBaseUrl не задан, возвращает ошибку.
  ///
  /// Поддерживает различные форматы ответа API:
  /// - Формат OpenRouter (data.total_credits, data.total_usage)
  /// - Прямой формат (balance, credits)
  /// - Вложенный формат (account.balance)
  Future<ApiKeyValidationResult> _validateVsegptKey(String apiKey) async {
    if (vsegptBaseUrl == null || vsegptBaseUrl!.isEmpty) {
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'VSEGPT base URL is not configured',
        balance: 0.0,
        provider: 'vsegpt',
      );
    }

    // Формируем URI для проверки баланса
    // VSEGPT использует endpoint /v1/balance для проверки баланса
    Uri uri;
    final baseUri = Uri.parse(vsegptBaseUrl!);

    // Формируем правильный endpoint для баланса
    // VSEGPT API использует /v1/balance для проверки баланса
    // Если базовый URL уже содержит путь (например /v1/chat), заменяем его на /v1/balance
    // Иначе добавляем /v1/balance к базовому URL
    if (baseUri.path.contains('/v1/')) {
      // Если путь содержит /v1/, заменяем всё после /v1/ на balance
      // Например: https://api.vsegpt.ru/v1/chat -> https://api.vsegpt.ru/v1/balance
      final scheme = baseUri.scheme;
      final host = baseUri.host;
      final port = baseUri.hasPort ? baseUri.port : null;
      uri = Uri(
        scheme: scheme,
        host: host,
        port: port,
        path: '/v1/balance',
      );
    } else {
      // Иначе добавляем /v1/balance
      uri = baseUri.resolve('/v1/balance');
    }

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      // Обработка различных HTTP статусов
      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;

          // Пытаемся извлечь баланс из различных форматов ответа
          double? balance = _extractBalanceFromVsegptResponse(decoded);

          if (balance != null) {
            // Проверяем, что баланс неотрицательный (больше или равен нулю)
            final isValid = balance >= 0;

            if (isValid) {
              return ApiKeyValidationResult(
                isValid: true,
                message: balance.toStringAsFixed(2),
                balance: balance,
                provider: 'vsegpt',
              );
            } else {
              return ApiKeyValidationResult(
                isValid: false,
                message: 'VSEGPT API key has negative balance',
                balance: balance,
                provider: 'vsegpt',
              );
            }
          } else {
            // Если баланс не найден, но ответ успешен, считаем ключ валидным
            // (для совместимости с API, которые не возвращают баланс)
            return const ApiKeyValidationResult(
              isValid: true,
              message: 'Valid VSEGPT API key',
              balance: 0.0,
              provider: 'vsegpt',
            );
          }
        } catch (e) {
          // Ошибка парсинга JSON
          return ApiKeyValidationResult(
            isValid: false,
            message: 'Invalid response format from VSEGPT API: $e',
            balance: 0.0,
            provider: 'vsegpt',
          );
        }
      } else if (response.statusCode == 401) {
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Invalid VSEGPT API key',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else if (response.statusCode == 403) {
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Insufficient permissions to check VSEGPT balance',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else if (response.statusCode == 429) {
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Rate limit exceeded. Please try again later',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        return ApiKeyValidationResult(
          isValid: false,
          message:
              'VSEGPT server error (HTTP ${response.statusCode}). Please try again later',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else {
        return ApiKeyValidationResult(
          isValid: false,
          message:
              'Failed to validate VSEGPT key: HTTP ${response.statusCode}. Tried URL: $uri',
          balance: 0.0,
          provider: 'vsegpt',
        );
      }
    } on http.ClientException catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Network error while validating VSEGPT key: $e',
        balance: 0.0,
        provider: 'vsegpt',
      );
    } on TimeoutException catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Request timeout while validating VSEGPT key: $e',
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

  /// Извлекает баланс из ответа VSEGPT API.
  ///
  /// Поддерживает различные форматы ответа:
  /// - OpenRouter формат: { "data": { "total_credits": X, "total_usage": Y } }
  /// - Прямой формат: { "balance": X } или { "credits": X }
  /// - Вложенный формат: { "account": { "balance": X } }
  /// - VSEGPT формат: { "balance": X } или { "data": { "balance": X } }
  ///
  /// Возвращает баланс или null, если не удалось извлечь.
  double? _extractBalanceFromVsegptResponse(Map<String, dynamic> decoded) {
    // Формат OpenRouter: data.total_credits - data.total_usage
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data != null) {
      final totalCredits = (data['total_credits'] as num?)?.toDouble();
      final totalUsage = (data['total_usage'] as num?)?.toDouble();
      if (totalCredits != null) {
        return totalCredits - (totalUsage ?? 0.0);
      }
    }

    // Прямой формат: balance
    if (decoded.containsKey('balance')) {
      final balance = (decoded['balance'] as num?)?.toDouble();
      if (balance != null) return balance;
    }

    // Прямой формат: credits
    if (decoded.containsKey('credits')) {
      final credits = (decoded['credits'] as num?)?.toDouble();
      if (credits != null) return credits;
    }

    // Вложенный формат: account.balance
    final account = decoded['account'] as Map<String, dynamic>?;
    if (account != null) {
      final balance = (account['balance'] as num?)?.toDouble();
      if (balance != null) return balance;

      final credits = (account['credits'] as num?)?.toDouble();
      if (credits != null) return credits;
    }

    // Вложенный формат: result.balance
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result != null) {
      final balance = (result['balance'] as num?)?.toDouble();
      if (balance != null) return balance;
    }

    return null;
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
    return (AppConstants.pinMinValue +
            random.nextInt(AppConstants.pinMaxValue - AppConstants.pinMinValue))
        .toString();
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
  /// - Должен быть строкой из 4 цифр.
  /// - По умолчанию диапазон 1000-9999 (без ведущих нулей).
  /// - Если [allowLeadingZeros] = true, принимаем 0000-9999.
  ///
  /// Параметры:
  /// - [pin]: PIN код для проверки.
  /// - [allowLeadingZeros]: если true, допускаем PIN с ведущими нулями.
  ///
  /// Возвращает true, если формат валиден, иначе false.
  static bool validatePinFormat(String pin, {bool allowLeadingZeros = false}) {
    if (pin.length != 4) {
      return false;
    }

    // Проверяем, что все символы - цифры
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return false;
    }

    if (allowLeadingZeros) {
      return true;
    }

    // Проверяем, что PIN в диапазоне 1000-9999 (без ведущих нулей)
    final pinNumber = int.tryParse(pin);
    if (pinNumber == null ||
        pinNumber < AppConstants.pinMinValue ||
        pinNumber > AppConstants.pinMaxValue) {
      return false;
    }

    return true;
  }

  /// Освобождает ресурсы HTTP клиента.
  void dispose() {
    _client.close();
  }
}
