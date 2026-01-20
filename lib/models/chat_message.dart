/// Модель данных для сообщения чата.
///
/// Представляет одно сообщение в диалоге с AI, включая сообщение пользователя,
/// ответ AI, используемую модель и метаданные.
class ChatMessage {
  /// Уникальный идентификатор сообщения.
  final int? id;

  /// Идентификатор модели AI, использованной для ответа.
  final String model;

  /// Текст сообщения пользователя.
  final String userMessage;

  /// Текст ответа AI.
  final String aiResponse;

  /// Временная метка сообщения.
  final DateTime timestamp;

  /// Количество использованных токенов.
  final int tokensUsed;

  /// Создает экземпляр [ChatMessage].
  ///
  /// [id] может быть null для новых сообщений, которые еще не сохранены в БД.
  const ChatMessage({
    this.id,
    required this.model,
    required this.userMessage,
    required this.aiResponse,
    required this.timestamp,
    required this.tokensUsed,
  });

  /// Создает [ChatMessage] из JSON.
  ///
  /// Пример JSON:
  /// ```json
  /// {
  ///   "id": 1,
  ///   "model": "openai/gpt-4",
  ///   "user_message": "Привет",
  ///   "ai_response": "Здравствуйте!",
  ///   "timestamp": "2024-01-15T10:30:00Z",
  ///   "tokens_used": 50
  /// }
  /// ```
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int?,
      model: json['model'] as String,
      userMessage:
          json['user_message'] as String? ?? json['userMessage'] as String,
      aiResponse:
          json['ai_response'] as String? ?? json['aiResponse'] as String,
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      tokensUsed: json['tokens_used'] as int? ?? json['tokensUsed'] as int,
    );
  }

  /// Преобразует [ChatMessage] в JSON.
  ///
  /// Возвращает Map с ключами в snake_case для совместимости с Python версией.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'model': model,
      'user_message': userMessage,
      'ai_response': aiResponse,
      'timestamp': timestamp.toIso8601String(),
      'tokens_used': tokensUsed,
    };
  }

  /// Создает копию [ChatMessage] с измененными полями.
  ChatMessage copyWith({
    int? id,
    String? model,
    String? userMessage,
    String? aiResponse,
    DateTime? timestamp,
    int? tokensUsed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      model: model ?? this.model,
      userMessage: userMessage ?? this.userMessage,
      aiResponse: aiResponse ?? this.aiResponse,
      timestamp: timestamp ?? this.timestamp,
      tokensUsed: tokensUsed ?? this.tokensUsed,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, model: $model, timestamp: $timestamp, tokensUsed: $tokensUsed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.id == id &&
        other.model == model &&
        other.userMessage == userMessage &&
        other.aiResponse == aiResponse &&
        other.timestamp == timestamp &&
        other.tokensUsed == tokensUsed;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      model,
      userMessage,
      aiResponse,
      timestamp,
      tokensUsed,
    );
  }
}
