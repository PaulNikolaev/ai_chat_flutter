import 'package:flutter/material.dart';

import '../../auth/auth_manager.dart';
import '../../utils/platform.dart';
import '../styles.dart';

/// Экран авторизации для входа в приложение.
///
/// Поддерживает первый вход (только API ключ) и повторный вход
/// (PIN или API ключ). Отображает ошибки и статусы операций.
class LoginScreen extends StatefulWidget {
  /// Callback при успешной авторизации.
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
  final _authManager = AuthManager();

  bool _isFirstLogin = true;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final isAuthenticated = await _authManager.isAuthenticated();
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
          _showStatus('Введите API ключ');
          return;
        }

        final result = await _authManager.handleFirstLogin(apiKey);
        if (result.success) {
          _showStatus(
            'PIN сгенерирован: ${result.message}. Баланс: ${result.balance}',
            isError: false,
          );

          // Ждем немного, затем переходим в приложение
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            widget.onLoginSuccess?.call();
          }
        } else {
          _showStatus(result.message);
        }
      } else {
        // Повторный вход: PIN или API ключ
        if (pin.isNotEmpty && pin.length == 4) {
          // Попытка входа по PIN
          final result = await _authManager.handlePinLogin(pin);
          if (result.success) {
            if (mounted) {
              widget.onLoginSuccess?.call();
            }
            return;
          } else {
            _showStatus('Неверный PIN');
            return;
          }
        } else if (apiKey.isNotEmpty) {
          // Попытка входа по API ключу
          final result = await _authManager.handleApiKeyLogin(apiKey);
          if (result.success) {
            _showStatus(
              'Вход выполнен. ${result.message}. Баланс: ${result.balance}',
              isError: false,
            );

            // Ждем немного, затем переходим в приложение
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              widget.onLoginSuccess?.call();
            }
          } else {
            _showStatus(result.message);
          }
        } else {
          _showStatus('Введите PIN (4 цифры) или API ключ');
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
        title: const Text('Подтверждение сброса'),
        content: const Text(
          'Вы уверены, что хотите сбросить ключ? '
          'Все сохраненные данные аутентификации будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authManager.handleReset();
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
    final containerWidth = isMobile ? null : AppStyles.loginWindowWidth;

    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppStyles.padding : AppStyles.paddingLarge),
          child: Container(
            width: containerWidth,
            padding: EdgeInsets.all(
              isMobile ? AppStyles.padding : AppStyles.paddingLarge,
            ),
            decoration: AppStyles.loginWindowDecoration,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isFirstLogin ? 'Первичная авторизация' : 'Вход в приложение',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppStyles.padding),
                  if (!_isFirstLogin) ...[
                    TextFormField(
                      controller: _pinController,
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        hintText: 'Введите 4-значный PIN',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (!_isFirstLogin && value != null && value.isNotEmpty) {
                          if (value.length != 4) {
                            return 'PIN должен содержать 4 цифры';
                          }
                          if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                            return 'PIN должен содержать только цифры';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppStyles.paddingSmall),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppStyles.borderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppStyles.paddingSmall,
                          ),
                          child: Text(
                            'Или',
                            style: AppStyles.secondaryTextStyle.copyWith(
                              fontSize: AppStyles.fontSizeHint,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppStyles.borderColor)),
                      ],
                    ),
                    const SizedBox(height: AppStyles.paddingSmall),
                  ],
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Введите ключ OpenRouter или VSEGPT API',
                      prefixIcon: Icon(Icons.key),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    validator: (value) {
                      if (_isFirstLogin && (value == null || value.isEmpty)) {
                        return 'Введите API ключ';
                      }
                      return null;
                    },
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: AppStyles.paddingSmall),
                    Container(
                      padding: const EdgeInsets.all(AppStyles.paddingSmall),
                      decoration: BoxDecoration(
                        color: _isError
                            ? AppStyles.errorColor.withValues(alpha: 0.1)
                            : AppStyles.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                        border: Border.all(
                          color: _isError
                              ? AppStyles.errorColor
                              : AppStyles.successColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isError
                              ? AppStyles.errorColor
                              : AppStyles.successColor,
                          fontSize: AppStyles.fontSizeHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppStyles.padding),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleLogin,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Войти'),
                        style: AppStyles.sendButtonStyle,
                      ),
                      if (!_isFirstLogin) ...[
                        const SizedBox(width: AppStyles.padding),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _handleReset,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Сбросить ключ'),
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
    );
  }
}
