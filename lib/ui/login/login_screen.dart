import 'package:flutter/material.dart';

import '../../auth/auth_manager.dart';
import '../../config/env.dart';
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

        final result = await _authManager!.handleFirstLogin(apiKey);
        if (result.success) {
          print('[LOGIN] ✅ First login successful');
          print('[LOGIN] PIN: ${result.message}, Balance: ${result.balance}');
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
          print('[LOGIN] ❌ First login failed: ${result.message}');
          _showStatus(result.message);
        }
      } else {
        // Повторный вход: PIN или API ключ
        if (pin.isNotEmpty && pin.length == 4) {
          // Попытка входа по PIN
          final result = await _authManager!.handlePinLogin(pin);
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
          final result = await _authManager!.handleApiKeyLogin(apiKey);
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
    } catch (e, stackTrace) {
      print('[LOGIN] ❌ Exception during login: $e');
      print('[LOGIN] Stack trace: $stackTrace');
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
    } catch (e, stackTrace) {
      print('[LOGIN] ❌ Exception during reset: $e');
      print('[LOGIN] Stack trace: $stackTrace');
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
                    _isFirstLogin ? 'Первичная авторизация' : 'Вход в приложение',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppStyles.padding),
                  if (!_isFirstLogin) ...[
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
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        style: AppStyles.primaryTextStyle,
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
                    ),
                    const SizedBox(height: AppStyles.paddingSmall),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppStyles.borderColor)),
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
                        Expanded(child: Divider(color: AppStyles.borderColor)),
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
                        if (_isFirstLogin && (value == null || value.isEmpty)) {
                          return 'Введите API ключ';
                        }
                        return null;
                      },
                    ),
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
                                          child: CircularProgressIndicator(strokeWidth: 2),
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
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.login),
                                  label: const Text('Войти'),
                                  style: AppStyles.sendButtonStyle,
                                ),
                              ),
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
