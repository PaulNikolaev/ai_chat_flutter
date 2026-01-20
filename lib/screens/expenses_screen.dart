import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ai_chat/api/api.dart';
import 'package:ai_chat/models/models.dart';
import 'package:ai_chat/ui/ui.dart';
import 'package:ai_chat/utils/utils.dart';

/// Тип периода для отображения расходов.
enum ExpensesPeriodType {
  day,
  week,
  month,
}

/// Страница отображения графика расходов.
///
/// Показывает:
/// - График расходов по дням/неделям/месяцам
/// - Общую сумму расходов
/// - Фильтры по моделям и датам
/// - Разбивку расходов по моделям
class ExpensesScreen extends StatefulWidget {
  /// API клиент для получения информации о моделях.
  final OpenRouterClient? apiClient;

  /// Экземпляр аналитики для получения данных.
  final Analytics? analytics;

  /// Экземпляр калькулятора расходов.
  final ExpensesCalculator? expensesCalculator;

  /// Callback при нажатии кнопки выхода.
  final VoidCallback? onLogout;

  const ExpensesScreen({
    super.key,
    this.apiClient,
    this.analytics,
    this.expensesCalculator,
    this.onLogout,
  });

  @override
  State<ExpensesScreen> createState() => ExpensesScreenState();
}

class ExpensesScreenState extends State<ExpensesScreen> {
  /// Текущий тип периода отображения.
  ExpensesPeriodType _periodType = ExpensesPeriodType.day;

  /// Дата начала периода.
  DateTime? _startDate;

  /// Дата окончания периода.
  DateTime? _endDate;

  /// Фильтр по модели.
  String? _selectedModelFilter;

  /// Флаг загрузки данных.
  bool _isLoading = false;

  /// Флаг сравнения периодов.
  bool _isComparisonMode = false;

  /// Дата начала второго периода для сравнения.
  DateTime? _compareStartDate;

  /// Дата окончания второго периода для сравнения.
  DateTime? _compareEndDate;

  /// Данные расходов за второй период для сравнения.
  List<ExpensesPeriod> _compareExpensesData = [];

  /// Общая сумма расходов за второй период.
  double _compareTotalExpenses = 0.0;

  /// Кэш для оптимизации производительности.
  final Map<String, List<ExpensesPeriod>> _expensesCache = {};
  final Map<String, double> _totalExpensesCache = {};

  /// Данные расходов за выбранный период.
  List<ExpensesPeriod> _expensesData = [];

  /// Общая сумма расходов.
  double _totalExpenses = 0.0;

  /// Список доступных моделей для фильтрации.
  List<ModelInfo> _availableModels = [];

  /// Экземпляр калькулятора расходов.
  late ExpensesCalculator _calculator;
  
  // Флаг для отслеживания первого вызова didChangeDependencies
  bool _isFirstBuild = true;
  
  // Время последнего обновления расходов
  DateTime? _lastExpensesUpdate;

  @override
  void initState() {
    super.initState();
    // Инициализируем даты: по умолчанию последние 30 дней
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));

    // Инициализируем калькулятор
    _calculator = widget.expensesCalculator ??
        ExpensesCalculator(analytics: widget.analytics);

    // Загружаем данные
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем данные при каждом входе на страницу (кроме первого раза)
    if (!_isFirstBuild) {
      // Обновляем расходы только если прошло больше 1 секунды с последнего обновления
      final now = DateTime.now();
      if (_lastExpensesUpdate == null || 
          now.difference(_lastExpensesUpdate!).inSeconds > 1) {
        _lastExpensesUpdate = now;
        // Принудительно обновляем расходы при входе на страницу
        _loadExpenses(forceRefresh: true);
        _loadModels();
      }
    } else {
      _isFirstBuild = false;
      _lastExpensesUpdate = DateTime.now();
    }
  }

  /// Загружает все данные для страницы.
  Future<void> _loadData() async {
    await Future.wait([
      _loadModels(),
      _loadExpenses(),
    ]);
  }
  
  /// Публичный метод для принудительного обновления данных при входе на страницу.
  /// Вызывается из HomeScreen при переключении вкладок.
  void refreshData() {
    // Обновляем данные принудительно
    _loadExpenses(forceRefresh: true);
    _loadModels();
    _lastExpensesUpdate = DateTime.now();
  }

  /// Загружает список моделей для фильтрации.
  Future<void> _loadModels() async {
    final apiClient = widget.apiClient;
    if (apiClient == null) return;

    try {
      final models = await apiClient.getModels();
      if (mounted) {
        setState(() {
          _availableModels = models;
        });
        // Обновляем кэш моделей в калькуляторе
        _calculator.updateModelInfoCache(models);
      }
    } catch (e) {
      debugPrint('ExpensesScreen: Error loading models: $e');
    }
  }

  /// Загружает данные расходов для выбранного периода с кэшированием.
  Future<void> _loadExpenses({bool forceRefresh = false}) async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Проверяем кэш для оптимизации (если не принудительное обновление)
      final cacheKey = _getCacheKey(_startDate!, _endDate!, _selectedModelFilter, _periodType);
      
      List<ExpensesPeriod> expenses;
      double total;

      if (!forceRefresh && _expensesCache.containsKey(cacheKey) && _totalExpensesCache.containsKey(cacheKey)) {
        // Используем кэшированные данные
        expenses = _expensesCache[cacheKey]!;
        total = _totalExpensesCache[cacheKey]!;
      } else {
        // Загружаем данные
        switch (_periodType) {
          case ExpensesPeriodType.day:
            expenses = await _calculator.getExpensesByDays(
              startDate: _startDate!,
              endDate: _endDate!,
              model: _selectedModelFilter,
            );
            break;
          case ExpensesPeriodType.week:
            expenses = await _calculator.getExpensesByWeeks(
              startDate: _startDate!,
              endDate: _endDate!,
              model: _selectedModelFilter,
            );
            break;
          case ExpensesPeriodType.month:
            expenses = await _calculator.getExpensesByMonths(
              startDate: _startDate!,
              endDate: _endDate!,
              model: _selectedModelFilter,
            );
            break;
        }

        // Ограничиваем количество данных для производительности (максимум 365 периодов)
        if (expenses.length > 365) {
          expenses = expenses.sublist(expenses.length - 365);
        }

        total = await _calculator.getTotalExpenses(
          startDate: _startDate!,
          endDate: _endDate!,
          model: _selectedModelFilter,
        );

        // Сохраняем в кэш (ограничиваем размер кэша до 10 записей)
        if (_expensesCache.length >= 10) {
          final firstKey = _expensesCache.keys.first;
          _expensesCache.remove(firstKey);
          _totalExpensesCache.remove(firstKey);
        }
        _expensesCache[cacheKey] = expenses;
        _totalExpensesCache[cacheKey] = total;
      }

      if (mounted) {
        setState(() {
          _expensesData = expenses;
          _totalExpenses = total;
          _isLoading = false;
        });
      }

      // Загружаем данные для сравнения, если режим сравнения включен
      if (_isComparisonMode && _compareStartDate != null && _compareEndDate != null) {
        await _loadCompareExpenses();
      }
    } catch (e, stackTrace) {
      debugPrint('ExpensesScreen: Error loading expenses: $e');
      debugPrint('ExpensesScreen: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _expensesData = [];
          _totalExpenses = 0.0;
          _isLoading = false;
        });
      }
    }
  }

  /// Генерирует ключ кэша для данных расходов.
  String _getCacheKey(DateTime startDate, DateTime endDate, String? model, ExpensesPeriodType periodType) {
    return '${startDate.toIso8601String()}_${endDate.toIso8601String()}_${model ?? "all"}_${periodType.name}';
  }

  /// Загружает данные расходов для второго периода сравнения.
  Future<void> _loadCompareExpenses() async {
    if (_compareStartDate == null || _compareEndDate == null) return;

    try {
      List<ExpensesPeriod> expenses;
      double total;

      switch (_periodType) {
        case ExpensesPeriodType.day:
          expenses = await _calculator.getExpensesByDays(
            startDate: _compareStartDate!,
            endDate: _compareEndDate!,
            model: _selectedModelFilter,
          );
          break;
        case ExpensesPeriodType.week:
          expenses = await _calculator.getExpensesByWeeks(
            startDate: _compareStartDate!,
            endDate: _compareEndDate!,
            model: _selectedModelFilter,
          );
          break;
        case ExpensesPeriodType.month:
          expenses = await _calculator.getExpensesByMonths(
            startDate: _compareStartDate!,
            endDate: _compareEndDate!,
            model: _selectedModelFilter,
          );
          break;
      }

      // Ограничиваем количество данных для производительности
      if (expenses.length > 365) {
        expenses = expenses.sublist(expenses.length - 365);
      }

      total = await _calculator.getTotalExpenses(
        startDate: _compareStartDate!,
        endDate: _compareEndDate!,
        model: _selectedModelFilter,
      );

      if (mounted) {
        setState(() {
          _compareExpensesData = expenses;
          _compareTotalExpenses = total;
        });
      }
    } catch (e) {
      debugPrint('ExpensesScreen: Error loading compare expenses: $e');
      if (mounted) {
        setState(() {
          _compareExpensesData = [];
          _compareTotalExpenses = 0.0;
        });
      }
    }
  }

  /// Переключает режим сравнения периодов.
  void _toggleComparisonMode() {
    setState(() {
      _isComparisonMode = !_isComparisonMode;
      if (!_isComparisonMode) {
        _compareStartDate = null;
        _compareEndDate = null;
        _compareExpensesData = [];
        _compareTotalExpenses = 0.0;
      } else {
        // Инициализируем второй период: предыдущий такой же длины
        if (_startDate != null && _endDate != null) {
          final periodLength = _endDate!.difference(_startDate!);
          _compareEndDate = _startDate!.subtract(const Duration(days: 1));
          _compareStartDate = _compareEndDate!.subtract(periodLength);
          _loadCompareExpenses();
        }
      }
    });
  }

  /// Применяет фильтры и перезагружает данные.
  void _applyFilters() {
    _loadExpenses();
  }

  /// Сбрасывает все фильтры.
  void _resetFilters() {
    setState(() {
      final now = DateTime.now();
      _endDate = now;
      _startDate = now.subtract(const Duration(days: 30));
      _selectedModelFilter = null;
    });
    _loadExpenses();
  }

  /// Форматирует сумму расходов для отображения.
  String _formatCost(double cost) {
    if (cost < 0.01) {
      return '\$${cost.toStringAsFixed(4)}';
    }
    return '\$${cost.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppStyles.getPadding(context);
    final maxContentWidth = AppStyles.getMaxContentWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.trending_up, size: 24),
            SizedBox(width: 8),
            Text('Расходы'),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Экспорт данных',
            onPressed: _exportExpensesData,
          ),
          IconButton(
            icon: Icon(_isComparisonMode ? Icons.compare_arrows : Icons.compare),
            tooltip: _isComparisonMode ? 'Отключить сравнение' : 'Сравнить периоды',
            onPressed: _toggleComparisonMode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWithMessage(
              message: 'Загрузка данных о расходах...',
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
                      // Общая сумма расходов
                      _buildTotalExpensesSection(),
                      const SizedBox(height: AppStyles.padding),

                      // Сравнение периодов (если включено)
                      if (_isComparisonMode) ...[
                        _buildComparisonSection(),
                        const SizedBox(height: AppStyles.padding),
                      ],

                      // Фильтры и выбор периода
                      _buildFiltersSection(),
                      const SizedBox(height: AppStyles.padding),

                      // Область для графика (заглушка на данный момент)
                      _buildChartSection(),
                      const SizedBox(height: AppStyles.padding),

                      // Разбивка расходов по моделям
                      if (_expensesData.isNotEmpty) ...[
                        _buildModelBreakdownSection(),
                        const SizedBox(height: AppStyles.padding),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Строит секцию с общей суммой расходов.
  Widget _buildTotalExpensesSection() {
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
                Icons.account_balance_wallet,
                color: AppStyles.accentColor,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Общие расходы',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          Text(
            _formatCost(_totalExpenses),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppStyles.accentColor,
            ),
          ),
          const SizedBox(height: AppStyles.paddingSmall),
          Text(
            'За период: ${_getPeriodLabel()}',
            style: const TextStyle(
              color: AppStyles.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Строит секцию фильтров и выбора периода.
  Widget _buildFiltersSection() {
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
                'Фильтры и период',
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
              
              // Выбор типа периода
              final periodTypeSelector = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Тип периода:',
                    style: TextStyle(
                      color: AppStyles.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppStyles.paddingSmall),
                  SegmentedButton<ExpensesPeriodType>(
                    segments: const [
                      ButtonSegment<ExpensesPeriodType>(
                        value: ExpensesPeriodType.day,
                        label: Text('Дни'),
                        icon: Icon(Icons.calendar_today, size: 16),
                      ),
                      ButtonSegment<ExpensesPeriodType>(
                        value: ExpensesPeriodType.week,
                        label: Text('Недели'),
                        icon: Icon(Icons.date_range, size: 16),
                      ),
                      ButtonSegment<ExpensesPeriodType>(
                        value: ExpensesPeriodType.month,
                        label: Text('Месяцы'),
                        icon: Icon(Icons.calendar_month, size: 16),
                      ),
                    ],
                    selected: {_periodType},
                    onSelectionChanged: (Set<ExpensesPeriodType> selection) {
                      if (selection.isNotEmpty) {
                        setState(() {
                          _periodType = selection.first;
                        });
                        _loadExpenses();
                      }
                    },
                  ),
                ],
              );
              
              // Фильтр по дате
              final dateFilters = Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: _endDate ?? DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _startDate = date;
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
                          _startDate != null
                              ? DateFormat('yyyy-MM-dd').format(_startDate!)
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
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
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
                      _endDate != null
                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
                          : 'Не выбрана',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          );
              
              // Фильтр по модели
              final modelFilter = DropdownButtonFormField<String>(
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
                  ..._availableModels.map((model) => DropdownMenuItem<String>(
                        value: model.id,
                        child: Text(model.id, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedModelFilter = value;
                  });
                  _applyFilters();
                },
              );
              
              // Кнопка сброса фильтров
              final resetButton = Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Сбросить фильтры'),
                  ),
                ],
              );
              
              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    periodTypeSelector,
                    const SizedBox(height: AppStyles.padding),
                    dateFilters,
                    const SizedBox(height: AppStyles.paddingSmall),
                    modelFilter,
                    const SizedBox(height: AppStyles.paddingSmall),
                    resetButton,
                  ],
                );
              } else {
                // Для планшетов и больших экранов размещаем в две колонки
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    periodTypeSelector,
                    const SizedBox(height: AppStyles.padding),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: dateFilters,
                        ),
                        const SizedBox(width: AppStyles.padding),
                        Expanded(
                          flex: 1,
                          child: modelFilter,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.paddingSmall),
                    resetButton,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Строит секцию графика расходов.
  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.padding,
        AppStyles.padding,
        AppStyles.padding,
        AppStyles.paddingLarge,
      ),
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
                Icons.show_chart,
                color: AppStyles.accentColor,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'График расходов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          // Легенда графика
          if (_expensesData.isNotEmpty) _buildChartLegend(),
          const SizedBox(height: AppStyles.paddingSmall),
          if (_expensesData.isEmpty)
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
                      'Нет данных для отображения',
                      style: TextStyle(color: AppStyles.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Используйте чат для накопления данных о расходах',
                      style: TextStyle(
                        color: AppStyles.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: _buildExpensesChart(),
            ),
        ],
      ),
    );
  }

  /// Строит график расходов используя fl_chart.
  Widget _buildExpensesChart() {
    if (_expensesData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Подготавливаем данные для графика
    final barGroups = _expensesData.asMap().entries.map((entry) {
      final index = entry.key;
      final period = entry.value;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: period.totalCost,
            color: AppStyles.accentColor,
            width: _periodType == ExpensesPeriodType.day ? 8 : 12,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
        ],
        barsSpace: 4,
      );
    }).toList();

    // Формируем подписи для оси X
    final xLabels = _expensesData.map((period) {
      switch (_periodType) {
        case ExpensesPeriodType.day:
          return DateFormat('MM/dd').format(period.startDate);
        case ExpensesPeriodType.week:
          return DateFormat('MM/dd').format(period.startDate);
        case ExpensesPeriodType.month:
          return DateFormat('MMM yyyy').format(period.startDate);
      }
    }).toList();

    // Находим максимальное значение для масштабирования
    final maxValue = _expensesData.isEmpty
        ? 1.0
        : _expensesData.map((p) => p.totalCost).reduce((a, b) => a > b ? a : b);
    final maxY = maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 1.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final period = _expensesData[groupIndex];
              String periodLabel;
              switch (_periodType) {
                case ExpensesPeriodType.day:
                  periodLabel = DateFormat('yyyy-MM-dd').format(period.startDate);
                  break;
                case ExpensesPeriodType.week:
                  periodLabel =
                      '${DateFormat('MM/dd').format(period.startDate)} - ${DateFormat('MM/dd').format(period.endDate)}';
                  break;
                case ExpensesPeriodType.month:
                  periodLabel = DateFormat('MMM yyyy').format(period.startDate);
                  break;
              }
              
              // Формируем детальную информацию с разбивкой по моделям
              final tooltipLines = <String>[
                periodLabel,
                'Общие расходы: ${_formatCost(rod.toY)}',
                'Запросов: ${period.requestCount}',
              ];
              
              // Добавляем разбивку по моделям, если есть данные
              if (period.costsByModel.isNotEmpty) {
                tooltipLines.add('');
                tooltipLines.add('По моделям:');
                final sortedModels = period.costsByModel.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                
                // Показываем топ-5 моделей, чтобы не перегружать tooltip
                final modelsToShow = sortedModels.take(5);
                for (final modelEntry in modelsToShow) {
                  final percentage = period.totalCost > 0
                      ? (modelEntry.value / period.totalCost * 100).toStringAsFixed(1)
                      : '0.0';
                  tooltipLines.add(
                    '  • ${modelEntry.key}: ${_formatCost(modelEntry.value)} ($percentage%)',
                  );
                }
                
                if (sortedModels.length > 5) {
                  final remainingCost = sortedModels.skip(5)
                      .fold<double>(0.0, (sum, e) => sum + e.value);
                  tooltipLines.add(
                    '  • Прочие: ${_formatCost(remainingCost)}',
                  );
                }
              }
              
              return BarTooltipItem(
                tooltipLines.join('\n'),
                const TextStyle(
                  color: AppStyles.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
            tooltipBgColor: AppStyles.cardColor,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                'Период',
                style: TextStyle(
                  color: AppStyles.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Показываем подписи только для некоторых столбцов, чтобы не перегружать график
                final index = value.toInt();
                if (index < 0 || index >= xLabels.length) {
                  return const Text('');
                }
                
                // Показываем каждую N-ю подпись в зависимости от количества данных
                final showEveryNth = _expensesData.length > 20
                    ? (_expensesData.length / 10).ceil()
                    : (_expensesData.length > 10 ? 2 : 1);
                
                if (index % showEveryNth != 0 && index != xLabels.length - 1) {
                  return const Text('');
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    xLabels[index],
                    style: const TextStyle(
                      color: AppStyles.textSecondary,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
              reservedSize: 60,
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'Расходы (\$)',
                  style: TextStyle(
                    color: AppStyles.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _formatCost(value),
                    style: const TextStyle(
                      color: AppStyles.textSecondary,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppStyles.borderColor.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: AppStyles.borderColor,
            width: 1,
          ),
        ),
        barGroups: barGroups,
      ),
    );
  }

  /// Строит легенду графика.
  Widget _buildChartLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.paddingSmall,
        vertical: AppStyles.paddingSmall / 2,
      ),
      decoration: BoxDecoration(
        color: AppStyles.surfaceColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius / 2),
        border: Border.all(
          color: AppStyles.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppStyles.accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Общие расходы за период',
            style: TextStyle(
              color: AppStyles.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.info_outline,
            size: 14,
            color: AppStyles.textSecondary,
          ),
          const SizedBox(width: 4),
          const Text(
            'Нажмите на столбец для деталей',
            style: TextStyle(
              color: AppStyles.textSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Строит секцию разбивки расходов по моделям.
  Widget _buildModelBreakdownSection() {
    // Агрегируем расходы по моделям
    final Map<String, double> modelCosts = {};
    for (final period in _expensesData) {
      for (final entry in period.costsByModel.entries) {
        modelCosts[entry.key] = (modelCosts[entry.key] ?? 0.0) + entry.value;
      }
    }

    final sortedModels = modelCosts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                Icons.pie_chart,
                color: AppStyles.accentColor,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Расходы по моделям',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          if (sortedModels.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppStyles.padding),
                child: Text(
                  'Нет данных',
                  style: TextStyle(color: AppStyles.textSecondary),
                ),
              ),
            )
          else
            ...sortedModels.map((entry) {
              final percentage = _totalExpenses > 0
                  ? (entry.value / _totalExpenses * 100).toStringAsFixed(1)
                  : '0.0';
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
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: AppStyles.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppStyles.paddingSmall),
                      Text(
                        _formatCost(entry.value),
                        style: const TextStyle(
                          color: AppStyles.accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: AppStyles.paddingSmall),
                      Text(
                        '($percentage%)',
                        style: const TextStyle(
                          color: AppStyles.textSecondary,
                          fontSize: 12,
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

  /// Возвращает текстовую метку для текущего периода.
  String _getPeriodLabel() {
    if (_startDate == null || _endDate == null) {
      return 'Не выбран';
    }
    return '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}';
  }

  /// Экспортирует данные расходов в CSV и JSON форматы.
  Future<void> _exportExpensesData() async {
    if (_expensesData.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет данных для экспорта'),
          backgroundColor: AppStyles.warningColor,
        ),
      );
      return;
    }

    try {
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
      final periodTypeStr = _periodType.name;

      // Экспортируем в JSON
      final jsonFile = File('${directory.path}/expenses_${periodTypeStr}_$timestamp.json');
      final jsonData = {
        'export_date': DateTime.now().toIso8601String(),
        'period_type': periodTypeStr,
        'start_date': _startDate?.toIso8601String(),
        'end_date': _endDate?.toIso8601String(),
        'model_filter': _selectedModelFilter,
        'total_expenses': _totalExpenses,
        'periods': _expensesData.map((period) => {
          'start_date': period.startDate.toIso8601String(),
          'end_date': period.endDate.toIso8601String(),
          'total_cost': period.totalCost,
          'request_count': period.requestCount,
          'costs_by_model': period.costsByModel,
        }).toList(),
      };
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonData),
      );

      // Экспортируем в CSV
      final csvFile = File('${directory.path}/expenses_${periodTypeStr}_$timestamp.csv');
      final csvBuffer = StringBuffer();
      
      // Заголовки CSV
      csvBuffer.writeln('Start Date,End Date,Total Cost (\$),Request Count,Models');
      
      // Данные
      for (final period in _expensesData) {
        final modelsStr = period.costsByModel.entries
            .map((e) => '${e.key}: ${_formatCost(e.value)}')
            .join('; ');
        csvBuffer.writeln(
          '${DateFormat('yyyy-MM-dd').format(period.startDate)},'
          '${DateFormat('yyyy-MM-dd').format(period.endDate)},'
          '${period.totalCost},'
          '${period.requestCount},'
          '"$modelsStr"',
        );
      }
      await csvFile.writeAsString(csvBuffer.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Данные экспортированы:\n${jsonFile.path}\n${csvFile.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error exporting expenses: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при экспорте: $e'),
          backgroundColor: AppStyles.errorColor,
        ),
      );
    }
  }

  /// Строит секцию сравнения периодов.
  Widget _buildComparisonSection() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppStyles.accentColor.withValues(alpha: 0.5)),
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
            children: [
              const Icon(
                Icons.compare_arrows,
                color: AppStyles.accentColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Сравнение периодов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _toggleComparisonMode,
                tooltip: 'Отключить сравнение',
              ),
            ],
          ),
          const SizedBox(height: AppStyles.padding),
          // Выбор второго периода
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _compareStartDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: _compareEndDate ?? DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _compareStartDate = date;
                      });
                      _loadCompareExpenses();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Начало периода сравнения',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                      ),
                    ),
                    child: Text(
                      _compareStartDate != null
                          ? DateFormat('yyyy-MM-dd').format(_compareStartDate!)
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
                      initialDate: _compareEndDate ?? DateTime.now(),
                      firstDate: _compareStartDate ?? DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _compareEndDate = date;
                      });
                      _loadCompareExpenses();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Конец периода сравнения',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                      ),
                    ),
                    child: Text(
                      _compareEndDate != null
                          ? DateFormat('yyyy-MM-dd').format(_compareEndDate!)
                          : 'Не выбрана',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_compareExpensesData.isNotEmpty) ...[
            const SizedBox(height: AppStyles.padding),
            const Divider(),
            const SizedBox(height: AppStyles.padding),
            // Сравнение сумм
            Row(
              children: [
                Expanded(
                  child: _buildComparisonCard(
                    'Текущий период',
                    _formatCost(_totalExpenses),
                    AppStyles.accentColor,
                  ),
                ),
                const SizedBox(width: AppStyles.padding),
                Expanded(
                  child: _buildComparisonCard(
                    'Период сравнения',
                    _formatCost(_compareTotalExpenses),
                    AppStyles.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppStyles.paddingSmall),
            // Разница
            Container(
              padding: const EdgeInsets.all(AppStyles.paddingSmall),
              decoration: BoxDecoration(
                color: AppStyles.surfaceColor,
                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Разница: ',
                    style: TextStyle(
                      color: AppStyles.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _formatCost(_totalExpenses - _compareTotalExpenses),
                    style: TextStyle(
                      color: _totalExpenses > _compareTotalExpenses
                          ? AppStyles.errorColor
                          : AppStyles.successColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${((_totalExpenses / (_compareTotalExpenses > 0 ? _compareTotalExpenses : 1) - 1) * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      color: AppStyles.textSecondary,
                      fontSize: 12,
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

  /// Строит карточку сравнения.
  Widget _buildComparisonCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.padding),
      decoration: BoxDecoration(
        color: AppStyles.surfaceColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppStyles.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
