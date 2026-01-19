/// Модель данных для информации об AI модели.
///
/// Представляет метаданные модели AI, доступной через OpenRouter API.
class ModelInfo {
  /// Идентификатор модели для использования в API запросах.
  final String id;

  /// Человекочитаемое название модели.
  final String name;

  /// Описание модели (опционально).
  final String? description;

  /// Контекстное окно модели в токенах (опционально).
  final int? contextLength;

  /// Стоимость за токен для промпта (опционально).
  final double? promptPrice;

  /// Стоимость за токен для завершения (опционально).
  final double? completionPrice;

  /// Создает экземпляр [ModelInfo].
  const ModelInfo({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    this.promptPrice,
    this.completionPrice,
  });

  /// Создает [ModelInfo] из JSON.
  ///
  /// Пример JSON:
  /// ```json
  /// {
  ///   "id": "openai/gpt-4",
  ///   "name": "GPT-4",
  ///   "description": "Most capable model",
  ///   "context_length": 8192,
  ///   "pricing": {
  ///     "prompt": "0.00003",
  ///     "completion": "0.00006"
  ///   }
  /// }
  /// ```
  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    
    return ModelInfo(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      description: json['description'] as String?,
      contextLength: json['context_length'] as int? ?? json['contextLength'] as int?,
      promptPrice: pricing != null
          ? (double.tryParse(pricing['prompt']?.toString() ?? '0') ?? 0.0)
          : json['prompt_price'] as double? ?? json['promptPrice'] as double?,
      completionPrice: pricing != null
          ? (double.tryParse(pricing['completion']?.toString() ?? '0') ?? 0.0)
          : json['completion_price'] as double? ?? json['completionPrice'] as double?,
    );
  }

  /// Преобразует [ModelInfo] в JSON.
  ///
  /// Возвращает Map с ключами в snake_case для совместимости с Python версией.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (contextLength != null) 'context_length': contextLength,
      if (promptPrice != null || completionPrice != null)
        'pricing': {
          if (promptPrice != null) 'prompt': promptPrice.toString(),
          if (completionPrice != null) 'completion': completionPrice.toString(),
        },
    };
  }

  /// Создает копию [ModelInfo] с измененными полями.
  ModelInfo copyWith({
    String? id,
    String? name,
    String? description,
    int? contextLength,
    double? promptPrice,
    double? completionPrice,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      contextLength: contextLength ?? this.contextLength,
      promptPrice: promptPrice ?? this.promptPrice,
      completionPrice: completionPrice ?? this.completionPrice,
    );
  }

  /// Возвращает полное название модели (id или name).
  String get displayName => name.isNotEmpty ? name : id;

  @override
  String toString() {
    return 'ModelInfo(id: $id, name: $name, contextLength: $contextLength)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModelInfo &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.contextLength == contextLength &&
        other.promptPrice == promptPrice &&
        other.completionPrice == completionPrice;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      contextLength,
      promptPrice,
      completionPrice,
    );
  }
}
