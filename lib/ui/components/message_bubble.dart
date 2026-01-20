import 'package:flutter/material.dart';

import 'package:ai_chat/ui/ui.dart';
import 'package:ai_chat/utils/utils.dart';

/// Виджет пузырька сообщения для чата.
///
/// Поддерживает разные стили для пользовательских и AI сообщений,
/// адаптивную ширину на мобильных/десктопных платформах и выбор текста.
class MessageBubble extends StatelessWidget {
  /// Текст сообщения.
  final String text;

  /// Признак, что сообщение отправлено пользователем.
  final bool isUser;

  /// Время сообщения (опционально).
  final DateTime? timestamp;

  /// Идентификатор/имя модели (опционально).
  final String? model;

  /// Показывать ли время.
  final bool showTimestamp;

  /// Коэффициент максимальной ширины на десктопе (0..1).
  final double maxWidthFactor;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.model,
    this.showTimestamp = true,
    this.maxWidthFactor = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Вычисляем цвета один раз, а не в LayoutBuilder
    final bubbleColor =
        isUser ? AppStyles.buttonPrimaryColor : AppStyles.cardColor;
    final borderColor = isUser ? Colors.transparent : AppStyles.borderColor;

    return LayoutBuilder(
      key: ValueKey('${text.hashCode}_$isUser'),
      builder: (context, constraints) {
        // На мобильных даём ширину до 90%, на десктопе — maxWidthFactor
        final maxWidth = constraints.maxWidth *
            (PlatformUtils.isMobile() ? 0.9 : maxWidthFactor.clamp(0.4, 0.9));

        return Semantics(
          label: isUser
              ? 'Сообщение пользователя: $text'
              : 'Ответ AI: $text${model != null ? ' от модели $model' : ''}',
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppStyles.borderRadius),
                    topRight: const Radius.circular(AppStyles.borderRadius),
                    bottomLeft: Radius.circular(
                      isUser ? AppStyles.borderRadius : 2,
                    ),
                    bottomRight: Radius.circular(
                      isUser ? 2 : AppStyles.borderRadius,
                    ),
                  ),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppStyles.paddingSmall),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (model != null && model!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppStyles.paddingSmall / 2,
                          ),
                          child: Text(
                            model!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppStyles.textSecondary,
                            ),
                          ),
                        ),
                      SelectionArea(
                        child: SelectableText(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppStyles.textPrimary,
                          ),
                        ),
                      ),
                      if (showTimestamp && timestamp != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppStyles.paddingSmall / 2,
                          ),
                          child: Text(
                            _formatTime(timestamp!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppStyles.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
