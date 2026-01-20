import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../api/openrouter_client.dart';
import '../models/model_info.dart';
import '../ui/styles.dart';
import '../utils/analytics.dart';
import '../utils/expenses_calculator.dart';

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

  const ExpensesScreen({
    super.key,
    this.apiClient,
    this.analytics,
    this.expensesCalculator,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
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

  /// Данные расходов за выбранный период.
  List<ExpensesPeriod> _expensesData = [];

  /// Общая сумма расходов.
  double _totalExpenses = 0.0;

  /// Список доступных моделей для фильтрации.
  List<ModelInfo> _availableModels = [];

  /// Экземпляр калькулятора расходов.
  late ExpensesCalculator _calculator;

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

  /// Загружает все данные для страницы.
  Future<void> _loadData() async {
    await Future.wait([
      _loadModels(),
      _loadExpenses(),
    ]);
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

  /// Загружает данные расходов для выбранного периода.
  Future<void> _loadExpenses() async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<ExpensesPeriod> expenses;
      double total;

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

      total = await _calculator.getTotalExpenses(
        startDate: _startDate!,
        endDate: _endDate!,
        model: _selectedModelFilter,
      );

      if (mounted) {
        setState(() {
          _expensesData = expenses;
          _totalExpenses = total;
          _isLoading = false;
        });
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppStyles.padding),
                  Text(
                    'Загрузка данных о расходах...',
                    style: TextStyle(
                      color: AppStyles.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
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
                      // Общая сумма расходов
                      _buildTotalExpensesSection(),
                      const SizedBox(height: AppStyles.padding),

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
          // Выбор типа периода
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
          const SizedBox(height: AppStyles.padding),
          // Фильтр по дате
          Row(
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
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.paddingSmall),
          // Фильтр по модели
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Модель',
              prefixIcon: const Icon(Icons.model_training),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
              ),
            ),
            initialValue: _selectedModelFilter,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Все модели'),
              ),
              ..._availableModels.map((model) => DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(model.id),
                  )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedModelFilter = value;
              });
              _applyFilters();
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

  /// Строит секцию графика расходов.
  Widget _buildChartSection() {
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
              return BarTooltipItem(
                '$periodLabel\n${_formatCost(rod.toY)}\n${period.requestCount} запросов',
                const TextStyle(
                  color: AppStyles.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
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
}
