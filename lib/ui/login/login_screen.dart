import 'package:flutter/material.dart';

import 'package:ai_chat/auth/auth.dart';
import 'package:ai_chat/config/config.dart';
import 'package:ai_chat/ui/ui.dart';
import 'package:ai_chat/utils/utils.dart';

/// Экран авторизации для входа в приложение.
///
/// Предоставляет пользовательский интерфейс для аутентификации в приложении.
///
/// **Поддерживаемые сценарии:**
/// - **Первый вход**: только поле для API ключа
///   - Валидация API ключа через соответствующий провайдер
///   - Проверка баланса аккаунта
///   - Генерация и отображение PIN кода
///   - Автоматический переход в приложение после успешного входа
///
/// - **Повторный вход**: поля для PIN и API ключа
///   - Вход по PIN коду (4 цифры, скрывается при вводе)
///   - Обновление API ключа (с сохранением существующего PIN)
///   - Кнопка "Сбросить ключ" для полной очистки данных
///
/// **Особенности UI:**
/// - Адаптивный дизайн для мобильных, планшетов и десктопов
/// - Валидация формата API ключа и PIN в реальном времени
/// - Индикаторы загрузки во время операций
/// - Форматированные сообщения об ошибках с эмодзи
/// - Автоматическое определение режима входа (первый/повторный)
///
/// **Обработка ошибок:**
/// - Сетевые ошибки (отсутствие интернета, таймауты)
/// - Ошибки валидации (неверный формат ключа, неверный PIN)
/// - Ошибки сервера (5xx, rate limits)
/// - Ошибки базы данных (не удалось сохранить данные)
///
/// **Пример использования:**
/// ```dart
/// LoginScreen(
///   onLoginSuccess: () {
///     // Переход к основному экрану приложения
///     Navigator.pushReplacement(...);
///   },
/// )
/// ```
class LoginScreen extends StatefulWidget {
  /// Callback при успешной авторизации.
  ///
  /// Вызывается автоматически после успешного входа или обновления ключа.
  /// Используется для перехода к основному экрану приложения.
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _pinController = TextEditingController();
  AuthManager? _authManager;

  bool _isFirstLogin = true;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  /// Инициализирует AuthManager после загрузки конфигурации.
  Future<void> _initializeAuth() async {
    try {
      // Убеждаемся, что конфигурация загружена
      if (!EnvConfig.isLoaded) {
        await EnvConfig.load();
      }
      _authManager = AuthManager();
      _checkAuthStatus();
    } catch (e) {
      // Если не удалось загрузить .env, используем значения по умолчанию
      _authManager = AuthManager();
      _checkAuthStatus();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    if (_authManager == null) return;
    final isAuthenticated = await _authManager!.isAuthenticated();
    setState(() {
      _isFirstLogin = !isAuthenticated;
    });
  }

  void _clearStatus() {
    setState(() {
      _statusMessage = null;
      _isError = false;
    });
  }

  void _showStatus(String message, {bool isError = true}) {
    setState(() {
      _statusMessage = message;
      _isError = isError;
    });
  }

  /// Форматирует сообщение об ошибке для лучшего отображения пользователю.
  String _formatErrorMessage(String errorMessage) {
    // Улучшаем отображение различных типов ошибок
    if (errorMessage.contains('Invalid API key format') ||
        errorMessage.contains('must start with')) {
      return '❌ Неверный формат API ключа\n\n'
          'Ключ должен начинаться с:\n'
          '• sk-or-v1-... (OpenRouter)\n'
          '• sk-or-vv-... (VSEGPT)';
    }

    if (errorMessage.contains('Invalid API key') ||
        errorMessage.contains('Unauthorized') ||
        errorMessage.contains('401')) {
      return '❌ Неверный API ключ\n\n'
          'Проверьте правильность ключа и убедитесь, что он не был отозван.';
    }

    if (errorMessage.contains('Network error') ||
        errorMessage.contains('network') ||
        errorMessage.contains('Connection')) {
      return '❌ Ошибка сети\n\n'
          'Не удалось подключиться к серверу API.\n'
          'Проверьте подключение к интернету и попробуйте снова.';
    }

    if (errorMessage.contains('timeout') || errorMessage.contains('Timeout')) {
      return '⏱️ Превышено время ожидания\n\n'
          'Сервер не ответил вовремя.\n'
          'Проверьте подключение к интернету и попробуйте снова.';
    }

    if (errorMessage.contains('server error') ||
        errorMessage.contains('500') ||
        errorMessage.contains('502') ||
        errorMessage.contains('503')) {
      return '⚠️ Ошибка сервера\n\n'
          'Сервер API временно недоступен.\n'
          'Попробуйте позже.';
    }

    if (errorMessage.contains('429') || errorMessage.contains('rate limit')) {
      return '⏳ Превышен лимит запросов\n\n'
          'Слишком много запросов к API.\n'
          'Подождите немного и попробуйте снова.';
    }

    if (errorMessage.contains('Insufficient balance') ||
        errorMessage.contains('negative balance')) {
      return '💳 Недостаточно средств\n\n'
          'Баланс вашего аккаунта отрицательный.\n'
          'Пополните баланс перед продолжением.';
    }

    if (errorMessage.contains('Failed to save') ||
        errorMessage.contains('database')) {
      return '❌ Ошибка сохранения данных\n\n'
          'Не удалось сохранить данные аутентификации.\n'
          'Попробуйте снова.';
    }

    // Для остальных ошибок возвращаем оригинальное сообщение
    return '❌ $errorMessage';
  }

  /// Форматирует сообщение об ошибке для входа по PIN.
  String _formatPinErrorMessage(String errorMessage) {
    if (errorMessage.contains('Invalid PIN format') ||
        errorMessage.contains('4 digits')) {
      return '❌ Неверный формат PIN\n\n'
          'PIN должен содержать ровно 4 цифры (1000-9999).';
    }

    if (errorMessage.contains('Invalid PIN') ||
        errorMessage.contains('неверный')) {
      return '❌ Неверный PIN код\n\n'
          'Проверьте правильность введенного PIN и попробуйте снова.';
    }

    if (errorMessage.contains('Error verifying PIN') ||
        errorMessage.contains('Error retrieving')) {
      return '❌ Ошибка при проверке данных\n\n'
          'Не удалось проверить PIN код.\n'
          'Попробуйте снова или используйте API ключ для входа.';
    }

    if (errorMessage.contains('Authentication data not found') ||
        errorMessage.contains('not found')) {
      return '❌ Данные аутентификации не найдены\n\n'
          'Войдите с помощью API ключа для восстановления доступа.';
    }

    // Для остальных ошибок возвращаем оригинальное сообщение
    return '❌ $errorMessage';
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    _clearStatus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = _apiKeyController.text.trim();
      final pin = _pinController.text.trim();

      if (_isFirstLogin) {
        // Первый вход: только API ключ
        if (apiKey.isEmpty) {
          _showStatus('Пожалуйста, введите API ключ для первого входа');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Валидация API ключа выполняется, показываем индикатор загрузки
        final result = await _authManager!.handleFirstLogin(apiKey);
        if (result.success) {
          // Успешный вход: показываем PIN и баланс
          final pin = result.message;
          final balance = result.balance.isNotEmpty ? result.balance : '0.00';

          _showStatus(
            '✅ Успешная авторизация!\n\n'
            '🔐 Ваш PIN код: $pin\n'
            '💰 Баланс аккаунта: \$$balance\n\n'
            '⚠️ Сохраните PIN код в безопасном месте!\n'
            'Вы будете перенаправлены в приложение через 3 секунды...',
            isError: false,
          );

          // Ждем немного, чтобы пользователь успел увидеть PIN
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            widget.onLoginSuccess?.call();
          }
        } else {
          // Показываем понятное сообщение об ошибке
          _showStatus(_formatErrorMessage(result.message));
        }
      } else {
        // Повторный вход: PIN или API ключ
        if (pin.isNotEmpty && pin.length == 4) {
          // Попытка входа по PIN
          final result = await _authManager!.handlePinLogin(pin);
          if (result.success) {
            // Успешный вход по PIN
            if (mounted) {
              widget.onLoginSuccess?.call();
            }
            return;
          } else {
            // Показываем понятное сообщение об ошибке PIN
            _showStatus(_formatPinErrorMessage(result.message));
            return;
          }
        } else if (apiKey.isNotEmpty) {
          // Попытка входа по API ключу (обновление ключа)
          final result = await _authManager!.handleApiKeyLogin(apiKey);
          if (result.success) {
            // Успешное обновление ключа
            final balance = result.balance.isNotEmpty ? result.balance : '0.00';
            if (result.message.contains('updated')) {
              _showStatus(
                '✅ API ключ успешно обновлен!\n\n'
                '💰 Баланс аккаунта: \$$balance\n\n'
                'Ваш PIN код остался прежним.\n'
                'Вы будете перенаправлены в приложение через 2 секунды...',
                isError: false,
              );
            } else {
              // Новый PIN был сгенерирован (если почему-то PIN отсутствовал)
              _showStatus(
                '✅ Вход выполнен!\n\n'
                '🔐 Ваш PIN код: ${result.message}\n'
                '💰 Баланс аккаунта: \$$balance\n\n'
                'Вы будете перенаправлены в приложение через 2 секунды...',
                isError: false,
              );
            }

            // Автопереход: ждем немного, затем переходим в приложение
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              widget.onLoginSuccess?.call();
            }
          } else {
            // Показываем понятное сообщение об ошибке
            _showStatus(_formatErrorMessage(result.message));
          }
        } else {
          _showStatus('❌ Введите PIN (4 цифры) или API ключ для входа');
        }
      }
    } catch (e) {
      _showStatus('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleReset() async {
    if (_isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppStyles.warningColor,
              size: 28,
            ),
            SizedBox(width: AppStyles.paddingSmall),
            Expanded(
              child: Text(
                'Подтверждение сброса',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы уверены, что хотите сбросить ключ?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppStyles.paddingSmall),
            Text(
              '⚠️ Все сохраненные данные аутентификации будут удалены:',
            ),
            SizedBox(height: AppStyles.paddingSmall),
            Padding(
              padding: EdgeInsets.only(left: AppStyles.paddingSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• API ключ'),
                  Text('• PIN код'),
                  Text('• Данные провайдера'),
                ],
              ),
            ),
            SizedBox(height: AppStyles.paddingSmall),
            Text(
              'После сброса вам потребуется ввести новый API ключ.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppStyles.textSecondary,
              ),
            ),
          ],
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
            child: const Text(
              'Сбросить',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authManager!.handleReset();
      if (success) {
        setState(() {
          _isFirstLogin = true;
          _apiKeyController.clear();
          _pinController.clear();
          _clearStatus();
        });
      } else {
        _showStatus('Ошибка сброса ключа');
      }
    } catch (e) {
      _showStatus('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformUtils.isMobile();
    final isTablet = PlatformUtils.isTablet(context);
    final isLandscape = PlatformUtils.isLandscape(context);
    final padding = AppStyles.getPadding(context);
    final buttonHeight = AppStyles.getButtonHeight(context);
    final inputHeight = AppStyles.getInputHeight(context);
    final maxContentWidth = AppStyles.getMaxContentWidth(context);

    // Адаптивная ширина контейнера
    double? containerWidth;
    if (isMobile) {
      containerWidth = null; // Полная ширина на мобильных
    } else if (isTablet) {
      containerWidth = isLandscape ? 600.0 : 500.0; // Шире в landscape
    } else {
      containerWidth = AppStyles.loginWindowWidth; // Десктоп
    }

    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth ?? double.infinity,
            ),
            child: Container(
              width: containerWidth,
              padding: EdgeInsets.all(padding * 1.5),
              decoration: AppStyles.loginWindowDecoration,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isFirstLogin
                          ? 'Первичная авторизация'
                          : 'Вход в приложение',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppStyles.padding),
                    // Повторный вход: отображаем поля для PIN и API ключа
                    if (!_isFirstLogin) ...[
                      // Поле для ввода PIN кода
                      // PIN скрывается при вводе (obscureText: true) для безопасности
                      SizedBox(
                        height: inputHeight,
                        child: TextFormField(
                          controller: _pinController,
                          decoration: const InputDecoration(
                            labelText: 'PIN',
                            hintText: 'Введите 4-значный PIN',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText:
                              true, // PIN скрывается при вводе для безопасности
                          textInputAction: TextInputAction.next,
                          style: AppStyles.primaryTextStyle,
                          validator: (value) {
                            if (!_isFirstLogin &&
                                value != null &&
                                value.isNotEmpty) {
                              // Валидация формата PIN: должен быть ровно 4 цифры
                              if (value.length != 4) {
                                return 'PIN должен содержать ровно 4 цифры (1000-9999)';
                              }
                              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                                return 'PIN должен содержать только цифры';
                              }
                              // Проверяем диапазон (1000-9999)
                              final pinValue = int.tryParse(value);
                              if (pinValue == null ||
                                  pinValue < 1000 ||
                                  pinValue > 9999) {
                                return 'PIN должен быть числом от 1000 до 9999';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppStyles.paddingSmall),
                      // Разделитель между полями PIN и API ключа
                      const Row(
                        children: [
                          Expanded(
                              child: Divider(color: AppStyles.borderColor)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppStyles.paddingSmall,
                            ),
                            child: Text(
                              'Или',
                              style: TextStyle(
                                color: AppStyles.textSecondary,
                                fontSize: AppStyles.fontSizeHint,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: AppStyles.borderColor)),
                        ],
                      ),
                      const SizedBox(height: AppStyles.paddingSmall),
                    ],
                    SizedBox(
                      height: inputHeight,
                      child: TextFormField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Введите ключ OpenRouter или VSEGPT API',
                          prefixIcon: Icon(Icons.key),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        style: AppStyles.primaryTextStyle,
                        onFieldSubmitted: (_) => _handleLogin(),
                        validator: (value) {
                          if (_isFirstLogin &&
                              (value == null || value.isEmpty)) {
                            return 'Введите API ключ';
                          }
                          // Валидация формата API ключа при вводе
                          if (value != null && value.isNotEmpty) {
                            final trimmed = value.trim();
                            if (!trimmed.startsWith('sk-or-')) {
                              return 'Ключ должен начинаться с "sk-or-v1-" (OpenRouter) или "sk-or-vv-" (VSEGPT)';
                            }
                            if (!trimmed.startsWith('sk-or-v1-') &&
                                !trimmed.startsWith('sk-or-vv-')) {
                              return 'Неверный формат ключа. Используйте "sk-or-v1-..." или "sk-or-vv-..."';
                            }
                            // Минимальная длина ключа (примерно)
                            if (trimmed.length < 20) {
                              return 'API ключ слишком короткий. Проверьте правильность ввода';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: AppStyles.paddingSmall),
                      Container(
                        padding: EdgeInsets.all(_isFirstLogin && !_isError
                            ? AppStyles.padding
                            : AppStyles.paddingSmall),
                        decoration: BoxDecoration(
                          color: _isError
                              ? AppStyles.errorColor.withValues(alpha: 0.1)
                              : AppStyles.successColor.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppStyles.borderRadius),
                          border: Border.all(
                            color: _isError
                                ? AppStyles.errorColor
                                : AppStyles.successColor,
                            width: _isFirstLogin && !_isError ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _isError
                                ? AppStyles.errorColor
                                : AppStyles.successColor,
                            fontSize: _isFirstLogin && !_isError
                                ? AppStyles.fontSizeDefault
                                : AppStyles.fontSizeHint,
                            fontWeight: _isFirstLogin && !_isError
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (_isLoading && _isFirstLogin) ...[
                      const SizedBox(height: AppStyles.paddingSmall),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: AppStyles.paddingSmall),
                            Text(
                              'Проверка API ключа...',
                              style: TextStyle(
                                color: AppStyles.textSecondary,
                                fontSize: AppStyles.fontSizeHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppStyles.padding),
                    (isMobile || (isTablet && isLandscape))
                        ? // Вертикальный layout для мобильных и планшетов в landscape
                        Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.login),
                                  label: const Text('Войти'),
                                  style: AppStyles.sendButtonStyle,
                                ),
                              ),
                              if (!_isFirstLogin) ...[
                                const SizedBox(height: AppStyles.paddingSmall),
                                SizedBox(
                                  height: buttonHeight,
                                  child: TextButton.icon(
                                    onPressed: _isLoading ? null : _handleReset,
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('Сбросить ключ'),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : // Горизонтальный layout для десктопов и планшетов в portrait
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.login),
                                  label: const Text('Войти'),
                                  style: AppStyles.sendButtonStyle,
                                ),
                              ),
                              // Кнопка "Сбросить ключ" отображается только при повторном входе
                              if (!_isFirstLogin) ...[
                                const SizedBox(width: AppStyles.padding),
                                SizedBox(
                                  height: buttonHeight,
                                  child: TextButton.icon(
                                    onPressed: _isLoading ? null : _handleReset,
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('Сбросить ключ'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
