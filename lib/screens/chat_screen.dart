import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/openrouter_client.dart';
import '../models/model_info.dart';
import '../ui/components/message_bubble.dart';
import '../ui/components/model_selector.dart';
import '../ui/styles.dart';
import '../utils/analytics.dart';
import '../utils/cache.dart';
import '../utils/monitor.dart';
import '../utils/platform.dart';
import 'analytics_dialog.dart';

/// Главный экран чата с историей сообщений и полем ввода.
///
/// Предоставляет базовую структуру UI с AppBar, областью истории чата
/// и полем ввода сообщения. Поддерживает адаптивный layout для мобильных/десктопных устройств.
class ChatScreen extends StatefulWidget {
  /// API клиент для отправки сообщений.
  final OpenRouterClient? apiClient;

  /// Выбранная модель для использования.
  final String? selectedModel;

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
    this.apiClient,
    this.selectedModel,
    this.onSave,
    this.onAnalytics,
    this.onClear,
    this.onLogout,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _MessageItem {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? model;

  _MessageItem({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.model,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_MessageItem> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  
  // Экземпляры для аналитики и мониторинга
  final Analytics _analytics = Analytics();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  // Состояние для моделей
  List<ModelInfo> _models = [];
  String? _selectedModelId;
  bool _isLoadingModels = false;

  // Ключ для сохранения выбранной модели
  static const String _selectedModelKey = 'selected_model_id';

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _loadSelectedModel();
    _loadModels();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Загружает историю чата из кэша и отображает сохраненные сообщения.
  ///
  /// Получает последние сообщения из базы данных, преобразует их в
  /// формат для отображения и добавляет в список сообщений.
  Future<void> _loadChatHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await ChatCache.instance.getChatHistory(limit: 100);
      
      // Переворачиваем список, так как getChatHistory возвращает DESC (новейшие первыми),
      // а для отображения нужны старые сверху, новые снизу
      final reversedHistory = history.reversed.toList();

      final List<_MessageItem> loadedMessages = [];
      
      for (final message in reversedHistory) {
        // Добавляем сообщение пользователя
        loadedMessages.add(_MessageItem(
          text: message.userMessage,
          isUser: true,
          timestamp: message.timestamp,
        ));
        
        // Добавляем ответ AI
        loadedMessages.add(_MessageItem(
          text: message.aiResponse,
          isUser: false,
          timestamp: message.timestamp,
          model: message.model,
        ));
      }

      setState(() {
        _messages.clear();
        _messages.addAll(loadedMessages);
        _isLoadingHistory = false;
      });

      // Автоскролл к последнему сообщению после загрузки истории
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки истории: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Показывает диалог подтверждения очистки истории.
  ///
  /// После подтверждения очищает историю чата из базы данных и обновляет UI.
  Future<void> _showClearHistoryDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Очистить историю'),
          content: const Text(
            'Вы уверены, что хотите удалить всю историю чата? '
            'Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppStyles.errorColor,
              ),
              child: const Text('Очистить'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _clearHistory();
    }
  }

  /// Очищает историю чата из базы данных.
  ///
  /// Удаляет все сообщения из кэша и обновляет UI.
  /// Показывает сообщение об успехе или ошибке.
  Future<void> _clearHistory() async {
    try {
      final success = await ChatCache.instance.clearHistory();

      if (success) {
        setState(() {
          _messages.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('История чата успешно очищена'),
              backgroundColor: AppStyles.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to clear history');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при очистке истории: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Сохраняет историю чата в JSON файл.
  ///
  /// Экспортирует всю историю чата в JSON формат и сохраняет файл
  /// в директорию экспорта. Показывает сообщение об успехе или ошибке.
  Future<void> _saveHistory() async {
    try {
      // Получаем JSON строку с историей
      final jsonString = await ChatCache.instance.exportHistoryToJson();

      if (jsonString == null || jsonString.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('История чата пуста, нечего сохранять'),
              backgroundColor: AppStyles.warningColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Получаем директорию для экспорта
      final exportDir = await _getExportsDirectory();
      if (exportDir == null) {
        throw Exception('Could not determine export directory');
      }

      // Убеждаемся, что директория существует
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Создаем имя файла с текущей датой и временем
      final now = DateTime.now();
      final dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
      final fileName = 'chat_history_${dateFormat.format(now)}.json';
      final filePath = '${exportDir.path}/$fileName';

      // Сохраняем файл
      final file = File(filePath);
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('История сохранена: $fileName'),
            backgroundColor: AppStyles.successColor,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: AppStyles.textPrimary,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при сохранении истории: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Получает директорию для экспорта файлов в зависимости от платформы.
  ///
  /// На мобильных платформах использует директорию документов приложения.
  /// На десктопных платформах использует директорию 'exports' относительно приложения.
  ///
  /// Возвращает [Directory] для экспорта или null, если не удалось определить путь.
  Future<Directory?> _getExportsDirectory() async {
    try {
      if (PlatformUtils.isMobile()) {
        // На мобильных платформах используем директорию документов приложения
        final appDir = await getApplicationDocumentsDirectory();
        return Directory('${appDir.path}/exports');
      } else {
        // На десктопе используем директорию 'exports' относительно приложения
        final appDir = await getApplicationSupportDirectory();
        return Directory('${appDir.path}/exports');
      }
    } catch (e) {
      // Fallback: используем текущую директорию
      try {
        return Directory('exports');
      } catch (_) {
        return null;
      }
    }
  }

  /// Показывает диалог аналитики с статистикой использования моделей и метриками производительности.
  ///
  /// Отображает баланс аккаунта, статистику использования моделей и метрики производительности.
  /// Баланс автоматически обновляется каждые 30 секунд.
  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AnalyticsDialog(
          apiClient: widget.apiClient,
          analytics: _analytics,
          performanceMonitor: _performanceMonitor,
        );
      },
    );
  }

  /// Загружает список моделей из API.
  ///
  /// Получает список доступных моделей от OpenRouter API и обновляет состояние.
  /// Показывает ошибку, если загрузка не удалась.
  Future<void> _loadModels() async {
    final apiClient = widget.apiClient;
    if (apiClient == null) {
      return;
    }

    setState(() {
      _isLoadingModels = true;
    });

    try {
      final models = await apiClient.getModels();
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;
          
          // Если модель не выбрана, выбираем первую доступную или сохраненную
          if (_selectedModelId == null && models.isNotEmpty) {
            _selectedModelId = models.first.id;
            _saveSelectedModel(_selectedModelId!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки моделей: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Загружает сохраненную выбранную модель из настроек.
  ///
  /// Восстанавливает последнюю выбранную модель из SharedPreferences.
  Future<void> _loadSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModelId = prefs.getString(_selectedModelKey);
      
      if (mounted && savedModelId != null && savedModelId.isNotEmpty) {
        setState(() {
          _selectedModelId = savedModelId;
        });
      } else if (widget.selectedModel != null) {
        // Используем модель из параметров виджета, если она передана
        setState(() {
          _selectedModelId = widget.selectedModel;
        });
        if (_selectedModelId != null) {
          await _saveSelectedModel(_selectedModelId!);
        }
      }
    } catch (e) {
      // Игнорируем ошибки загрузки настроек
    }
  }

  /// Сохраняет выбранную модель в настройках.
  ///
  /// Сохраняет ID выбранной модели в SharedPreferences для восстановления при следующем запуске.
  Future<void> _saveSelectedModel(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedModelKey, modelId);
    } catch (e) {
      // Игнорируем ошибки сохранения настроек
    }
  }

  /// Обрабатывает изменение выбранной модели.
  ///
  /// Обновляет состояние и сохраняет выбранную модель в настройках.
  void _onModelChanged(String? modelId) {
    if (modelId == null || modelId.isEmpty) {
      return;
    }

    setState(() {
      _selectedModelId = modelId;
    });

    _saveSelectedModel(modelId);
  }

  /// Получает текущую выбранную модель для использования.
  ///
  /// Возвращает ID выбранной модели или модель из параметров виджета.
  String? get _currentModelId {
    return _selectedModelId ?? widget.selectedModel;
  }

  Future<void> _sendMessage() async {
    final apiClient = widget.apiClient;
    final selectedModel = _currentModelId;
    final canSend = !_isLoading && 
        apiClient != null && 
        selectedModel != null &&
        selectedModel.isNotEmpty;
    if (!canSend) {
      return;
    }

    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _messageController.clear();
    });

    // Добавляем сообщение пользователя
    final userMessage = _MessageItem(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMessage);
    });
    _scrollToBottom();

    try {
      // Отправляем запрос к API
      final result = await apiClient.sendMessage(
        message: messageText,
        model: selectedModel,
      );

      final now = DateTime.now();
      final tokensUsed = result.totalTokens ?? 0;

      // Сохраняем сообщение в кэш
      await ChatCache.instance.saveMessage(
        model: selectedModel,
        userMessage: messageText,
        aiResponse: result.text,
        tokensUsed: tokensUsed,
      );

      // Добавляем ответ AI
      final aiMessage = _MessageItem(
        text: result.text,
        isUser: false,
        timestamp: now,
        model: selectedModel,
      );
      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      // Показываем ошибку
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки сообщения: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
            onPressed: widget.onSave ?? _saveHistory,
          ),
          // Кнопка аналитики
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Аналитика',
            onPressed: widget.onAnalytics ?? _showAnalyticsDialog,
          ),
          // Кнопка очистки истории
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Очистить историю',
            onPressed: widget.onClear ?? _showClearHistoryDialog,
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
          // Селектор моделей
          if (_models.isNotEmpty || _isLoadingModels)
            Container(
              padding: EdgeInsets.all(
                PlatformUtils.isMobile() ? AppStyles.paddingSmall : AppStyles.padding,
              ),
              decoration: const BoxDecoration(
                color: AppStyles.cardColor,
                border: Border(
                  bottom: BorderSide(
                    color: AppStyles.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: _isLoadingModels
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppStyles.paddingSmall),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : ModelSelector(
                      models: _models,
                      selectedModelId: _currentModelId,
                      onChanged: _onModelChanged,
                      width: PlatformUtils.isMobile() ? null : AppStyles.searchFieldWidth,
                    ),
            ),
          // Область истории чата
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _messages.isEmpty && !_isLoading
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
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Индикатор загрузки
                        return const Padding(
                          padding: EdgeInsets.all(AppStyles.padding),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final message = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppStyles.paddingSmall,
                        ),
                        child: MessageBubble(
                          text: message.text,
                          isUser: message.isUser,
                          timestamp: message.timestamp,
                          model: message.model,
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
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppStyles.paddingSmall),
                        SizedBox(
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final apiClient = widget.apiClient;
                              final selectedModel = _currentModelId;
                              if (!_isLoading && 
                                  apiClient != null && 
                                  selectedModel != null &&
                                  selectedModel.isNotEmpty) {
                                _sendMessage();
                              }
                            },
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
                            enabled: !_isLoading,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: AppStyles.paddingSmall),
                        SizedBox(
                          width: AppStyles.buttonWidth,
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final apiClient = widget.apiClient;
                              final selectedModel = _currentModelId;
                              if (!_isLoading && 
                                  apiClient != null && 
                                  selectedModel != null &&
                                  selectedModel.isNotEmpty) {
                                _sendMessage();
                              }
                            },
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
