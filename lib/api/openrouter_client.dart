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

  /// Освобождает ресурсы HTTP клиента.
  void dispose() {
    _client.close();
  }
}

/// Ошибка, связанная с работой OpenRouterClient.
class OpenRouterException implements Exception {
  final String message;

  const OpenRouterException(this.message);

  @override
  String toString() => 'OpenRouterException: $message';
}

