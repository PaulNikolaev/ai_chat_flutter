import 'package:flutter/material.dart';

import '../ui/styles.dart';
import '../utils/platform.dart';

/// Главный экран чата с историей сообщений и полем ввода.
///
/// Предоставляет базовую структуру UI с AppBar, областью истории чата
/// и полем ввода сообщения. Поддерживает адаптивный layout для мобильных/десктопных устройств.
class ChatScreen extends StatefulWidget {
  /// Callback при нажатии кнопки сохранения.
  final VoidCallback? onSave;

  /// Callback при нажатии кнопки аналитики.
  final VoidCallback? onAnalytics;

  /// Callback при нажатии кнопки очистки истории.
  final VoidCallback? onClear;

  /// Callback при нажатии кнопки выхода.
  final VoidCallback? onLogout;

  const ChatScreen({
    super.key,
    this.onSave,
    this.onAnalytics,
    this.onClear,
    this.onLogout,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformUtils.isMobile();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      appBar: AppBar(
        title: const Text('AI Chat'),
        actions: [
          // Кнопка сохранения
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Сохранить диалог',
            onPressed: widget.onSave,
          ),
          // Кнопка аналитики
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Аналитика',
            onPressed: widget.onAnalytics,
          ),
          // Кнопка очистки истории
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Очистить историю',
            onPressed: widget.onClear,
          ),
          // Кнопка выхода
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Область истории чата
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Начните диалог, отправив сообщение',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppStyles.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(
                      isMobile ? AppStyles.paddingSmall : AppStyles.padding,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppStyles.paddingSmall,
                        ),
                        child: Text(
                          message['text'] ?? '',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    },
                  ),
          ),
          // Область ввода сообщения
          Container(
            padding: EdgeInsets.all(
              isMobile ? AppStyles.paddingSmall : AppStyles.padding,
            ),
            decoration: const BoxDecoration(
              color: AppStyles.cardColor,
              border: Border(
                top: BorderSide(
                  color: AppStyles.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: isMobile
                ? // Мобильный layout: поле ввода и кнопка вертикально
                  Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Введите сообщение здесь...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppStyles.borderRadius,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(
                              AppStyles.paddingSmall,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          style: AppStyles.primaryTextStyle,
                        ),
                        const SizedBox(height: AppStyles.paddingSmall),
                        SizedBox(
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.send),
                            label: const Text('Отправка'),
                            style: AppStyles.sendButtonStyle,
                          ),
                        ),
                      ],
                    )
                : // Десктопный layout: поле ввода и кнопка горизонтально
                  Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Введите сообщение здесь...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppStyles.borderRadius,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(
                                AppStyles.paddingSmall,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                            style: AppStyles.primaryTextStyle,
                          ),
                        ),
                        const SizedBox(width: AppStyles.paddingSmall),
                        SizedBox(
                          width: AppStyles.buttonWidth,
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.send),
                            label: const Text('Отправка'),
                            style: AppStyles.sendButtonStyle,
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
