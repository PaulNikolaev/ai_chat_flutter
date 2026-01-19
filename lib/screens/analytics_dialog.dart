import 'package:flutter/material.dart';

import '../api/openrouter_client.dart';
import '../ui/styles.dart';
import '../utils/analytics.dart';
import '../utils/monitor.dart';
import '../utils/platform.dart';

/// Диалог отображения аналитики использования моделей и метрик производительности.
///
/// Показывает:
/// - Статистику использования моделей (количество запросов, токены)
/// - Баланс аккаунта с автообновлением
/// - Метрики производительности (память, время работы)
class AnalyticsDialog extends StatefulWidget {
  /// API клиент для получения баланса.
  final OpenRouterClient? apiClient;

  /// Экземпляр аналитики для получения статистики.
  final Analytics? analytics;

  /// Экземпляр мониторинга производительности.
  final PerformanceMonitor? performanceMonitor;

  const AnalyticsDialog({
    super.key,
    this.apiClient,
    this.analytics,
    this.performanceMonitor,
  });

  @override
  State<AnalyticsDialog> createState() => _AnalyticsDialogState();
}

class _AnalyticsDialogState extends State<AnalyticsDialog> {
  String _balance = 'Загрузка...';
  bool _isLoadingBalance = false;
  Map<String, Map<String, int>> _modelStatistics = {};
  bool _isLoadingStatistics = false;
  Map<String, dynamic>? _performanceMetrics;
  bool _isLoadingMetrics = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Автообновление баланса каждые 30 секунд
    _startBalanceAutoRefresh();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Загружает все данные для диалога.
  Future<void> _loadData() async {
    await Future.wait([
      _loadBalance(),
      _loadStatistics(),
      _loadPerformanceMetrics(),
    ]);
  }

  /// Загружает баланс аккаунта.
  Future<void> _loadBalance({bool forceRefresh = false}) async {
    print('[ANALYTICS] Loading balance (forceRefresh: $forceRefresh)');
    final apiClient = widget.apiClient;
    if (apiClient == null) {
      print('[ANALYTICS] ❌ API client is null');
      setState(() {
        _balance = 'Недоступно';
        _isLoadingBalance = false;
      });
      return;
    }

    setState(() {
      _isLoadingBalance = true;
    });

    try {
      print('[ANALYTICS] Calling getBalance...');
      final balance = await apiClient.getBalance(forceRefresh: forceRefresh);
      print('[ANALYTICS] ✅ Balance loaded: $balance');
      if (mounted) {
        setState(() {
          _balance = balance;
          _isLoadingBalance = false;
        });
      }
    } catch (e, stackTrace) {
      print('[ANALYTICS] ❌ Error loading balance: $e');
      print('[ANALYTICS] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _balance = 'Ошибка';
          _isLoadingBalance = false;
        });
      }
    }
  }

  /// Очищает все данные аналитики.
  Future<void> _clearData() async {
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppStyles.cardColor,
        title: const Text(
          'Очистить аналитику?',
          style: TextStyle(color: AppStyles.textPrimary),
        ),
        content: const Text(
          'Все данные аналитики будут удалены. Это действие нельзя отменить.',
          style: TextStyle(color: AppStyles.textSecondary),
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
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      print('[ANALYTICS] Clearing analytics data...');
      final analytics = widget.analytics;
      if (analytics != null) {
        final success = await analytics.clear();
        if (success) {
          print('[ANALYTICS] ✅ Analytics data cleared successfully');
          // Показываем сообщение об успехе
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Аналитика очищена'),
                backgroundColor: AppStyles.successColor,
                duration: Duration(seconds: 2),
              ),
            );
            // Перезагружаем данные
            _loadData();
          }
        } else {
          print('[ANALYTICS] ❌ Failed to clear analytics data');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ошибка при очистке аналитики'),
                backgroundColor: AppStyles.errorColor,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        print('[ANALYTICS] ❌ Analytics instance is null');
      }
    } catch (e, stackTrace) {
      print('[ANALYTICS] ❌ Error clearing analytics: $e');
      print('[ANALYTICS] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppStyles.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Загружает статистику использования моделей.
  Future<void> _loadStatistics() async {
    final analytics = widget.analytics ?? Analytics();
    
    setState(() {
      _isLoadingStatistics = true;
    });

    try {
      final statistics = await analytics.getModelStatistics();
      // Отладочная информация
      debugPrint('AnalyticsDialog: Loaded statistics: ${statistics.length} models');
      if (mounted) {
        setState(() {
          _modelStatistics = statistics;
          _isLoadingStatistics = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('AnalyticsDialog: Error loading statistics: $e');
      debugPrint('AnalyticsDialog: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _modelStatistics = {};
          _isLoadingStatistics = false;
        });
      }
    }
  }

  /// Загружает метрики производительности.
  Future<void> _loadPerformanceMetrics() async {
    final monitor = widget.performanceMonitor ?? PerformanceMonitor();
    
    setState(() {
      _isLoadingMetrics = true;
    });

    try {
      final metrics = monitor.getMetricsSummary();
      if (mounted) {
        setState(() {
          _performanceMetrics = metrics;
          _isLoadingMetrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _performanceMetrics = null;
          _isLoadingMetrics = false;
        });
      }
    }
  }

  /// Запускает автообновление баланса каждые 30 секунд.
  void _startBalanceAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && widget.apiClient != null) {
        _loadBalance(forceRefresh: true);
        _startBalanceAutoRefresh(); // Рекурсивно планируем следующее обновление
      }
    });
  }

  /// Форматирует количество токенов для отображения.
  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(2)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(2)}K';
    }
    return tokens.toString();
  }

  /// Форматирует время работы для отображения.
  String _formatUptime(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  /// Форматирует память для отображения.
  String _formatMemory(double? mb) {
    if (mb == null) return 'N/A';
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformUtils.isMobile();

    return Dialog(
      backgroundColor: AppStyles.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusLarge),
      ),
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(AppStyles.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Аналитика',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppStyles.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppStyles.padding),
            
            // Скроллируемая область с контентом
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Баланс
                    _buildBalanceSection(),
                    const SizedBox(height: AppStyles.padding),
                    
                    // Статистика моделей
                    _buildModelStatisticsSection(),
                    const SizedBox(height: AppStyles.padding),
                    
                    // Метрики производительности
                    if (_performanceMetrics != null) ...[
                      _buildPerformanceMetricsSection(),
                      const SizedBox(height: AppStyles.padding),
                    ],
                  ],
                ),
              ),
            ),
            
            // Кнопки управления
            const SizedBox(height: AppStyles.paddingSmall),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Обновить'),
                    style: AppStyles.getButtonStyle(),
                  ),
                ),
                const SizedBox(width: AppStyles.paddingSmall),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearData,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Очистить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppStyles.padding,
                        vertical: AppStyles.paddingSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Строит секцию баланса.
  Widget _buildBalanceSection() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.surfaceColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Баланс аккаунта',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
              if (_isLoadingBalance)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppStyles.paddingSmall),
          Text(
            _balance,
            style: AppStyles.balanceTextStyle.copyWith(fontSize: 24),
          ),
        ],
      ),
    );
  }

  /// Строит секцию статистики моделей.
  Widget _buildModelStatisticsSection() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.surfaceColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Статистика использования моделей',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
              if (_isLoadingStatistics)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppStyles.paddingSmall),
          if (_modelStatistics.isEmpty && !_isLoadingStatistics)
            const Text(
              'Статистика недоступна',
              style: TextStyle(color: AppStyles.textSecondary),
            )
          else
            ..._modelStatistics.entries.map((entry) {
              final model = entry.key;
              final stats = entry.value;
              final count = stats['count'] ?? 0;
              final tokens = stats['tokens'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppStyles.paddingSmall),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        model,
                        style: const TextStyle(
                          color: AppStyles.textPrimary,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppStyles.paddingSmall),
                    Text(
                      '$count запросов',
                      style: const TextStyle(
                        color: AppStyles.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: AppStyles.paddingSmall),
                    Text(
                      '${_formatTokens(tokens)} токенов',
                      style: const TextStyle(
                        color: AppStyles.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Строит секцию метрик производительности.
  Widget _buildPerformanceMetricsSection() {
    final metrics = _performanceMetrics;
    if (metrics == null) return const SizedBox.shrink();

    final memoryMb = metrics['memoryRssMb'] as double?;
    final uptimeSeconds = metrics['uptimeSeconds'] as int?;

    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.surfaceColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Метрики производительности',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
              if (_isLoadingMetrics)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppStyles.paddingSmall),
          if (memoryMb != null)
            _buildMetricRow('Использование памяти', _formatMemory(memoryMb)),
          if (uptimeSeconds != null)
            _buildMetricRow('Время работы', _formatUptime(uptimeSeconds)),
        ],
      ),
    );
  }

  /// Строит строку метрики.
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyles.paddingSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppStyles.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppStyles.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
