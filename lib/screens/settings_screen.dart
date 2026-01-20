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
  String? _provider;
  String _maskedApiKey = '';
  String? _errorMessage;

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

  /// Получает читаемое название провайдера.
  String _getProviderDisplayName(String? provider) {
    switch (provider) {
      case 'openrouter':
        return 'OpenRouter';
      case 'vsegpt':
        return 'VSEGPT';
      case null:
        return 'Не установлен';
      default:
        return provider;
    }
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
          Container(
            padding: const EdgeInsets.all(AppStyles.paddingSmall),
            decoration: BoxDecoration(
              color: AppStyles.surfaceColor,
              borderRadius: BorderRadius.circular(AppStyles.borderRadius),
              border: Border.all(
                color: _getProviderColor(_provider).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppStyles.paddingSmall,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getProviderColor(_provider).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                  ),
                  child: Text(
                    _getProviderDisplayName(_provider),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getProviderColor(_provider),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
