import 'package:flutter/material.dart';

import 'package:ai_chat/auth/auth.dart';
import 'package:ai_chat/navigation/navigation.dart';
import 'package:ai_chat/ui/ui.dart';
import 'package:ai_chat/utils/utils.dart';

/// Страница настроек провайдера и API ключей.
///
/// Отображает:
/// - Текущий провайдер (OpenRouter/VSEGPT)
/// - Маскированный API ключ
/// - Возможность обновления настроек (будет добавлено в следующих подэтапах)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthManager _authManager = AuthManager();
  final _apiKeyController = TextEditingController();
  final _apiKeyFormKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isUpdatingProvider = false;
  bool _isAddingApiKey = false;
  bool _showApiKeyForm = false;
  String? _activeProvider;
  List<Map<String, String>> _allApiKeys = [];
  String? _errorMessage;
  String? _successMessage;
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  /// Загружает текущие настройки из хранилища.
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Получаем активного провайдера
      final provider = await _authManager.getStoredProvider();

      // Получаем все API ключи
      final allKeys = await _authManager.getAllStoredApiKeys();

      if (mounted) {
        setState(() {
          _activeProvider = provider;
          _allApiKeys = allKeys;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки настроек: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Обрабатывает смену активного провайдера.
  Future<void> _handleProviderChange(String? newProvider) async {
    if (newProvider == null || newProvider == _activeProvider) {
      return;
    }

    // Проверяем, есть ли ключ для этого провайдера
    final hasKey = _allApiKeys.any((key) => key['provider'] == newProvider);
    if (!hasKey) {
      setState(() {
        _errorMessage =
            'API ключ для $newProvider не найден. Пожалуйста, добавьте ключ для этого провайдера.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: AppStyles.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isUpdatingProvider = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _authManager.updateProvider(newProvider);

      if (mounted) {
        if (result.success) {
          setState(() {
            _activeProvider = newProvider;
            _successMessage = result.message;
            _isUpdatingProvider = false;
          });

          // Обновляем список ключей
          await _loadSettings();

          // Обновляем API клиент с новым провайдером
          if (AppRouter.onProviderChanged != null) {
            await AppRouter.onProviderChanged!();
          }

          // Показываем сообщение об успехе
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: AppStyles.successColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }

          // Очищаем сообщение через 3 секунды
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _successMessage = null;
              });
            }
          });
        } else {
          setState(() {
            _errorMessage = result.message;
            _isUpdatingProvider = false;
          });

          // Показываем сообщение об ошибке
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppStyles.errorColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка обновления провайдера: $e';
          _isUpdatingProvider = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления провайдера: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Обрабатывает добавление/обновление API ключа.
  Future<void> _handleApiKeyUpdate() async {
    if (!_apiKeyFormKey.currentState!.validate()) {
      return;
    }

    final newApiKey = _apiKeyController.text.trim();
    if (newApiKey.isEmpty) {
      setState(() {
        _apiKeyError = 'API ключ не может быть пустым';
      });
      return;
    }

    setState(() {
      _isAddingApiKey = true;
      _apiKeyError = null;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Используем addApiKey для добавления нового ключа
      final result = await _authManager.addApiKey(newApiKey);

      if (mounted) {
        if (result.success) {
          // Очищаем форму и скрываем её
          _apiKeyController.clear();
          setState(() {
            _showApiKeyForm = false;
            _isAddingApiKey = false;
            _successMessage = result.balance.isNotEmpty
                ? 'API ключ успешно добавлен. Баланс: ${result.balance}'
                : 'API ключ успешно добавлен';
          });

          // Перезагружаем настройки для отображения нового ключа
          await _loadSettings();

          // Показываем сообщение об успехе
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.balance.isNotEmpty
                    ? 'API ключ добавлен. Баланс: ${result.balance}'
                    : 'API ключ успешно добавлен'),
                backgroundColor: AppStyles.successColor,
                duration: const Duration(seconds: 5),
              ),
            );
          }

          // Очищаем сообщение через 5 секунд
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _successMessage = null;
              });
            }
          });
        } else {
          setState(() {
            _apiKeyError = result.message;
            _isAddingApiKey = false;
          });

          // Показываем сообщение об ошибке
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppStyles.errorColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiKeyError = 'Ошибка добавления API ключа: $e';
          _isAddingApiKey = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка добавления API ключа: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Обрабатывает удаление API ключа для указанного провайдера.
  Future<void> _handleDeleteApiKey(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление API ключа'),
        content: Text('Вы уверены, что хотите удалить API ключ для $provider?'),
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
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final deleted = await _authManager.deleteApiKey(provider);
      if (deleted) {
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('API ключ для $provider удален'),
              backgroundColor: AppStyles.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления API ключа для $provider'),
              backgroundColor: AppStyles.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления API ключа: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Маскирует API ключ, оставляя только первые и последние символы видимыми.
  ///
  /// Пример: `sk-or-v1-abc123def456` -> `sk-or-v1-***...***456`
  String _maskApiKey(String apiKey) {
    if (apiKey.isEmpty) {
      return 'Не установлен';
    }

    if (apiKey.length <= 12) {
      // Если ключ слишком короткий, маскируем полностью
      return '***${apiKey.substring(apiKey.length - 3)}';
    }

    // Оставляем первые 8 символов и последние 4 символа видимыми
    final prefix = apiKey.substring(0, 8);
    final suffix = apiKey.substring(apiKey.length - 4);
    return '$prefix...$suffix';
  }

  /// Получает название провайдера для отображения.
  String _getProviderDisplayName(String provider) {
    switch (provider) {
      case 'openrouter':
        return 'OpenRouter';
      case 'vsegpt':
        return 'VSEGPT';
      default:
        return provider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformUtils.isMobile();
    final padding = AppStyles.getPadding(context);
    final maxContentWidth = AppStyles.getMaxContentWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings, size: 24),
            SizedBox(width: 8),
            Text('Настройки'),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: AppRouter.onLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: AnimatedLoadingIndicator(
                usePulse: true,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppStyles.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppStyles.errorColor,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadSettings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxContentWidth ?? double.infinity,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Заголовок страницы
                          if (!isMobile) ...[
                            const Row(
                              children: [
                                Icon(
                                  Icons.account_circle,
                                  size: 32,
                                  color: AppStyles.accentColor,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Настройки аккаунта',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppStyles.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppStyles.paddingLarge),
                          ],

                          // Раздел: Провайдер
                          _buildSectionHeader(
                            icon: Icons.cloud_circle,
                            title: 'Провайдер API',
                            subtitle: 'Выберите провайдера для подключения',
                          ),
                          const SizedBox(height: AppStyles.paddingSmall),
                          _buildProviderSection(),
                          const SizedBox(height: AppStyles.paddingLarge),

                          // Разделитель
                          const Divider(
                              color: AppStyles.borderColor, thickness: 1),
                          const SizedBox(height: AppStyles.paddingLarge),

                          // Раздел: API ключ
                          _buildSectionHeader(
                            icon: Icons.security,
                            title: 'API Ключ',
                            subtitle: 'Управление ключом доступа',
                          ),
                          const SizedBox(height: AppStyles.paddingSmall),
                          _buildApiKeySection(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  /// Строит заголовок секции с иконкой и описанием.
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppStyles.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          ),
          child: Icon(
            icon,
            color: AppStyles.accentColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppStyles.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Строит секцию с информацией о провайдере.
  Widget _buildProviderSection() {
    final isMobile = PlatformUtils.isMobile();

    return Container(
      padding:
          EdgeInsets.all(isMobile ? AppStyles.paddingSmall : AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppStyles.paddingSmall),
          // Переключатель провайдера
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'openrouter',
                label: Text(isMobile ? 'OpenRouter' : 'OpenRouter'),
                icon: const Icon(Icons.cloud, size: 20),
                tooltip: 'OpenRouter API',
              ),
              ButtonSegment<String>(
                value: 'vsegpt',
                label: Text(isMobile ? 'VSEGPT' : 'VSEGPT'),
                icon: const Icon(Icons.router, size: 20),
                tooltip: 'VSEGPT API',
              ),
            ],
            selected: _activeProvider != null ? {_activeProvider!} : <String>{},
            onSelectionChanged: _isUpdatingProvider
                ? null
                : (Set<String> newSelection) {
                    if (newSelection.isNotEmpty) {
                      _handleProviderChange(newSelection.first);
                    }
                  },
            selectedIcon: const Icon(Icons.check, size: 18),
            style: SegmentedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 16,
                vertical: isMobile ? 8 : 12,
              ),
            ),
          ),
          if (_isUpdatingProvider) ...[
            const SizedBox(height: AppStyles.paddingSmall),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppStyles.paddingSmall),
                Text(
                  'Обновление провайдера...',
                  style: TextStyle(
                    color: AppStyles.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: AppStyles.paddingSmall),
            Container(
              padding: const EdgeInsets.all(AppStyles.paddingSmall),
              decoration: BoxDecoration(
                color: AppStyles.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                border: Border.all(
                  color: AppStyles.successColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppStyles.successColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppStyles.paddingSmall),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                        color: AppStyles.successColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppStyles.paddingSmall),
            Container(
              padding: const EdgeInsets.all(AppStyles.paddingSmall),
              decoration: BoxDecoration(
                color: AppStyles.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                border: Border.all(
                  color: AppStyles.errorColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppStyles.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppStyles.paddingSmall),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppStyles.errorColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Строит секцию с информацией об API ключе.
  Widget _buildApiKeySection() {
    final isMobile = PlatformUtils.isMobile();

    return Container(
      padding:
          EdgeInsets.all(isMobile ? AppStyles.paddingSmall : AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppStyles.paddingSmall),
          // Список всех API ключей
          if (_allApiKeys.isNotEmpty) ...[
            const SizedBox(height: AppStyles.paddingSmall),
            const Text(
              'Сохраненные ключи:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppStyles.textSecondary,
              ),
            ),
            const SizedBox(height: AppStyles.paddingSmall),
            ..._allApiKeys.map((key) {
              final provider = key['provider'] ?? '';
              final maskedKey = _maskApiKey(key['api_key'] ?? '');
              final isActive = provider == _activeProvider;

              return Container(
                margin: const EdgeInsets.only(bottom: AppStyles.paddingSmall),
                padding: const EdgeInsets.all(AppStyles.paddingSmall),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppStyles.accentColor.withValues(alpha: 0.1)
                      : AppStyles.surfaceColor,
                  borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                  border: Border.all(
                    color: isActive
                        ? AppStyles.accentColor
                        : AppStyles.borderColor,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getProviderDisplayName(provider),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? AppStyles.accentColor
                                      : AppStyles.textPrimary,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: AppStyles.accentColor,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '(активен)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppStyles.accentColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            maskedKey,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppStyles.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppStyles.errorColor,
                      tooltip: 'Удалить ключ',
                      onPressed: () => _handleDeleteApiKey(provider),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: AppStyles.padding),

          // Кнопка для показа/скрытия формы добавления
          ElevatedButton.icon(
            onPressed: _isAddingApiKey
                ? null
                : () {
                    setState(() {
                      _showApiKeyForm = !_showApiKeyForm;
                      if (!_showApiKeyForm) {
                        _apiKeyController.clear();
                        _apiKeyError = null;
                      }
                    });
                  },
            icon: Icon(_showApiKeyForm ? Icons.close : Icons.add),
            label: Text(_showApiKeyForm ? 'Отменить' : 'Добавить API ключ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.accentColor,
              foregroundColor: Colors.white,
            ),
          ),
          // Форма для обновления API ключа
          if (_showApiKeyForm) ...[
            const SizedBox(height: AppStyles.padding),
            Form(
              key: _apiKeyFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'Новый API ключ',
                      hintText: 'Введите новый API ключ',
                      prefixIcon: const Icon(Icons.vpn_key),
                      errorText: _apiKeyError,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppStyles.borderRadius),
                      ),
                    ),
                    obscureText: true,
                    enabled: !_isAddingApiKey,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите API ключ';
                      }
                      final trimmed = value.trim();
                      if (!trimmed.startsWith('sk-or-')) {
                        return 'Ключ должен начинаться с "sk-or-v1-" (OpenRouter) или "sk-or-vv-" (VSEGPT)';
                      }
                      if (!trimmed.startsWith('sk-or-v1-') &&
                          !trimmed.startsWith('sk-or-vv-')) {
                        return 'Неверный формат ключа. Используйте "sk-or-v1-..." или "sk-or-vv-..."';
                      }
                      if (trimmed.length < 20) {
                        return 'API ключ слишком короткий. Проверьте правильность ввода';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppStyles.paddingSmall),
                  if (_isAddingApiKey)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppStyles.paddingSmall),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: AppStyles.paddingSmall),
                            Text(
                              'Добавление API ключа...',
                              style: TextStyle(
                                color: AppStyles.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _handleApiKeyUpdate,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.successColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
