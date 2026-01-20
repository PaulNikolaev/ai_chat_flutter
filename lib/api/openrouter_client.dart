import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'package:ai_chat/config/config.dart';
import 'package:ai_chat/models/models.dart';

/// Базовый клиент для работы с OpenRouter API.
///
/// Отвечает за:
/// - инициализацию с API ключом и базовым URL;
/// - получение списка моделей;
/// - базовую обработку ошибок HTTP запросов.
class OpenRouterClient {
  /// Базовый URL OpenRouter API.
  final String baseUrl;

  /// API ключ для аутентификации.
  final String apiKey;

  /// Провайдер API ('openrouter' или 'vsegpt').
  final String? provider;

  final http.Client _client;

  /// Кэш списка моделей.
  List<ModelInfo>? _modelCache;

  /// Кэш баланса.
  String? _cachedBalance;
  DateTime? _balanceUpdatedAt;

  /// Очищает кэш моделей.
  ///
  /// Вызывается при переключении провайдера для принудительной перезагрузки моделей.
  void clearModelCache() {
    _modelCache = null;
  }

  OpenRouterClient._({
    required this.baseUrl,
    required this.apiKey,
    this.provider,
    required http.Client httpClient,
  }) : _client = httpClient;

  /// Создает экземпляр [OpenRouterClient] с указанными параметрами.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для аутентификации.
  /// - [baseUrl]: Базовый URL API (по умолчанию используется из EnvConfig).
  /// - [provider]: Провайдер API ('openrouter' или 'vsegpt'). Определяется автоматически по префиксу ключа, если не указан.
  /// - [httpClient]: HTTP клиент (опционально, создается новый если не указан).
  factory OpenRouterClient({
    required String apiKey,
    String? baseUrl,
    String? provider,
    http.Client? httpClient,
  }) {
    final effectiveBaseUrl = baseUrl ??
        (EnvConfig.openRouterBaseUrl.trim().isNotEmpty
            ? EnvConfig.openRouterBaseUrl.trim()
            : 'https://openrouter.ai/api/v1');

    // Определяем провайдера по префиксу ключа, если не указан
    final detectedProvider = provider ?? _detectProviderFromKey(apiKey);

    return OpenRouterClient._(
      baseUrl: effectiveBaseUrl,
      apiKey: apiKey.trim(),
      provider: detectedProvider,
      httpClient: httpClient ?? http.Client(),
    );
  }

  /// Определяет провайдера по префиксу API ключа.
  static String? _detectProviderFromKey(String apiKey) {
    final trimmed = apiKey.trim();
    if (trimmed.startsWith('sk-or-vv-')) {
      return 'vsegpt';
    } else if (trimmed.startsWith('sk-or-v1-')) {
      return 'openrouter';
    }
    return null;
  }

  /// Фабричный конструктор, инициализирующий клиент из `.env`.
  ///
  /// Использует `EnvConfig` для загрузки и валидации конфигурации.
  /// Требует, чтобы в `.env` был задан `OPENROUTER_API_KEY`.
  static Future<OpenRouterClient> create({http.Client? httpClient}) async {
    await EnvConfig.load();
    // Проверяем, что хотя бы один ключ есть; затем убеждаемся, что есть OpenRouter.
    EnvConfig.validate();

    final apiKey = EnvConfig.openRouterApiKey.trim();
    if (apiKey.isEmpty) {
      throw const OpenRouterException(
        'OPENROUTER_API_KEY is not set in .env. For OpenRouterClient you must provide OPENROUTER_API_KEY.',
      );
    }

    final baseUrl = EnvConfig.openRouterBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const OpenRouterException(
        'OPENROUTER_BASE_URL is empty. Check your .env file.',
      );
    }

    return OpenRouterClient._(
      baseUrl: baseUrl,
      apiKey: apiKey,
      httpClient: httpClient ?? http.Client(),
    );
  }

  /// Заголовки по умолчанию для запросов к OpenRouter.
  Map<String, String> get _defaultHeaders {
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // Для VSEGPT используем минимальный набор заголовков
    // User-Agent может вызывать проблемы с некоторыми серверами

    return headers;
  }

  /// Получает список доступных моделей из API.
  ///
  /// Возвращает список [ModelInfo]. В случае ошибки выбрасывает [OpenRouterException].
  ///
  /// Использует простой кэш: при повторных вызовах возвращает ранее загруженный
  /// список моделей, если не запрошено [forceRefresh].
  ///
  /// Для VSEGPT использует endpoint /v1/models, для OpenRouter - /models
  Future<List<ModelInfo>> getModels({bool forceRefresh = false}) async {
    if (!forceRefresh && _modelCache != null) {
      return _modelCache!;
    }

    // Формируем правильный endpoint в зависимости от провайдера
    Uri uri;
    if (provider == 'vsegpt') {
      // Для VSEGPT используем /v1/models
      final baseUri = Uri.parse(baseUrl);
      // Если baseUrl уже содержит /v1/, заменяем весь путь на /v1/models
      // Например: https://api.vsegpt.ru/v1/chat -> https://api.vsegpt.ru/v1/models
      if (baseUri.path.contains('/v1/')) {
        uri = Uri(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
          path: '/v1/models',
        );
      } else {
        // Иначе добавляем /v1/models
        uri = baseUri.resolve('/v1/models');
      }
    } else {
      // Для OpenRouter используем стандартный /models
      uri = Uri.parse('$baseUrl/models');
    }

    http.Response response;
    try {
      response = await _getWithRetry(uri);
    } on http.ClientException catch (e) {
      throw OpenRouterException('Network error while fetching models: $e');
    } catch (e) {
      throw OpenRouterException('Unexpected error while fetching models: $e');
    }

    if (response.statusCode != 200) {
      throw OpenRouterException(
        'Failed to fetch models: HTTP ${response.statusCode}',
      );
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object');
      }

      // Логируем структуру ответа для диагностики
      // VSEGPT может возвращать модели в другом формате
      dynamic data;
      if (provider == 'vsegpt') {
        // Пробуем разные варианты структуры ответа VSEGPT
        data =
            decoded['data'] ?? decoded['models'] ?? decoded['list'] ?? decoded;
        // Если data это не список, но это Map, пробуем извлечь список из него
        if (data is Map<String, dynamic>) {
          data = data['items'] ?? data['models'] ?? data['data'];
        }
      } else {
        data = decoded['data'];
      }

      if (data is! List) {
        throw FormatException(
            'Response does not contain a data list. Got: ${data.runtimeType}');
      }

      final models = data
          .whereType<Map<String, dynamic>>()
          .map((json) => _parseModelInfo(json, provider))
          .toList();

      // Удаляем дубликаты по id (могут быть одинаковые модели с разными форматами)
      final uniqueModels = <String, ModelInfo>{};
      final duplicateIds = <String>[];

      for (final model in models) {
        if (model.id.isEmpty) {
          continue;
        }

        if (!uniqueModels.containsKey(model.id)) {
          uniqueModels[model.id] = model;
        } else {
          duplicateIds.add(model.id);
        }
      }

      final deduplicatedModels = uniqueModels.values.toList();

      _modelCache = deduplicatedModels;

      return deduplicatedModels;
    } on FormatException catch (e) {
      throw OpenRouterException('Invalid models response format: $e');
    } catch (e) {
      throw OpenRouterException('Failed to parse models response: $e');
    }
  }

  /// Отправляет сообщение к выбранной модели и возвращает ответ AI.
  ///
  /// Возвращает [ChatCompletionResult] c текстом ответа и информацией о токенах.
  /// В случае ошибки выбрасывает [OpenRouterException].
  ///
  /// Для VSEGPT и OpenRouter используется одинаковый endpoint /chat/completions
  Future<ChatCompletionResult> sendMessage({
    required String message,
    required String model,
  }) async {
    // Формируем правильный endpoint в зависимости от провайдера
    Uri uri;
    if (provider == 'vsegpt') {
      // Для VSEGPT используем /v1/chat/completions
      final baseUri = Uri.parse(baseUrl);
      debugPrint('[OpenRouterClient] VSEGPT baseUrl: $baseUrl');
      debugPrint('[OpenRouterClient] Parsed baseUri path: ${baseUri.path}');

      // Если baseUrl уже содержит полный путь /v1/chat/completions, используем его как есть
      if (baseUri.path == '/v1/chat/completions' ||
          baseUri.path.endsWith('/v1/chat/completions')) {
        uri = baseUri;
      } else if (baseUri.path == '/v1/chat' ||
          baseUri.path.endsWith('/v1/chat')) {
        // Если baseUrl заканчивается на /v1/chat, добавляем /completions
        // Например: https://api.vsegpt.ru/v1/chat -> https://api.vsegpt.ru/v1/chat/completions
        uri = Uri(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
          path: '/v1/chat/completions',
        );
      } else if (baseUri.path == '/v1' || baseUri.path.endsWith('/v1')) {
        // Если baseUrl заканчивается на /v1, добавляем /chat/completions
        // Например: https://api.vsegpt.ru/v1 -> https://api.vsegpt.ru/v1/chat/completions
        uri = Uri(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
          path: '/v1/chat/completions',
        );
      } else if (baseUri.path.contains('/v1/')) {
        // Если содержит /v1/, заменяем весь путь на /v1/chat/completions
        uri = Uri(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
          path: '/v1/chat/completions',
        );
      } else {
        // Иначе добавляем /v1/chat/completions
        uri = baseUri.resolve('/v1/chat/completions');
      }
      debugPrint('[OpenRouterClient] Final VSEGPT URI: $uri');
    } else {
      // Для OpenRouter используем стандартный /chat/completions
      uri = Uri.parse('$baseUrl/chat/completions');
      debugPrint('[OpenRouterClient] OpenRouter URI: $uri');
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': message,
        }
      ],
      'max_tokens': EnvConfig.maxTokens,
      'temperature': EnvConfig.temperature,
    };

    // Логируем URL и параметры запроса для диагностики
    // ВАЖНО: Не логируем Authorization header, чтобы не раскрывать API ключ
    debugPrint('[OpenRouterClient] Sending message to: $uri');
    debugPrint('[OpenRouterClient] Provider: $provider');
    debugPrint('[OpenRouterClient] Model: $model');
    // Логируем body без чувствительных данных (API ключ в заголовках, не в body)
    debugPrint('[OpenRouterClient] Request body: ${jsonEncode(body)}');

    http.Response response;
    try {
      response = await _postWithRetry(uri, body: body);
      debugPrint('[OpenRouterClient] Response status: ${response.statusCode}');
      debugPrint('[OpenRouterClient] Response body: ${response.body}');
    } on http.ClientException catch (e) {
      debugPrint('[OpenRouterClient] Network error: $e');
      throw OpenRouterException('Network error while sending message: $e');
    } catch (e) {
      debugPrint('[OpenRouterClient] Unexpected error: $e');
      throw OpenRouterException('Unexpected error while sending message: $e');
    }

    if (response.statusCode != 200) {
      // Пытаемся извлечь сообщение об ошибке из ответа
      String errorMessage =
          'Failed to send message: HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        if (decoded != null) {
          // Проверяем различные форматы ошибок
          if (decoded.containsKey('error')) {
            final error = decoded['error'];
            if (error is Map<String, dynamic>) {
              errorMessage = error['message'] as String? ?? errorMessage;
            } else if (error is String) {
              errorMessage = error;
            }
          } else if (decoded.containsKey('message')) {
            errorMessage = decoded['message'] as String? ?? errorMessage;
          }
        }
      } catch (e) {
        // Если не удалось распарсить, используем стандартное сообщение
      }

      // Для VSEGPT добавляем дополнительную информацию об ошибке 404
      if (provider == 'vsegpt' && response.statusCode == 404) {
        final modelId = body['model'] as String? ?? 'unknown';
        errorMessage = 'Модель "$modelId" недоступна в VSEGPT. '
            'Пожалуйста, выберите другую модель из списка доступных. '
            'Ошибка: $errorMessage';
      }

      throw OpenRouterException(errorMessage);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint(
            '[OpenRouterClient] Response is not a JSON object: ${decoded.runtimeType}');
        throw const FormatException('Response is not a JSON object');
      }

      // Для VSEGPT может быть другой формат ответа
      dynamic choices;
      if (provider == 'vsegpt') {
        // Пробуем разные варианты структуры ответа VSEGPT
        choices = decoded['choices'] ?? decoded['data'] ?? decoded['result'];
        // Если choices это не список, но это Map, пробуем извлечь список из него
        if (choices is Map<String, dynamic>) {
          choices = choices['choices'] ?? choices['items'] ?? choices['data'];
        }
      } else {
        choices = decoded['choices'];
      }

      if (choices is! List || choices.isEmpty) {
        debugPrint('[OpenRouterClient] Response structure: ${decoded.keys}');
        debugPrint(
            '[OpenRouterClient] Choices type: ${choices.runtimeType}, value: $choices');
        throw FormatException(
            'Response does not contain choices. Response keys: ${decoded.keys}');
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        debugPrint(
            '[OpenRouterClient] First choice type: ${first.runtimeType}');
        throw const FormatException('First choice is not an object');
      }

      // Извлекаем контент ответа - пробуем разные форматы
      String? content;
      if (first.containsKey('message')) {
        // Стандартный формат OpenAI: choices[].message.content
        final messageObj = first['message'] as Map<String, dynamic>?;
        content = messageObj?['content'] as String?;
      } else if (first.containsKey('content')) {
        // Прямой формат: choices[].content
        content = first['content'] as String?;
      } else if (first.containsKey('text')) {
        // Альтернативный формат: choices[].text
        content = first['text'] as String?;
      } else if (first.containsKey('delta')) {
        // Streaming формат: choices[].delta.content
        final delta = first['delta'] as Map<String, dynamic>?;
        content = delta?['content'] as String?;
      }

      if (content == null || content.isEmpty) {
        debugPrint('[OpenRouterClient] First choice keys: ${first.keys}');
        debugPrint('[OpenRouterClient] First choice: $first');
        throw FormatException(
            'Could not extract content from response. Choice keys: ${first.keys}');
      }

      // Извлекаем информацию о токенах, если она присутствует.
      final usage = decoded['usage'] as Map<String, dynamic>?;
      final totalTokens =
          usage?['total_tokens'] as int? ?? usage?['totalTokens'] as int?;
      final promptTokens =
          usage?['prompt_tokens'] as int? ?? usage?['promptTokens'] as int?;
      final completionTokens = usage?['completion_tokens'] as int? ??
          usage?['completionTokens'] as int?;

      debugPrint(
          '[OpenRouterClient] Successfully parsed response. Content length: ${content.length}');

      return ChatCompletionResult(
        text: content,
        totalTokens: totalTokens,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );
    } on FormatException catch (e) {
      debugPrint('[OpenRouterClient] FormatException: $e');
      debugPrint('[OpenRouterClient] Response body: ${response.body}');
      throw OpenRouterException('Invalid chat completion response format: $e');
    } catch (e) {
      debugPrint('[OpenRouterClient] Parse error: $e');
      debugPrint('[OpenRouterClient] Response body: ${response.body}');
      throw OpenRouterException('Failed to parse chat completion response: $e');
    }
  }

  /// Получает текущий баланс аккаунта.
  ///
  /// Для OpenRouter использует endpoint /credits, для VSEGPT - /v1/balance.
  /// Возвращает строку вида `'$X.XX'` или `'Error'` в случае ошибки.
  /// Значение кэшируется; для принудительного обновления используйте [forceRefresh].
  Future<String> getBalance({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedBalance != null &&
        _balanceUpdatedAt != null &&
        DateTime.now().difference(_balanceUpdatedAt!) <
            const Duration(minutes: 1)) {
      return _cachedBalance!;
    }

    // Формируем правильный endpoint в зависимости от провайдера
    Uri uri;
    if (provider == 'vsegpt') {
      // Для VSEGPT используем /v1/balance
      final baseUri = Uri.parse(baseUrl);
      if (baseUri.path.contains('/v1/')) {
        uri = Uri(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
          path: '/v1/balance',
        );
      } else {
        uri = baseUri.resolve('/v1/balance');
      }
    } else {
      // Для OpenRouter используем стандартный /credits
      uri = Uri.parse('$baseUrl/credits');
    }

    http.Response response;
    try {
      response = await _getWithRetry(uri);
    } on http.ClientException {
      return 'Error';
    } catch (_) {
      return 'Error';
    }

    if (response.statusCode != 200) {
      return 'Error';
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return 'Error';
      }

      double balance;

      if (provider == 'vsegpt') {
        // Для VSEGPT извлекаем баланс из различных форматов
        balance = (decoded['balance'] as num?)?.toDouble() ??
            (decoded['credits'] as num?)?.toDouble() ??
            0.0;

        // Проверяем вложенные форматы
        if (balance == 0.0 && decoded.containsKey('data')) {
          final data = decoded['data'] as Map<String, dynamic>?;
          if (data != null) {
            balance = (data['balance'] as num?)?.toDouble() ??
                (data['credits'] as num?)?.toDouble() ??
                0.0;
          }
        }

        if (balance == 0.0 && decoded.containsKey('account')) {
          final account = decoded['account'] as Map<String, dynamic>?;
          if (account != null) {
            balance = (account['balance'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final formatted = balance.toStringAsFixed(2);
        _cachedBalance = formatted;
        _balanceUpdatedAt = DateTime.now();
        return formatted;
      } else {
        // Для OpenRouter используем стандартный формат
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data == null) {
          return 'Error';
        }

        final totalCredits = (data['total_credits'] as num?)?.toDouble() ?? 0.0;
        final totalUsage = (data['total_usage'] as num?)?.toDouble() ?? 0.0;
        balance = totalCredits - totalUsage;

        final formatted = '\$${balance.toStringAsFixed(2)}';
        _cachedBalance = formatted;
        _balanceUpdatedAt = DateTime.now();
        return formatted;
      }
    } catch (e) {
      return 'Error';
    }
  }

  /// Выполняет GET запрос с простой retry логикой и обработкой rate limits.
  Future<http.Response> _getWithRetry(
    Uri uri, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final response = await _client.get(uri, headers: _defaultHeaders);

        // Обработка rate limits (429) и 5xx ошибок.
        if (response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode < 600)) {
          if (attempt >= maxRetries) {
            return response;
          }

          // Если сервер вернул Retry-After, уважаем его.
          final retryAfterHeader = response.headers['retry-after'];
          Duration delay;
          if (retryAfterHeader != null) {
            final seconds = int.tryParse(retryAfterHeader);
            delay = Duration(seconds: seconds ?? 1);
          } else {
            delay = Duration(milliseconds: 300 * attempt);
          }

          await Future<void>.delayed(delay);
          continue;
        }

        return response;
      } on http.ClientException {
        if (attempt >= maxRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  /// Выполняет POST запрос с простой retry логикой для сетевых и 5xx ошибок.
  Future<http.Response> _postWithRetry(
    Uri uri, {
    required Map<String, dynamic> body,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        debugPrint(
            '[OpenRouterClient] POST attempt $attempt/$maxRetries to $uri');
        // ВАЖНО: Не логируем Authorization header для безопасности
        final safeHeaders = Map<String, String>.from(_defaultHeaders)
          ..remove('Authorization');
        debugPrint('[OpenRouterClient] Headers (safe): $safeHeaders');

        // Проверяем, что клиент не закрыт перед использованием
        // Для VSEGPT не используем encoding параметр, так как он может вызывать проблемы
        final response = await _client
            .post(
          uri,
          headers: _defaultHeaders,
          body: jsonEncode(body),
        )
            .timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            debugPrint('[OpenRouterClient] Request timeout after 60 seconds');
            throw http.ClientException('Request timeout');
          },
        );

        debugPrint(
            '[OpenRouterClient] Response received: ${response.statusCode}');

        // Повторяем только при 5xx ошибках, остальные возвращаем сразу.
        if (response.statusCode >= 500 && response.statusCode < 600) {
          if (attempt >= maxRetries) {
            debugPrint('[OpenRouterClient] Max retries reached for 5xx error');
            return response;
          }

          debugPrint('[OpenRouterClient] Retrying after delay...');
          await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
          continue;
        }

        return response;
      } on http.ClientException catch (e) {
        debugPrint(
            '[OpenRouterClient] ClientException on attempt $attempt: $e');
        if (attempt >= maxRetries) {
          debugPrint(
              '[OpenRouterClient] Max retries reached, rethrowing exception');
          rethrow;
        }
        // Если клиент закрыт, не пытаемся повторять
        if (e.toString().contains('already closed') ||
            e.toString().contains('Connection closed')) {
          debugPrint('[OpenRouterClient] Connection closed, not retrying');
          rethrow;
        }
        debugPrint('[OpenRouterClient] Retrying after delay...');
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      } catch (e) {
        debugPrint(
            '[OpenRouterClient] Unexpected error on attempt $attempt: $e');
        if (attempt >= maxRetries) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  /// Парсит ModelInfo из JSON с учетом формата провайдера.
  ///
  /// Обрабатывает различия в форматах ответа между OpenRouter и VSEGPT.
  ModelInfo _parseModelInfo(Map<String, dynamic> json, String? provider) {
    try {
      // Для VSEGPT может быть другой формат полей
      if (provider == 'vsegpt') {
        // Пробуем извлечь context_length с учетом того, что он может быть строкой
        int? contextLength;
        final contextLengthValue = json['context_length'] ??
            json['contextLength'] ??
            json['max_tokens'];
        if (contextLengthValue != null) {
          if (contextLengthValue is int) {
            contextLength = contextLengthValue;
          } else if (contextLengthValue is String) {
            contextLength = int.tryParse(contextLengthValue);
          } else if (contextLengthValue is num) {
            contextLength = contextLengthValue.toInt();
          }
        }

        // Парсим цены с учетом возможных форматов
        final pricing = json['pricing'] as Map<String, dynamic>?;
        double? promptPrice;
        double? completionPrice;

        if (pricing != null) {
          promptPrice = _parsePrice(pricing['prompt'] ?? pricing['input']);
          completionPrice =
              _parsePrice(pricing['completion'] ?? pricing['output']);
        } else {
          promptPrice =
              _parsePrice(json['prompt_price'] ?? json['promptPrice']);
          completionPrice =
              _parsePrice(json['completion_price'] ?? json['completionPrice']);
        }

        return ModelInfo(
          id: json['id'] as String? ?? json['model'] as String? ?? '',
          name: json['name'] as String? ??
              json['id'] as String? ??
              json['model'] as String? ??
              '',
          description: json['description'] as String?,
          contextLength: contextLength,
          promptPrice: promptPrice,
          completionPrice: completionPrice,
        );
      } else {
        // Для OpenRouter используем стандартный парсинг
        return ModelInfo.fromJson(json);
      }
    } catch (e) {
      // Возвращаем базовую модель с минимальными данными
      return ModelInfo(
        id: json['id']?.toString() ?? json['model']?.toString() ?? 'unknown',
        name: json['name']?.toString() ??
            json['id']?.toString() ??
            json['model']?.toString() ??
            'Unknown Model',
        description: json['description']?.toString(),
      );
    }
  }

  /// Парсит цену из различных форматов (String, int, double).
  double? _parsePrice(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  /// Освобождает ресурсы HTTP клиента.
  void dispose() {
    _client.close();
  }
}

/// Результат чата с AI моделью.
class ChatCompletionResult {
  /// Сгенерированный текст ответа.
  final String text;

  /// Общее количество токенов (если возвращено API).
  final int? totalTokens;

  /// Количество токенов в промпте (если возвращено API).
  final int? promptTokens;

  /// Количество токенов в завершении (если возвращено API).
  final int? completionTokens;

  const ChatCompletionResult({
    required this.text,
    this.totalTokens,
    this.promptTokens,
    this.completionTokens,
  });
}

/// Ошибка, связанная с работой OpenRouterClient.
class OpenRouterException implements Exception {
  final String message;

  const OpenRouterException(this.message);

  @override
  String toString() => 'OpenRouterException: $message';
}
