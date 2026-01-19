import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
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
    developer.log('[VALIDATOR] Starting API key validation', name: 'AuthValidator');
    developer.log('[VALIDATOR] Key prefix: ${apiKey.substring(0, apiKey.length > 15 ? 15 : apiKey.length)}...', name: 'AuthValidator');
    
    final provider = detectProvider(apiKey);
    if (provider == null) {
      developer.log('[VALIDATOR] ❌ Invalid API key format', name: 'AuthValidator');
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'Invalid API key format. Key must start with sk-or-vv- (VSEGPT) or sk-or-v1- (OpenRouter)',
        balance: 0.0,
        provider: 'unknown',
      );
    }

    developer.log('[VALIDATOR] Detected provider: $provider', name: 'AuthValidator');

    try {
      if (provider == 'vsegpt') {
        developer.log('[VALIDATOR] Validating VSEGPT key...', name: 'AuthValidator');
        return await _validateVsegptKey(apiKey);
      } else {
        developer.log('[VALIDATOR] Validating OpenRouter key...', name: 'AuthValidator');
        return await _validateOpenRouterKey(apiKey);
      }
    } catch (e, stackTrace) {
      developer.log('[VALIDATOR] ❌ Exception during validation: $e', name: 'AuthValidator');
      developer.log('[VALIDATOR] Stack trace: $stackTrace', name: 'AuthValidator');
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
    developer.log('[VALIDATOR] OpenRouter URL: $uri', name: 'AuthValidator');
    
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      developer.log('[VALIDATOR] Sending request to OpenRouter...', name: 'AuthValidator');
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      
      developer.log('[VALIDATOR] OpenRouter response status: ${response.statusCode}', name: 'AuthValidator');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;

        if (data != null) {
          final totalCredits = (data['total_credits'] as num?)?.toDouble() ?? 0.0;
          final totalUsage = (data['total_usage'] as num?)?.toDouble() ?? 0.0;
          final balance = totalCredits - totalUsage;
          final balanceStr = balance.toStringAsFixed(2);

          // Проверяем, что баланс неотрицательный (больше или равен нулю)
          return ApiKeyValidationResult(
            isValid: balance >= 0,
            message: balanceStr,
            balance: balance,
            provider: 'openrouter',
          );
        }
      }

      // Обработка различных HTTP статусов для лучшей диагностики
      if (response.statusCode == 401) {
        developer.log('[VALIDATOR] ❌ OpenRouter: Invalid API key (401)', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Invalid OpenRouter API key',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else if (response.statusCode == 403) {
        developer.log('[VALIDATOR] ❌ OpenRouter: Insufficient permissions (403)', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Insufficient permissions to check OpenRouter balance',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else if (response.statusCode == 429) {
        developer.log('[VALIDATOR] ❌ OpenRouter: Rate limit exceeded (429)', name: 'AuthValidator');
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Rate limit exceeded. Please try again later',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        developer.log('[VALIDATOR] ❌ OpenRouter: Server error (${response.statusCode})', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        return ApiKeyValidationResult(
          isValid: false,
          message: 'OpenRouter server error (HTTP ${response.statusCode}). Please try again later',
          balance: 0.0,
          provider: 'openrouter',
        );
      } else {
        developer.log('[VALIDATOR] ❌ OpenRouter: Unexpected status code (${response.statusCode})', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        return ApiKeyValidationResult(
          isValid: false,
          message: 'Failed to validate OpenRouter key: HTTP ${response.statusCode}',
          balance: 0.0,
          provider: 'openrouter',
        );
      }
    } on http.ClientException catch (e) {
      developer.log('[VALIDATOR] ❌ OpenRouter: Network error: $e', name: 'AuthValidator');
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Network error while validating OpenRouter key: $e',
        balance: 0.0,
        provider: 'openrouter',
      );
    } on TimeoutException catch (e) {
      developer.log('[VALIDATOR] ❌ OpenRouter: Request timeout: $e', name: 'AuthValidator');
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Request timeout while validating OpenRouter key: $e',
        balance: 0.0,
        provider: 'openrouter',
      );
    } catch (e, stackTrace) {
      developer.log('[VALIDATOR] ❌ OpenRouter: Unexpected error: $e', name: 'AuthValidator');
      developer.log('[VALIDATOR] Stack trace: $stackTrace', name: 'AuthValidator');
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
    
    developer.log('[VALIDATOR] VSEGPT base URL: $vsegptBaseUrl', name: 'AuthValidator');
    developer.log('[VALIDATOR] Parsed base URI: $baseUri', name: 'AuthValidator');
    developer.log('[VALIDATOR] Base URI path: "${baseUri.path}"', name: 'AuthValidator');
    
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
      developer.log('[VALIDATOR] Using /v1/balance endpoint (replaced path): $uri', name: 'AuthValidator');
    } else {
      // Иначе добавляем /v1/balance
      uri = baseUri.resolve('/v1/balance');
      developer.log('[VALIDATOR] Using /v1/balance endpoint (added path): $uri', name: 'AuthValidator');
    }

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    developer.log('[VALIDATOR] Request headers: Authorization=Bearer ${apiKey.substring(0, apiKey.length > 15 ? 15 : apiKey.length)}...', name: 'AuthValidator');

    try {
      developer.log('[VALIDATOR] Sending GET request to: $uri', name: 'AuthValidator');
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      
      developer.log('[VALIDATOR] VSEGPT response status: ${response.statusCode}', name: 'AuthValidator');
      developer.log('[VALIDATOR] VSEGPT response headers: ${response.headers}', name: 'AuthValidator');

      // Обработка различных HTTP статусов
      if (response.statusCode == 200) {
        try {
          developer.log('[VALIDATOR] Parsing VSEGPT response...', name: 'AuthValidator');
          developer.log('[VALIDATOR] VSEGPT response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...', name: 'AuthValidator');
          
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Пытаемся извлечь баланс из различных форматов ответа
          developer.log('[VALIDATOR] Full decoded response: $decoded', name: 'AuthValidator');
          double? balance = _extractBalanceFromVsegptResponse(decoded);
          developer.log('[VALIDATOR] Extracted balance from primary endpoint: $balance', name: 'AuthValidator');
          
          if (balance == null) {
            // Если не удалось извлечь баланс, логируем предупреждение
            developer.log('[VALIDATOR] ⚠️ Could not extract balance from response, but status is 200', name: 'AuthValidator');
            developer.log('[VALIDATOR] Response keys: ${decoded.keys.toList()}', name: 'AuthValidator');
          }

          if (balance != null) {
            // Проверяем, что баланс неотрицательный (больше или равен нулю)
            final isValid = balance >= 0;
            developer.log('[VALIDATOR] VSEGPT balance: $balance, isValid: $isValid', name: 'AuthValidator');
            developer.log('[VALIDATOR] Balance type: ${balance.runtimeType}', name: 'AuthValidator');
            
            if (isValid) {
              developer.log('[VALIDATOR] ✅ VSEGPT validation successful', name: 'AuthValidator');
              return ApiKeyValidationResult(
                isValid: true,
                message: balance.toStringAsFixed(2),
                balance: balance,
                provider: 'vsegpt',
              );
            } else {
              developer.log('[VALIDATOR] ❌ VSEGPT validation failed: negative balance', name: 'AuthValidator');
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
            developer.log('[VALIDATOR] ⚠️ VSEGPT balance not found in response, considering key valid', name: 'AuthValidator');
            return const ApiKeyValidationResult(
              isValid: true,
              message: 'Valid VSEGPT API key',
              balance: 0.0,
              provider: 'vsegpt',
            );
          }
        } catch (e, stackTrace) {
          // Ошибка парсинга JSON
          developer.log('[VALIDATOR] ❌ Error parsing VSEGPT response: $e', name: 'AuthValidator');
          developer.log('[VALIDATOR] Stack trace: $stackTrace', name: 'AuthValidator');
          developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
          return ApiKeyValidationResult(
            isValid: false,
            message: 'Invalid response format from VSEGPT API: $e',
            balance: 0.0,
            provider: 'vsegpt',
          );
        }
      } else if (response.statusCode == 401) {
        developer.log('[VALIDATOR] ❌ VSEGPT: Invalid API key (401)', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Invalid VSEGPT API key',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else if (response.statusCode == 403) {
        developer.log('[VALIDATOR] ❌ VSEGPT: Insufficient permissions (403)', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Insufficient permissions to check VSEGPT balance',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else if (response.statusCode == 429) {
        developer.log('[VALIDATOR] ❌ VSEGPT: Rate limit exceeded (429)', name: 'AuthValidator');
        return const ApiKeyValidationResult(
          isValid: false,
          message: 'Rate limit exceeded. Please try again later',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        developer.log('[VALIDATOR] ❌ VSEGPT: Server error (${response.statusCode})', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        return ApiKeyValidationResult(
          isValid: false,
          message: 'VSEGPT server error (HTTP ${response.statusCode}). Please try again later',
          balance: 0.0,
          provider: 'vsegpt',
        );
      } else {
        developer.log('[VALIDATOR] ❌ VSEGPT: Unexpected status code (${response.statusCode})', name: 'AuthValidator');
        developer.log('[VALIDATOR] Requested URL: $uri', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response body: ${response.body}', name: 'AuthValidator');
        developer.log('[VALIDATOR] Response headers: ${response.headers}', name: 'AuthValidator');
        
        // Для 404 логируем детальную информацию
        if (response.statusCode == 404) {
          developer.log('[VALIDATOR] ⚠️ 404 error - endpoint not found', name: 'AuthValidator');
          developer.log('[VALIDATOR] Expected endpoint: /v1/balance', name: 'AuthValidator');
          developer.log('[VALIDATOR] Please check VSEGPT_BASE_URL in .env file', name: 'AuthValidator');
        }
        
        return ApiKeyValidationResult(
          isValid: false,
          message: 'Failed to validate VSEGPT key: HTTP ${response.statusCode}. Tried URL: $uri',
          balance: 0.0,
          provider: 'vsegpt',
        );
      }
    } on http.ClientException catch (e) {
      developer.log('[VALIDATOR] ❌ VSEGPT: Network error: $e', name: 'AuthValidator');
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Network error while validating VSEGPT key: $e',
        balance: 0.0,
        provider: 'vsegpt',
      );
    } on TimeoutException catch (e) {
      developer.log('[VALIDATOR] ❌ VSEGPT: Request timeout: $e', name: 'AuthValidator');
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Request timeout while validating VSEGPT key: $e',
        balance: 0.0,
        provider: 'vsegpt',
      );
    } catch (e, stackTrace) {
      developer.log('[VALIDATOR] ❌ VSEGPT: Unexpected error: $e', name: 'AuthValidator');
      developer.log('[VALIDATOR] Stack trace: $stackTrace', name: 'AuthValidator');
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
    developer.log('[VALIDATOR] Extracting balance from response: $decoded', name: 'AuthValidator');
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
