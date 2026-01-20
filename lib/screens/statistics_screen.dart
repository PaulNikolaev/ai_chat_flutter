import 'package:flutter/material.dart';

import '../api/openrouter_client.dart';
import '../ui/styles.dart';
import '../utils/analytics.dart';
import '../utils/monitor.dart';
import '../utils/platform.dart';

/// Страница статистики использования моделей и метрик производительности.
///
/// Показывает:
/// - Статистику использования моделей (количество запросов, токены)
/// - Баланс аккаунта с автообновлением
/// - Метрики производительности (память, время работы)
class StatisticsScreen extends StatefulWidget {
  /// API клиент для получения баланса.
  final OpenRouterClient? apiClient;

  /// Экземпляр аналитики для получения статистики.
  final Analytics? analytics;

  /// Экземпляр мониторинга производительности.
  final PerformanceMonitor? performanceMonitor;

  const StatisticsScreen({
    super.key,
    this.apiClient,
    this.analytics,
    this.performanceMonitor,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
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

  /// Загружает все данные для страницы.
  Future<void> _loadData() async {
    await Future.wait([
      _loadBalance(),
      _loadStatistics(),
      _loadPerformanceMetrics(),
    ]);
  }

  /// Загружает баланс аккаунта.
  Future<void> _loadBalance({bool forceRefresh = false}) async {
    final apiClient = widget.apiClient;
    if (apiClient == null) {
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
      final balance = await apiClient.getBalance(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _balance = balance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
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
      final analytics = widget.analytics ?? Analytics();
      final success = await analytics.clear();
      if (success) {
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
    } catch (e) {
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
      if (mounted) {
        setState(() {
          _modelStatistics = statistics;
          _isLoadingStatistics = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('StatisticsScreen: Error loading statistics: $e');
      debugPrint('StatisticsScreen: Stack trace: $stackTrace');
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
    final padding = AppStyles.getPadding(context);
    final maxContentWidth = AppStyles.getMaxContentWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.analytics, size: 24),
            SizedBox(width: 8),
            Text('Статистика'),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Очистить',
            onPressed: _clearData,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth ?? double.infinity,
            ),
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
      ),
    );
  }

  /// Строит секцию баланса.
  Widget _buildBalanceSection() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppStyles.accentColor,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Баланс аккаунта',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_isLoadingBalance)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          Text(
            _balance,
            style: AppStyles.balanceTextStyle.copyWith(fontSize: 28),
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
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.pie_chart,
                    color: AppStyles.accentColor,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Статистика использования моделей',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_isLoadingStatistics)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          if (_modelStatistics.isEmpty && !_isLoadingStatistics)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppStyles.padding),
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 48,
                      color: AppStyles.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Статистика недоступна',
                      style: TextStyle(color: AppStyles.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Используйте чат для накопления статистики',
                      style: TextStyle(
                        color: AppStyles.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._modelStatistics.entries.map((entry) {
              final model = entry.key;
              final stats = entry.value;
              final count = stats['count'] ?? 0;
              final tokens = stats['tokens'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppStyles.paddingSmall),
                child: Container(
                  padding: const EdgeInsets.all(AppStyles.paddingSmall),
                  decoration: BoxDecoration(
                    color: AppStyles.surfaceColor,
                    borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                    border: Border.all(color: AppStyles.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model,
                              style: const TextStyle(
                                color: AppStyles.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.borderColor),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.speed,
                    color: AppStyles.accentColor,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Метрики производительности',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_isLoadingMetrics)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          if (memoryMb != null)
            _buildMetricRow(
              'Использование памяти',
              _formatMemory(memoryMb),
              Icons.memory,
            ),
          if (uptimeSeconds != null)
            _buildMetricRow(
              'Время работы',
              _formatUptime(uptimeSeconds),
              Icons.access_time,
            ),
        ],
      ),
    );
  }

  /// Строит строку метрики.
  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyles.paddingSmall),
      child: Container(
        padding: const EdgeInsets.all(AppStyles.paddingSmall),
        decoration: BoxDecoration(
          color: AppStyles.surfaceColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: AppStyles.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppStyles.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
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
      ),
    );
  }
}
