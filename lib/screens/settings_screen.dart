import 'package:flutter/material.dart';

import '../auth/auth_manager.dart';
import '../ui/styles.dart';

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
  bool _isLoading = true;
  bool _isUpdatingProvider = false;
  String? _provider;
  String _maskedApiKey = '';
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Загружает текущие настройки из хранилища.
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Получаем провайдера
      final provider = await _authManager.getStoredProvider();
      
      // Получаем API ключ и маскируем его
      final apiKey = await _authManager.getStoredApiKey();
      final maskedKey = _maskApiKey(apiKey);

      if (mounted) {
        setState(() {
          _provider = provider;
          _maskedApiKey = maskedKey;
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

  /// Обрабатывает смену провайдера.
  Future<void> _handleProviderChange(String? newProvider) async {
    if (newProvider == null || newProvider == _provider) {
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
            _provider = newProvider;
            _successMessage = result.message;
            _isUpdatingProvider = false;
          });
          
          // Показываем сообщение об успехе
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppStyles.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
          
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

  /// Получает иконку провайдера.
  IconData _getProviderIcon(String? provider) {
    switch (provider) {
      case 'openrouter':
        return Icons.cloud;
      case 'vsegpt':
        return Icons.router;
      default:
        return Icons.help_outline;
    }
  }

  /// Получает цвет для провайдера.
  Color _getProviderColor(String? provider) {
    switch (provider) {
      case 'openrouter':
        return AppStyles.accentColor;
      case 'vsegpt':
        return AppStyles.successColor;
      default:
        return AppStyles.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppStyles.getPadding(context);
    final maxContentWidth = AppStyles.getMaxContentWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
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
                          // Секция информации о провайдере
                          _buildProviderSection(),
                          const SizedBox(height: AppStyles.padding),

                          // Секция API ключа
                          _buildApiKeySection(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  /// Строит секцию с информацией о провайдере.
  Widget _buildProviderSection() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getProviderIcon(_provider),
                color: _getProviderColor(_provider),
                size: 24,
              ),
              const SizedBox(width: AppStyles.paddingSmall),
              const Text(
                'Провайдер',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          // Переключатель провайдера
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'openrouter',
                label: Text('OpenRouter'),
                icon: Icon(Icons.cloud),
              ),
              ButtonSegment<String>(
                value: 'vsegpt',
                label: Text('VSEGPT'),
                icon: Icon(Icons.router),
              ),
            ],
            selected: _provider != null ? {_provider!} : <String>{},
            onSelectionChanged: _isUpdatingProvider
                ? null
                : (Set<String> newSelection) {
                    if (newSelection.isNotEmpty) {
                      _handleProviderChange(newSelection.first);
                    }
                  },
            selectedIcon: const Icon(Icons.check),
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
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.vpn_key,
                color: AppStyles.accentColor,
                size: 24,
              ),
              SizedBox(width: AppStyles.paddingSmall),
              Text(
                'API Ключ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          Container(
            padding: const EdgeInsets.all(AppStyles.paddingSmall),
            decoration: BoxDecoration(
              color: AppStyles.surfaceColor,
              borderRadius: BorderRadius.circular(AppStyles.borderRadius),
              border: Border.all(color: AppStyles.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _maskedApiKey,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: AppStyles.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_maskedApiKey != 'Не установлен') ...[
                  const SizedBox(width: AppStyles.paddingSmall),
                  const Icon(
                    Icons.visibility_off,
                    size: 18,
                    color: AppStyles.textSecondary,
                  ),
                ],
              ],
            ),
          ),
          if (_maskedApiKey == 'Не установлен')
            const Padding(
              padding: EdgeInsets.only(top: AppStyles.paddingSmall),
              child: Text(
                'API ключ не найден. Пожалуйста, выполните вход в приложение.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
