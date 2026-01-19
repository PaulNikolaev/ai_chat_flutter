import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/model_info.dart';

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

  final http.Client _client;

  OpenRouterClient._({
    required this.baseUrl,
    required this.apiKey,
    required http.Client httpClient,
  }) : _client = httpClient;

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
  Map<String, String> get _defaultHeaders => <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  /// Получает список доступных моделей из OpenRouter API.
  ///
  /// Возвращает список [ModelInfo]. В случае ошибки выбрасывает [OpenRouterException].
  Future<List<ModelInfo>> getModels() async {
    final uri = Uri.parse('$baseUrl/models');

    http.Response response;
    try {
      response = await _client.get(uri, headers: _defaultHeaders);
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
      final data = decoded['data'];
      if (data is! List) {
        throw const FormatException('Response does not contain a data list');
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(ModelInfo.fromJson)
          .toList();
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
  Future<ChatCompletionResult> sendMessage({
    required String message,
    required String model,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/completions');

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

    http.Response response;
    try {
      response = await _postWithRetry(uri, body: body);
    } on http.ClientException catch (e) {
      throw OpenRouterException('Network error while sending message: $e');
    } catch (e) {
      throw OpenRouterException('Unexpected error while sending message: $e');
    }

    if (response.statusCode != 200) {
      throw OpenRouterException(
        'Failed to send message: HTTP ${response.statusCode}',
      );
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object');
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const FormatException('Response does not contain choices');
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw const FormatException('First choice is not an object');
      }

      // OpenRouter совместим с форматом OpenAI: choices[].message.content
      final messageObj = first['message'] as Map<String, dynamic>?;
      final content = messageObj?['content'] as String? ?? '';

      // Извлекаем информацию о токенах, если она присутствует.
      final usage = decoded['usage'] as Map<String, dynamic>?;
      final totalTokens = usage?['total_tokens'] as int?;
      final promptTokens = usage?['prompt_tokens'] as int?;
      final completionTokens = usage?['completion_tokens'] as int?;

      return ChatCompletionResult(
        text: content,
        totalTokens: totalTokens,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );
    } on FormatException catch (e) {
      throw OpenRouterException('Invalid chat completion response format: $e');
    } catch (e) {
      throw OpenRouterException('Failed to parse chat completion response: $e');
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
        final response = await _client.post(
          uri,
          headers: _defaultHeaders,
          body: jsonEncode(body),
        );

        // Повторяем только при 5xx ошибках, остальные возвращаем сразу.
        if (response.statusCode >= 500 && response.statusCode < 600) {
          if (attempt >= maxRetries) {
            return response;
          }
        } else {
          return response;
        }
      } on http.ClientException {
        if (attempt >= maxRetries) rethrow;
      }

      // Небольшая задержка перед повторной попыткой.
      await Future<void>.delayed(
        Duration(milliseconds: 300 * attempt),
      );
    }
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

