import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ai_chat/api/api.dart';
import 'package:ai_chat/models/models.dart';
import 'package:ai_chat/ui/ui.dart';
import 'package:ai_chat/utils/utils.dart';

/// Главный экран чата с историей сообщений и полем ввода.
///
/// Предоставляет базовую структуру UI с AppBar, областью истории чата
/// и полем ввода сообщения. Поддерживает адаптивный layout для мобильных/десктопных устройств.
///
/// Адаптирован для работы в многостраничном режиме:
/// - Упрощенный AppBar без дублирования функционала (аналитика доступна через навигацию)
/// - Кнопка выхода вызывает callback для перехода на страницу входа
/// - Автоматически скрывает кнопку "назад" в контексте HomeScreen
class ChatScreen extends StatefulWidget {
  /// API клиент для отправки сообщений.
  final OpenRouterClient? apiClient;

  /// Выбранная модель для использования.
  final String? selectedModel;

  /// Callback при нажатии кнопки сохранения.
  final VoidCallback? onSave;

  /// Callback при нажатии кнопки очистки истории.
  final VoidCallback? onClear;

  /// Callback при нажатии кнопки выхода.
  final VoidCallback? onLogout;

  const ChatScreen({
    super.key,
    this.apiClient,
    this.selectedModel,
    this.onSave,
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

  // Экземпляр для аналитики
  final Analytics _analytics = Analytics();
  AppLogger? _logger;

  // Состояние для моделей
  List<ModelInfo> _models = [];
  String? _selectedModelId;
  bool _isLoadingModels = false;

  // Ключ для сохранения выбранной модели
  static const String _selectedModelKey = 'selected_model_id';

  @override
  void initState() {
    super.initState();
    _initializeLogger();
    _loadChatHistory();
    _loadSelectedModel();
    // Ленивая загрузка моделей - загружаем только при первом открытии селектора
    // _loadModels(); // Удалено - загрузка будет по требованию
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если изменился API клиент (например, при переключении провайдера),
    // очищаем кэш моделей и историю чата
    if (widget.apiClient != oldWidget.apiClient) {
      // Очищаем список моделей для принудительной перезагрузки
      setState(() {
        _models = [];
        _isLoadingModels = false;
        // Очищаем выбранную модель, так как модели разных провайдеров несовместимы
        _selectedModelId = null;
        // Очищаем историю чата в UI, так как она уже очищена в БД при переключении провайдера
        _messages.clear();
      });
      // Очищаем сохраненную модель из настроек
      _clearSavedModel();
      // Перезагружаем историю (она будет пустой после очистки при переключении провайдера)
      _loadChatHistory();
    }
  }

  /// Инициализирует логирование для экрана чата.
  Future<void> _initializeLogger() async {
    try {
      _logger = await AppLogger.create();
      _logger?.info('ChatScreen initialized');
    } catch (e) {
      // Игнорируем ошибки инициализации логирования
    }
  }

  /// Получает понятное сообщение об ошибке для пользователя.
  ///
  /// Преобразует технические сообщения об ошибках в понятные пользователю.
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Проблема с подключением к интернету. Проверьте соединение и попробуйте снова.';
    }
    
    if (errorString.contains('timeout')) {
      return 'Превышено время ожидания ответа. Сервер не отвечает. Попробуйте позже.';
    }
    
    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Неверный API ключ. Проверьте ключ в настройках.';
    }
    
    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return 'Слишком много запросов. Подождите немного и попробуйте снова.';
    }
    
    if (errorString.contains('500') || errorString.contains('502') || errorString.contains('503')) {
      return 'Сервер временно недоступен. Попробуйте позже.';
    }
    
    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Запрашиваемый ресурс не найден. Проверьте настройки.';
    }
    
    // Для остальных ошибок возвращаем оригинальное сообщение, но убираем технические детали
    return error.toString().split('\n').first;
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
      _logger?.debug('Loading chat history from cache');
      final history = await ChatCache.instance.getChatHistory(
          limit: AppConstants.maxChatHistoryMessages);

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

      _logger?.info('Chat history loaded: ${loadedMessages.length} messages');
      // Автоскролл к последнему сообщению после загрузки истории
      _scrollToBottom();
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to load chat history',
        error: e,
        stackTrace: stackTrace,
      );
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
      _logger?.info('Clearing chat history');
      final success = await ChatCache.instance.clearHistory();

      if (success) {
        setState(() {
          _messages.clear();
        });
        _logger?.info('Chat history cleared successfully');

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
        _logger?.error('Failed to clear history: clearHistory returned false');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Ошибка при очистке истории: не удалось удалить записи из базы данных'),
              backgroundColor: AppStyles.errorColor,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to clear chat history',
        error: e,
        stackTrace: stackTrace,
      );
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
      _logger?.info('Exporting chat history to JSON');
      // Получаем JSON строку с историей
      final jsonString = await ChatCache.instance.exportHistoryToJson();

      if (jsonString == null || jsonString.isEmpty) {
        _logger?.warning('Chat history is empty, nothing to export');
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
        _logger?.debug('Created export directory: ${exportDir.path}');
      }

      // Создаем имя файла с текущей датой и временем
      final now = DateTime.now();
      final dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
      final fileName = 'chat_history_${dateFormat.format(now)}.json';
      final filePath = '${exportDir.path}/$fileName';

      // Сохраняем файл
      final file = File(filePath);
      await file.writeAsString(jsonString);
      _logger?.info('Chat history exported to: $filePath');

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
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to export chat history',
        error: e,
        stackTrace: stackTrace,
      );
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

  /// Загружает список моделей из API (ленивая загрузка).
  ///
  /// Получает список доступных моделей от OpenRouter API и обновляет состояние.
  /// Загружает модели только если они еще не загружены (ленивая загрузка).
  /// Показывает ошибку, если загрузка не удалась.
  Future<void> _loadModels({bool forceRefresh = false}) async {
    final apiClient = widget.apiClient;
    if (apiClient == null) {
      _logger?.warning('Cannot load models: API client is null');
      return;
    }

    // Если модели уже загружены и не требуется обновление, пропускаем загрузку
    if (!forceRefresh && _models.isNotEmpty && !_isLoadingModels) {
      return;
    }

    setState(() {
      _isLoadingModels = true;
    });

    try {
      _logger?.debug('Loading models from API');
      final models = await apiClient.getModels(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;

          // Проверяем, существует ли сохраненная модель в новом списке моделей
          if (_selectedModelId != null) {
            final modelExists =
                models.any((model) => model.id == _selectedModelId);
            if (!modelExists) {
              // Если сохраненная модель не найдена (например, при переключении провайдера),
              // очищаем её и выбираем первую доступную
              _logger?.info(
                  'Saved model $_selectedModelId not found in new list, selecting default');
              _selectedModelId = null;
              _clearSavedModel();
            }
          }

          // Если модель не выбрана, выбираем первую доступную
          if (_selectedModelId == null && models.isNotEmpty) {
            _selectedModelId = models.first.id;
            _saveSelectedModel(_selectedModelId!);
            _logger?.info('Default model selected: $_selectedModelId');
          }
        });
        _logger?.info('Models loaded successfully: ${models.length} models');
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to load models',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки моделей: ${_getUserFriendlyErrorMessage(e)}'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Повторить',
              textColor: AppStyles.textPrimary,
              onPressed: () {
                _loadModels(forceRefresh: true);
              },
            ),
          ),
        );
      }
    }
  }

  /// Загружает сохраненную выбранную модель из настроек.
  ///
  /// Восстанавливает последнюю выбранную модель из PreferencesService.
  Future<void> _loadSelectedModel() async {
    try {
      _logger?.debug('Loading saved model preference');
      final savedModelId =
          await PreferencesService.instance.getString(_selectedModelKey);

      if (mounted && savedModelId != null && savedModelId.isNotEmpty) {
        setState(() {
          _selectedModelId = savedModelId;
        });
        _logger?.info('Loaded saved model: $savedModelId');
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
      _logger?.warning('Failed to load saved model preference: $e');
      // Игнорируем ошибки загрузки настроек
    }
  }

  /// Сохраняет выбранную модель в настройках.
  ///
  /// Сохраняет ID выбранной модели в PreferencesService для восстановления при следующем запуске.
  Future<void> _saveSelectedModel(String modelId) async {
    try {
      await PreferencesService.instance.saveString(_selectedModelKey, modelId);
      _logger?.debug('Saved model preference: $modelId');
    } catch (e) {
      _logger?.warning('Failed to save model preference: $e');
      // Игнорируем ошибки сохранения настроек
    }
  }

  /// Очищает сохраненную модель из настроек.
  ///
  /// Используется при переключении провайдера, когда модели становятся несовместимыми.
  Future<void> _clearSavedModel() async {
    try {
      await PreferencesService.instance.remove(_selectedModelKey);
      _logger?.debug('Cleared saved model preference');
    } catch (e) {
      _logger?.warning('Failed to clear saved model preference: $e');
      // Игнорируем ошибки очистки настроек
    }
  }

  /// Обрабатывает изменение выбранной модели.
  ///
  /// Обновляет состояние и сохраняет выбранную модель в настройках.
  /// Очищает историю чата при смене модели, так как контекст может быть несовместим.
  void _onModelChanged(String? modelId) {
    if (modelId == null || modelId.isEmpty) {
      return;
    }

    // Если модель изменилась, очищаем историю чата
    final previousModelId = _selectedModelId;
    if (previousModelId != null && previousModelId != modelId) {
      _logger?.info(
          'Model changed from $previousModelId to $modelId, clearing chat history');
      _clearHistorySilently();
    }

    _logger?.info('Model changed to: $modelId');
    setState(() {
      _selectedModelId = modelId;
    });

    _saveSelectedModel(modelId);
  }

  /// Очищает историю чата без показа диалога подтверждения.
  ///
  /// Используется при автоматической очистке (например, при смене модели или провайдера).
  Future<void> _clearHistorySilently() async {
    try {
      _logger?.info('Clearing chat history silently');
      final success = await ChatCache.instance.clearHistory();

      if (success) {
        setState(() {
          _messages.clear();
        });
        _logger?.info('Chat history cleared successfully');
      } else {
        _logger?.error('Failed to clear history: clearHistory returned false');
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to clear chat history',
        error: e,
        stackTrace: stackTrace,
      );
    }
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

    if (mounted) {
      setState(() {
        _isLoading = true;
        _messageController.clear();
      });
    }

    // Добавляем сообщение пользователя
    final userMessage = _MessageItem(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _messages.add(userMessage);
      });
    }
    _scrollToBottom();

    try {
      _logger?.debug('Sending message to model: $selectedModel');
      final startTime = DateTime.now();

      // Отправляем запрос к API
      final result = await apiClient.sendMessage(
        message: messageText,
        model: selectedModel,
      );

      final now = DateTime.now();
      final responseTime = now.difference(startTime).inMilliseconds / 1000.0;
      final tokensUsed = result.totalTokens ?? 0;

      _logger?.info(
        'Message sent successfully. Response time: ${responseTime.toStringAsFixed(2)}s, Tokens: $tokensUsed',
      );

      // Отслеживаем метрики производительности и аналитику
      try {
        // Находим информацию о модели для получения цен
        final modelInfo = _models.firstWhere(
          (m) => m.id == selectedModel,
          orElse: () => ModelInfo(id: selectedModel, name: selectedModel),
        );

        await _analytics.trackMessage(
          model: selectedModel,
          messageLength: messageText.length,
          responseTime: responseTime,
          tokensUsed: tokensUsed,
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
          promptPrice: modelInfo.promptPrice,
          completionPrice: modelInfo.completionPrice,
        );
      } catch (e, stackTrace) {
        _logger?.error(
          'Failed to track analytics',
          error: e,
          stackTrace: stackTrace,
        );
        // Продолжаем работу даже если аналитика не записалась
      }

      // Сохраняем сообщение в кэш
      try {
        await ChatCache.instance.saveMessage(
          model: selectedModel,
          userMessage: messageText,
          aiResponse: result.text,
          tokensUsed: tokensUsed,
        );
        _logger?.debug('Message saved to cache');
      } catch (e, stackTrace) {
        _logger?.error(
          'Failed to save message to cache',
          error: e,
          stackTrace: stackTrace,
        );
        // Продолжаем работу даже если сохранение не удалось
      }

      // Добавляем ответ AI
      if (mounted) {
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
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Failed to send message',
        error: e,
        stackTrace: stackTrace,
      );
      // Показываем ошибку
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    final isTablet = PlatformUtils.isTablet(context);
    final isLandscape = PlatformUtils.isLandscape(context);
    final screenSize = PlatformUtils.getScreenSize(context);
    final theme = Theme.of(context);
    final padding = AppStyles.getPadding(context);
    final buttonHeight = AppStyles.getButtonHeight(context);
    final inputHeight = AppStyles.getInputHeight(context);
    final maxContentWidth = AppStyles.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      appBar: AppBar(
        title: const Text('AI Chat'),
        automaticallyImplyLeading:
            false, // Убираем кнопку "назад" в контексте HomeScreen
        actions: [
          // Кнопка сохранения истории чата
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Сохранить диалог',
            onPressed: widget.onSave ?? _saveHistory,
          ),
          // Кнопка очистки истории чата
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Очистить историю',
            onPressed: widget.onClear ?? _showClearHistoryDialog,
          ),
          // Кнопка выхода из приложения
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Селектор моделей (ленивая загрузка при первом открытии)
          GestureDetector(
            onTap: () {
              // Загружаем модели при первом клике на селектор
              if (_models.isEmpty && !_isLoadingModels) {
                _loadModels();
              }
            },
            child: Container(
              padding: EdgeInsets.all(padding),
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
                        child: AnimatedLoadingIndicator(
                          size: 24,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _models.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppStyles.paddingSmall),
                            child: Text(
                              'Нажмите для загрузки моделей',
                              style: TextStyle(color: AppStyles.textSecondary),
                            ),
                          ),
                        )
                      : ModelSelector(
                          models: _models,
                          selectedModelId: _currentModelId,
                          onChanged: _onModelChanged,
                          width: PlatformUtils.isMobile()
                              ? null
                              : AppStyles.searchFieldWidth,
                        ),
            ),
          ),
          // Область истории чата
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: AnimatedLoadingIndicator(
                      usePulse: true,
                    ),
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
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth ?? double.infinity,
                          ),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(padding),
                            // Оптимизация: кэшируем больше элементов для плавной прокрутки
                            cacheExtent: 500,
                            // Оптимизация: добавляем key для эффективного обновления
                            itemCount: _messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) {
                                // Индикатор загрузки
                                return const Padding(
                                  padding: EdgeInsets.all(AppStyles.padding),
                                  child: Center(
                                    child: AnimatedLoadingIndicator(
                                      size: 20,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final message = _messages[index];
                              // Оптимизация: используем RepaintBoundary для изоляции перерисовок
                              return RepaintBoundary(
                                key: ValueKey(
                                    'message_${message.timestamp.millisecondsSinceEpoch}_$index'),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppStyles.paddingSmall,
                                  ),
                                  child: MessageBubble(
                                    text: message.text,
                                    isUser: message.isUser,
                                    timestamp: message.timestamp,
                                    model: message.model,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
          // Область ввода сообщения
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxContentWidth ?? double.infinity,
              ),
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: const BoxDecoration(
                  color: AppStyles.cardColor,
                  border: Border(
                    top: BorderSide(
                      color: AppStyles.borderColor,
                      width: 1,
                    ),
                  ),
                ),
                child: (isMobile || (isTablet && isLandscape))
                    ? // Мобильный layout: поле ввода и кнопка вертикально
                    Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: inputHeight,
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Введите сообщение здесь...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppStyles.borderRadius,
                                  ),
                                ),
                                contentPadding: EdgeInsets.all(
                                  screenSize == 'small'
                                      ? AppStyles.paddingSmall
                                      : AppStyles.paddingSmall * 1.5,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              style: AppStyles.primaryTextStyle,
                              enabled: !_isLoading,
                            ),
                          ),
                          const SizedBox(height: AppStyles.paddingSmall),
                          SizedBox(
                            height: buttonHeight,
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
                    : // Десктопный/планшетный portrait layout: поле ввода и кнопка горизонтально
                    Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: inputHeight,
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Введите сообщение здесь...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppStyles.borderRadius,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.all(
                                    screenSize == 'small'
                                        ? AppStyles.paddingSmall
                                        : AppStyles.paddingSmall * 1.5,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.newline,
                                style: AppStyles.primaryTextStyle,
                                enabled: !_isLoading,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppStyles.paddingSmall),
                          SizedBox(
                            width: isTablet
                                ? AppStyles.buttonWidth * 0.8
                                : AppStyles.buttonWidth,
                            height: buttonHeight,
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
            ),
          ),
        ],
      ),
    );
  }
}
