import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ai_chat/api/api.dart';
import 'package:ai_chat/models/models.dart';
import 'package:ai_chat/ui/ui.dart';
import 'package:ai_chat/utils/utils.dart';

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

  /// Callback при нажатии кнопки выхода.
  final VoidCallback? onLogout;

  const StatisticsScreen({
    super.key,
    this.apiClient,
    this.analytics,
    this.performanceMonitor,
    this.onLogout,
  });

  @override
  State<StatisticsScreen> createState() => StatisticsScreenState();
}

/// Тип сортировки статистики.
enum SortType {
  model,
  count,
  tokens,
}

/// Направление сортировки.
enum SortDirection {
  ascending,
  descending,
}

/// Кэшированные данные статистики.
class _CachedStatistics {
  final Map<String, Map<String, int>> statistics;
  final int totalRequests;
  final int totalTokens;
  final DateTime timestamp;
  
  _CachedStatistics({
    required this.statistics,
    required this.totalRequests,
    required this.totalTokens,
    required this.timestamp,
  });
  
  /// Проверяет, актуален ли кэш (не старше 5 секунд).
  bool get isValid {
    return DateTime.now().difference(timestamp).inSeconds < 5;
  }
}

class StatisticsScreenState extends State<StatisticsScreen> {
  String _balance = 'Загрузка...';
  bool _isLoadingBalance = false;
  Map<String, Map<String, int>> _modelStatistics = {};
  bool _isLoadingStatistics = false;
  Map<String, dynamic>? _performanceMetrics;
  bool _isLoadingMetrics = false;
  
  // Фильтры и сортировка
  String? _selectedModelFilter;
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  SortType _sortType = SortType.tokens;
  SortDirection _sortDirection = SortDirection.descending;
  
  // Общая статистика
  int _totalRequests = 0;
  int _totalTokens = 0;
  
  // Кэш для статистики (ключ - строка фильтров, значение - кэшированные данные)
  final Map<String, _CachedStatistics> _statisticsCache = {};
  
  // Флаг для предотвращения параллельных загрузок
  bool _isLoadingStatisticsInProgress = false;
  
  // Таймер для автообновления баланса
  Timer? _balanceRefreshTimer;
  
  // Флаг для отслеживания первого вызова didChangeDependencies
  bool _isFirstBuild = true;
  
  // Время последнего обновления статистики
  DateTime? _lastStatisticsUpdate;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Автообновление баланса каждые 30 секунд
    _startBalanceAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем данные при каждом входе на страницу (кроме первого раза)
    if (!_isFirstBuild) {
      // Обновляем статистику только если прошло больше 1 секунды с последнего обновления
      final now = DateTime.now();
      if (_lastStatisticsUpdate == null || 
          now.difference(_lastStatisticsUpdate!).inSeconds > 1) {
        _lastStatisticsUpdate = now;
        // Принудительно обновляем статистику при входе на страницу
        _loadStatistics(forceRefresh: true);
        _loadPerformanceMetrics();
      }
    } else {
      _isFirstBuild = false;
      _lastStatisticsUpdate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _balanceRefreshTimer?.cancel();
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
          // Перезагружаем данные с принудительным обновлением
          _loadStatistics(forceRefresh: true);
          _loadPerformanceMetrics();
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

  /// Генерирует ключ кэша на основе текущих фильтров.
  String _getCacheKey() {
    final modelKey = _selectedModelFilter ?? 'all';
    final startKey = _startDateFilter?.toIso8601String() ?? 'none';
    final endKey = _endDateFilter?.toIso8601String() ?? 'none';
    return '$modelKey|$startKey|$endKey';
  }

  /// Загружает статистику использования моделей с оптимизированными запросами и кэшированием.
  Future<void> _loadStatistics({bool forceRefresh = false}) async {
    // Предотвращаем параллельные загрузки
    if (_isLoadingStatisticsInProgress && !forceRefresh) {
      return;
    }
    
    // Проверяем кэш
    if (!forceRefresh) {
      final cacheKey = _getCacheKey();
      final cached = _statisticsCache[cacheKey];
      if (cached != null && cached.isValid) {
        // Используем кэшированные данные
        _applyCachedStatistics(cached);
        return;
      }
    }
    
    _isLoadingStatisticsInProgress = true;
    final analytics = widget.analytics ?? Analytics();
    
    if (mounted) {
      setState(() {
        _isLoadingStatistics = true;
      });
    }

    try {
      // Используем оптимизированный метод с фильтрацией на уровне SQL
      // getModelStatisticsFiltered уже возвращает агрегированные данные с SUM(tokens_used)
      final statisticsFuture = analytics.getModelStatisticsFiltered(
        model: _selectedModelFilter,
        startDate: _startDateFilter,
        endDate: _endDateFilter,
      );
      
      // Параллельно получаем общую статистику (только COUNT, без загрузки всех записей)
      final totalCountFuture = analytics.getHistoryCount(
        model: _selectedModelFilter,
        startDate: _startDateFilter,
        endDate: _endDateFilter,
      );
      
      // Получаем SUM токенов напрямую из БД через оптимизированный запрос
      // Вместо загрузки 10000 записей, используем SQL SUM
      final totalTokensFuture = analytics.getTotalTokens(
        model: _selectedModelFilter,
        startDate: _startDateFilter,
        endDate: _endDateFilter,
      );
      
      // Ждем выполнения всех запросов параллельно
      final results = await Future.wait([
        statisticsFuture,
        totalCountFuture,
        totalTokensFuture,
      ]);
      
      final statistics = results[0] as Map<String, Map<String, int>>;
      final totalCount = results[1] as int;
      final totalTokens = results[2] as int;
      
      // Сортируем статистику
      final sortedEntries = statistics.entries.toList();
      sortedEntries.sort((a, b) {
        int comparison = 0;
        switch (_sortType) {
          case SortType.model:
            comparison = a.key.compareTo(b.key);
            break;
          case SortType.count:
            comparison = (a.value['count'] ?? 0).compareTo(b.value['count'] ?? 0);
            break;
          case SortType.tokens:
            comparison = (a.value['tokens'] ?? 0).compareTo(b.value['tokens'] ?? 0);
            break;
        }
        return _sortDirection == SortDirection.ascending ? comparison : -comparison;
      });
      
      final sortedStatistics = Map<String, Map<String, int>>.fromEntries(sortedEntries);
      
      // Сохраняем в кэш
      final cacheKey = _getCacheKey();
      _statisticsCache[cacheKey] = _CachedStatistics(
        statistics: sortedStatistics,
        totalRequests: totalCount,
        totalTokens: totalTokens,
        timestamp: DateTime.now(),
      );
      
      // Очищаем старый кэш (оставляем только последние 5 записей)
      if (_statisticsCache.length > 5) {
        final oldestKey = _statisticsCache.keys.first;
        _statisticsCache.remove(oldestKey);
      }
      
      if (mounted) {
        setState(() {
          _modelStatistics = sortedStatistics;
          _totalRequests = totalCount;
          _totalTokens = totalTokens;
          _isLoadingStatistics = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('StatisticsScreen: Error loading statistics: $e');
      debugPrint('StatisticsScreen: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _modelStatistics = {};
          _totalRequests = 0;
          _totalTokens = 0;
          _isLoadingStatistics = false;
        });
      }
    } finally {
      _isLoadingStatisticsInProgress = false;
    }
  }
  
  /// Применяет кэшированные данные статистики.
  void _applyCachedStatistics(_CachedStatistics cached) {
    if (mounted) {
      setState(() {
        _modelStatistics = cached.statistics;
        _totalRequests = cached.totalRequests;
        _totalTokens = cached.totalTokens;
        _isLoadingStatistics = false;
      });
    }
  }
  
  /// Публичный метод для принудительного обновления данных при входе на страницу.
  /// Вызывается из HomeScreen при переключении вкладок.
  void refreshData() {
    // Обновляем данные принудительно
    _loadStatistics(forceRefresh: true);
    _loadPerformanceMetrics();
    _lastStatisticsUpdate = DateTime.now();
  }
  
  /// Применяет фильтры и перезагружает статистику.
  void _applyFilters() {
    _loadStatistics(forceRefresh: true);
  }
  
  /// Сбрасывает все фильтры.
  void _resetFilters() {
    setState(() {
      _selectedModelFilter = null;
      _startDateFilter = null;
      _endDateFilter = null;
      _sortType = SortType.tokens;
      _sortDirection = SortDirection.descending;
    });
    _loadStatistics(forceRefresh: true);
  }
  
  /// Изменяет тип сортировки.
  void _changeSortType(SortType type) {
    setState(() {
      if (_sortType == type) {
        // Меняем направление, если тот же тип
        _sortDirection = _sortDirection == SortDirection.ascending
            ? SortDirection.descending
            : SortDirection.ascending;
      } else {
        _sortType = type;
        _sortDirection = SortDirection.descending;
      }
    });
    // Сортировка применяется в памяти, перезагрузка не нужна
    // Но обновляем UI для применения новой сортировки
    _applySorting();
  }
  
  /// Применяет сортировку к текущим данным статистики.
  void _applySorting() {
    final sortedEntries = _modelStatistics.entries.toList();
    sortedEntries.sort((a, b) {
      int comparison = 0;
      switch (_sortType) {
        case SortType.model:
          comparison = a.key.compareTo(b.key);
          break;
        case SortType.count:
          comparison = (a.value['count'] ?? 0).compareTo(b.value['count'] ?? 0);
          break;
        case SortType.tokens:
          comparison = (a.value['tokens'] ?? 0).compareTo(b.value['tokens'] ?? 0);
          break;
      }
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });
    
    final sortedStatistics = Map<String, Map<String, int>>.fromEntries(sortedEntries);
    
    if (mounted) {
      setState(() {
        _modelStatistics = sortedStatistics;
      });
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
    _balanceRefreshTimer?.cancel();
    _balanceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && widget.apiClient != null) {
        _loadBalance(forceRefresh: true);
      } else {
        timer.cancel();
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
            icon: const Icon(Icons.download),
            tooltip: 'Экспорт статистики',
            onPressed: _exportStatistics,
          ),
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _isLoadingBalance || _isLoadingStatistics || _isLoadingMetrics
          ? const LoadingWithMessage(
              message: 'Загрузка статистики...',
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
                      // Баланс
                      _buildBalanceSection(),
                      const SizedBox(height: AppStyles.padding),
                      
                      // Общая статистика
                      _buildTotalStatisticsSection(),
                      const SizedBox(height: AppStyles.padding),
                      
                      // Фильтры и сортировка
                      _buildFiltersSection(),
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

  /// Строит секцию с общей статистикой.
  Widget _buildTotalStatisticsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = PlatformUtils.getScreenSize(context);
        final isSmall = screenSize == 'small';
        
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
          const Row(
            children: [
              Icon(
                Icons.dashboard,
                color: AppStyles.accentColor,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Общая статистика',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          isSmall
              ? Column(
                  children: [
                    _buildStatCard(
                      icon: Icons.message,
                      label: 'Всего запросов',
                      value: _totalRequests.toString(),
                      color: AppStyles.accentColor,
                    ),
                    const SizedBox(height: AppStyles.paddingSmall),
                    _buildStatCard(
                      icon: Icons.token,
                      label: 'Всего токенов',
                      value: _formatTokens(_totalTokens),
                      color: AppStyles.successColor,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.message,
                        label: 'Всего запросов',
                        value: _totalRequests.toString(),
                        color: AppStyles.accentColor,
                      ),
                    ),
                    const SizedBox(width: AppStyles.padding),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.token,
                        label: 'Всего токенов',
                        value: _formatTokens(_totalTokens),
                        color: AppStyles.successColor,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
      },
    );
  }

  /// Строит карточку со статистикой.
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.surfaceColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppStyles.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Строит секцию фильтров и сортировки.
  Widget _buildFiltersSection() {
    final analytics = widget.analytics ?? Analytics();
    
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
          const Row(
            children: [
              Icon(
                Icons.filter_list,
                color: AppStyles.accentColor,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Фильтры и сортировка',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenSize = PlatformUtils.getScreenSize(context);
              final isSmall = screenSize == 'small';
              
              // Фильтр по модели
              final modelFilter = FutureBuilder<Map<String, Map<String, int>>>(
                future: analytics.getModelStatistics(),
                builder: (context, snapshot) {
              final allModels = snapshot.data?.keys.toList() ?? [];
              return DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Модель',
                  prefixIcon: const Icon(Icons.model_training),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                  ),
                ),
                isExpanded: true,
                initialValue: _selectedModelFilter,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Все модели', overflow: TextOverflow.ellipsis),
                  ),
                  ...allModels.map((model) => DropdownMenuItem<String>(
                    value: model,
                    child: Text(model, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedModelFilter = value;
                  });
                  _applyFilters();
                },
              );
                },
              );
              
              // Фильтр по дате
              final dateFilters = Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDateFilter ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _startDateFilter = date;
                          });
                          _applyFilters();
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Дата начала',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                          ),
                        ),
                        child: Text(
                          _startDateFilter != null
                              ? DateFormat('yyyy-MM-dd').format(_startDateFilter!)
                              : 'Не выбрана',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppStyles.paddingSmall),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDateFilter ?? DateTime.now(),
                          firstDate: _startDateFilter ?? DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _endDateFilter = date;
                          });
                          _applyFilters();
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Дата окончания',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                          ),
                        ),
                        child: Text(
                          _endDateFilter != null
                              ? DateFormat('yyyy-MM-dd').format(_endDateFilter!)
                              : 'Не выбрана',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              );
              
              // Сортировка
              final sortControls = Row(
                children: [
                  if (!isSmall) ...[
                    const Text(
                      'Сортировать по:',
                      style: TextStyle(
                        color: AppStyles.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: AppStyles.paddingSmall),
                  ],
                  Expanded(
                    child: SegmentedButton<SortType>(
                      segments: const [
                        ButtonSegment<SortType>(
                          value: SortType.model,
                          label: Text('Модель'),
                          icon: Icon(Icons.sort_by_alpha, size: 16),
                        ),
                        ButtonSegment<SortType>(
                          value: SortType.count,
                          label: Text('Запросы'),
                          icon: Icon(Icons.numbers, size: 16),
                        ),
                        ButtonSegment<SortType>(
                          value: SortType.tokens,
                          label: Text('Токены'),
                          icon: Icon(Icons.token, size: 16),
                        ),
                      ],
                      selected: {_sortType},
                      onSelectionChanged: (Set<SortType> selection) {
                        if (selection.isNotEmpty) {
                          _changeSortType(selection.first);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppStyles.paddingSmall),
                  IconButton(
                    icon: Icon(
                      _sortDirection == SortDirection.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    tooltip: _sortDirection == SortDirection.ascending
                        ? 'По возрастанию'
                        : 'По убыванию',
                    onPressed: () {
                      setState(() {
                        _sortDirection = _sortDirection == SortDirection.ascending
                            ? SortDirection.descending
                            : SortDirection.ascending;
                      });
                      _applySorting();
                    },
                  ),
                ],
              );
              
              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    modelFilter,
                    const SizedBox(height: AppStyles.paddingSmall),
                    dateFilters,
                    const SizedBox(height: AppStyles.paddingSmall),
                    sortControls,
                  ],
                );
              } else {
                // Для планшетов и больших экранов размещаем в две колонки
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: modelFilter,
                        ),
                        const SizedBox(width: AppStyles.padding),
                        Expanded(
                          flex: 3,
                          child: dateFilters,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.paddingSmall),
                    sortControls,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: AppStyles.paddingSmall),
          // Кнопка сброса фильтров
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Сбросить фильтры'),
              ),
            ],
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
            ..._buildModelStatisticsList(),
        ],
      ),
    );
  }

  /// Строит список статистики по моделям с улучшенным отображением.
  List<Widget> _buildModelStatisticsList() {
    if (_modelStatistics.isEmpty) {
      return [];
    }
    
    final isMobile = PlatformUtils.isMobile();
    final totalTokens = _totalTokens > 0 ? _totalTokens : 1; // Избегаем деления на ноль
    
    return _modelStatistics.entries.map((entry) {
      final model = entry.key;
      final stats = entry.value;
      final count = stats['count'] ?? 0;
      final tokens = stats['tokens'] ?? 0;
      final percentage = (tokens / totalTokens * 100).clamp(0.0, 100.0);

      return Padding(
        padding: const EdgeInsets.only(bottom: AppStyles.paddingSmall),
        child: Container(
          padding: const EdgeInsets.all(AppStyles.padding),
          decoration: BoxDecoration(
            color: AppStyles.surfaceColor,
            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
            border: Border.all(
              color: AppStyles.borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок с названием модели
              Row(
                children: [
                  const Icon(
                    Icons.smart_toy,
                    size: 20,
                    color: AppStyles.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model,
                      style: const TextStyle(
                        color: AppStyles.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppStyles.accentColor,
                    ),
                    tooltip: 'Детальная статистика',
                    onPressed: () => _showModelDetailsDialog(context, model),
                  ),
                ],
              ),
              const SizedBox(height: AppStyles.paddingSmall),
              // Индикатор прогресса по токенам
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}% от общего использования',
                        style: const TextStyle(
                          color: AppStyles.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatTokens(tokens),
                        style: const TextStyle(
                          color: AppStyles.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 6,
                      backgroundColor: AppStyles.borderColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppStyles.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppStyles.paddingSmall),
              // Статистика в карточках
              isMobile
                  ? Column(
                      children: [
                        _buildModelStatItem(
                          icon: Icons.message,
                          label: 'Запросов',
                          value: count.toString(),
                        ),
                        const SizedBox(height: 8),
                        _buildModelStatItem(
                          icon: Icons.token,
                          label: 'Токенов',
                          value: _formatTokens(tokens),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildModelStatItem(
                            icon: Icons.message,
                            label: 'Запросов',
                            value: count.toString(),
                          ),
                        ),
                        const SizedBox(width: AppStyles.paddingSmall),
                        Expanded(
                          child: _buildModelStatItem(
                            icon: Icons.token,
                            label: 'Токенов',
                            value: _formatTokens(tokens),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: AppStyles.paddingSmall),
                          Expanded(
                            child: _buildModelStatItem(
                              icon: Icons.trending_up,
                              label: 'Среднее на запрос',
                              value: _formatTokens((tokens / count).round()),
                            ),
                          ),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      );
    }).toList();
  }

  /// Строит элемент статистики для модели.
  Widget _buildModelStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.paddingSmall,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius / 2),
        border: Border.all(
          color: AppStyles.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppStyles.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppStyles.textSecondary,
                    fontSize: 11,
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
          ),
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

  /// Показывает детальный диалог со статистикой по конкретной модели.
  Future<void> _showModelDetailsDialog(BuildContext context, String model) async {
    final analytics = widget.analytics ?? Analytics();
    
    // Показываем индикатор загрузки
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Загружаем историю для этой модели с применением фильтров даты
      final records = await analytics.getHistoryFiltered(
        model: model,
        startDate: _startDateFilter,
        endDate: _endDateFilter,
        limit: 10000, // Ограничиваем для производительности
      );
      
      // Закрываем индикатор загрузки
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      if (records.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нет данных для этой модели'),
            ),
          );
        }
        return;
      }
    
    // Рассчитываем статистику
    final totalRequests = records.length;
    final totalTokens = records.fold<int>(0, (sum, record) => sum + record.tokensUsed);
    final avgTokens = totalTokens / totalRequests;
    final avgResponseTime = records.fold<double>(0, (sum, record) => sum + record.responseTime) / totalRequests;
    final avgMessageLength = records.fold<int>(0, (sum, record) => sum + record.messageLength) / totalRequests;
    
    final minResponseTime = records.map((r) => r.responseTime).reduce((a, b) => a < b ? a : b);
    final maxResponseTime = records.map((r) => r.responseTime).reduce((a, b) => a > b ? a : b);
    
    final minTokens = records.map((r) => r.tokensUsed).reduce((a, b) => a < b ? a : b);
    final maxTokens = records.map((r) => r.tokensUsed).reduce((a, b) => a > b ? a : b);
    
    final firstUse = records.first.timestamp;
    final lastUse = records.last.timestamp;
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppStyles.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(AppStyles.padding),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info,
                            color: AppStyles.accentColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              model,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppStyles.padding),
                const Divider(),
                const SizedBox(height: AppStyles.padding),
                // Общая статистика
                _buildDetailStatRow(
                  'Всего запросов',
                  totalRequests.toString(),
                  Icons.message,
                ),
                _buildDetailStatRow(
                  'Всего токенов',
                  _formatTokens(totalTokens),
                  Icons.token,
                ),
                _buildDetailStatRow(
                  'Среднее токенов на запрос',
                  _formatTokens(avgTokens.round()),
                  Icons.trending_up,
                ),
                const SizedBox(height: AppStyles.paddingSmall),
                const Divider(),
                const SizedBox(height: AppStyles.paddingSmall),
                // Время ответа
                _buildDetailStatRow(
                  'Среднее время ответа',
                  '${avgResponseTime.toStringAsFixed(2)} сек',
                  Icons.speed,
                ),
                _buildDetailStatRow(
                  'Минимальное время',
                  '${minResponseTime.toStringAsFixed(2)} сек',
                  Icons.arrow_downward,
                ),
                _buildDetailStatRow(
                  'Максимальное время',
                  '${maxResponseTime.toStringAsFixed(2)} сек',
                  Icons.arrow_upward,
                ),
                const SizedBox(height: AppStyles.paddingSmall),
                const Divider(),
                const SizedBox(height: AppStyles.paddingSmall),
                // Токены
                _buildDetailStatRow(
                  'Минимум токенов',
                  _formatTokens(minTokens),
                  Icons.remove_circle_outline,
                ),
                _buildDetailStatRow(
                  'Максимум токенов',
                  _formatTokens(maxTokens),
                  Icons.add_circle_outline,
                ),
                const SizedBox(height: AppStyles.paddingSmall),
                const Divider(),
                const SizedBox(height: AppStyles.paddingSmall),
                // Дополнительная информация
                _buildDetailStatRow(
                  'Средняя длина сообщения',
                  '${avgMessageLength.round()} символов',
                  Icons.text_fields,
                ),
                _buildDetailStatRow(
                  'Первый запрос',
                  DateFormat('yyyy-MM-dd HH:mm').format(firstUse),
                  Icons.event_available,
                ),
                _buildDetailStatRow(
                  'Последний запрос',
                  DateFormat('yyyy-MM-dd HH:mm').format(lastUse),
                  Icons.event,
                ),
                const SizedBox(height: AppStyles.padding),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await _exportModelStatistics(model, records);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Экспорт модели'),
                    ),
                    const SizedBox(width: AppStyles.paddingSmall),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    } catch (e) {
      // Закрываем индикатор загрузки в случае ошибки
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отображения диалога: $e'),
            backgroundColor: AppStyles.errorColor,
          ),
        );
      }
    }
  }

  /// Строит строку статистики для детального диалога.
  Widget _buildDetailStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyles.paddingSmall),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppStyles.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppStyles.textSecondary,
                fontSize: 14,
              ),
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

  /// Экспортирует всю статистику в файлы (JSON и CSV).
  Future<void> _exportStatistics() async {
    final analytics = widget.analytics ?? Analytics();
    
    try {
      // Получаем всю историю
      final history = await analytics.getHistory();
      
      if (history.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет данных для экспорта'),
          ),
        );
        return;
      }
      
      // Получаем директорию для сохранения
      Directory? directory;
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          directory = await getDownloadsDirectory();
          directory ??= await getApplicationDocumentsDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        directory = Directory.current;
      }
      
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      
      // Экспортируем в JSON
      final jsonFile = File('${directory.path}/statistics_$timestamp.json');
      final jsonData = {
        'export_date': DateTime.now().toIso8601String(),
        'total_records': history.length,
        'records': history.map((r) => r.toJson()).toList(),
        'summary': await analytics.getModelStatistics(),
      };
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonData),
      );
      
      // Экспортируем в CSV
      final csvFile = File('${directory.path}/statistics_$timestamp.csv');
      final csvBuffer = StringBuffer();
      // Заголовки CSV
      csvBuffer.writeln('ID,Timestamp,Model,Message Length,Response Time (s),Tokens Used');
      // Данные
      for (final record in history) {
        csvBuffer.writeln(
          '${record.id ?? ""},'
          '${record.timestamp.toIso8601String()},'
          '"${record.model}",'
          '${record.messageLength},'
          '${record.responseTime},'
          '${record.tokensUsed}',
        );
      }
      await csvFile.writeAsString(csvBuffer.toString());
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Статистика экспортирована:\n${jsonFile.path}\n${csvFile.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error exporting statistics: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при экспорте: $e'),
          backgroundColor: AppStyles.errorColor,
        ),
      );
    }
  }

  /// Экспортирует статистику конкретной модели.
  Future<void> _exportModelStatistics(String model, List<AnalyticsRecord> records) async {
    try {
      Directory? directory;
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          directory = await getDownloadsDirectory();
          directory ??= await getApplicationDocumentsDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        directory = Directory.current;
      }
      
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final safeModelName = model.replaceAll(RegExp(r'[^\w\-_.]'), '_');
      
      // Экспортируем в JSON
      final jsonFile = File('${directory.path}/model_${safeModelName}_$timestamp.json');
      final jsonData = {
        'export_date': DateTime.now().toIso8601String(),
        'model': model,
        'total_records': records.length,
        'records': records.map((r) => r.toJson()).toList(),
      };
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonData),
      );
      
      // Экспортируем в CSV
      final csvFile = File('${directory.path}/model_${safeModelName}_$timestamp.csv');
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('ID,Timestamp,Message Length,Response Time (s),Tokens Used');
      for (final record in records) {
        csvBuffer.writeln(
          '${record.id ?? ""},'
          '${record.timestamp.toIso8601String()},'
          '${record.messageLength},'
          '${record.responseTime},'
          '${record.tokensUsed}',
        );
      }
      await csvFile.writeAsString(csvBuffer.toString());
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Статистика модели экспортирована:\n${jsonFile.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('Error exporting model statistics: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при экспорте: $e'),
          backgroundColor: AppStyles.errorColor,
        ),
      );
    }
  }
}
