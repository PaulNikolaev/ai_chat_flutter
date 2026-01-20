/// Модель данных для аналитической записи.
///
/// Представляет одну запись аналитики использования AI моделей,
/// включая метрики производительности и потребления токенов.
class AnalyticsRecord {
  /// Уникальный идентификатор записи (может быть null для новых записей).
  final int? id;

  /// Временная метка записи.
  final DateTime timestamp;

  /// Идентификатор модели AI, использованной для запроса.
  final String model;

  /// Длина сообщения в символах.
  final int messageLength;

  /// Время ответа в секундах.
  final double responseTime;

  /// Количество использованных токенов.
  final int tokensUsed;

  /// Количество токенов в промпте (опционально).
  final int? promptTokens;

  /// Количество токенов в завершении (опционально).
  final int? completionTokens;

  /// Стоимость запроса в долларах (опционально).
  final double? cost;

  /// Создает экземпляр [AnalyticsRecord].
  ///
  /// [id] может быть null для новых записей, которые еще не сохранены в БД.
  const AnalyticsRecord({
    this.id,
    required this.timestamp,
    required this.model,
    required this.messageLength,
    required this.responseTime,
    required this.tokensUsed,
    this.promptTokens,
    this.completionTokens,
    this.cost,
  });

  /// Создает [AnalyticsRecord] из JSON.
  ///
  /// Пример JSON:
  /// ```json
  /// {
  ///   "id": 1,
  ///   "timestamp": "2024-01-15T10:30:00Z",
  ///   "model": "openai/gpt-4",
  ///   "message_length": 100,
  ///   "response_time": 2.5,
  ///   "tokens_used": 150
  /// }
  /// ```
  factory AnalyticsRecord.fromJson(Map<String, dynamic> json) {
    return AnalyticsRecord(
      id: json['id'] as int?,
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      model: json['model'] as String,
      messageLength:
          json['message_length'] as int? ?? json['messageLength'] as int,
      responseTime: (json['response_time'] as num?)?.toDouble() ??
          (json['responseTime'] as num?)?.toDouble() ??
          0.0,
      tokensUsed: json['tokens_used'] as int? ?? json['tokensUsed'] as int,
      promptTokens:
          json['prompt_tokens'] as int? ?? json['promptTokens'] as int?,
      completionTokens:
          json['completion_tokens'] as int? ?? json['completionTokens'] as int?,
      cost: (json['cost'] as num?)?.toDouble(),
    );
  }

  /// Преобразует [AnalyticsRecord] в JSON.
  ///
  /// Возвращает Map с ключами в snake_case для совместимости с Python версией.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.toIso8601String(),
      'model': model,
      'message_length': messageLength,
      'response_time': responseTime,
      'tokens_used': tokensUsed,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (cost != null) 'cost': cost,
    };
  }

  /// Создает копию [AnalyticsRecord] с измененными полями.
  AnalyticsRecord copyWith({
    int? id,
    DateTime? timestamp,
    String? model,
    int? messageLength,
    double? responseTime,
    int? tokensUsed,
    int? promptTokens,
    int? completionTokens,
    double? cost,
  }) {
    return AnalyticsRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      model: model ?? this.model,
      messageLength: messageLength ?? this.messageLength,
      responseTime: responseTime ?? this.responseTime,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cost: cost ?? this.cost,
    );
  }

  @override
  String toString() {
    return 'AnalyticsRecord(id: $id, model: $model, timestamp: $timestamp, '
        'tokensUsed: $tokensUsed, promptTokens: $promptTokens, '
        'completionTokens: $completionTokens, cost: $cost, responseTime: ${responseTime}s)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnalyticsRecord &&
        other.id == id &&
        other.timestamp == timestamp &&
        other.model == model &&
        other.messageLength == messageLength &&
        other.responseTime == responseTime &&
        other.tokensUsed == tokensUsed &&
        other.promptTokens == promptTokens &&
        other.completionTokens == completionTokens &&
        other.cost == cost;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      timestamp,
      model,
      messageLength,
      responseTime,
      tokensUsed,
      promptTokens,
      completionTokens,
      cost,
    );
  }
}
