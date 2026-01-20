import 'package:flutter/material.dart';

import '../navigation/app_router.dart';
import '../utils/platform.dart';
import '../utils/analytics.dart';
import '../utils/monitor.dart';
import '../utils/expenses_calculator.dart';
import 'chat_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import '../api/openrouter_client.dart';

/// Главная страница приложения с навигацией между разделами.
///
/// Предоставляет навигацию между основными страницами приложения:
/// - Чат (главная страница)
/// - Статистика использования моделей
/// - Расходы с графиками
/// - Настройки провайдера и API ключей
///
/// **Особенности:**
/// - Использует адаптивный UI (BottomNavigationBar для мобильных, NavigationRail для десктопа)
/// - Кэширует страницы в `_pages` для сохранения состояния при переключении
/// - Использует `IndexedStack` для переключения между страницами с сохранением состояния
/// - Передает сервисы (Analytics, PerformanceMonitor, ExpensesCalculator) в дочерние экраны
///
/// **Управление состоянием:**
/// - Страницы создаются один раз при инициализации
/// - При изменении API клиента страницы пересоздаются с новыми параметрами
/// - Использует `ValueKey` для правильной работы анимаций
class HomeScreen extends StatefulWidget {
  /// API клиент для передачи в дочерние экраны.
  final OpenRouterClient? apiClient;

  /// Callback при выходе из приложения.
  final VoidCallback? onLogout;

  const HomeScreen({
    super.key,
    this.apiClient,
    this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  /// Кэш виджетов страниц для сохранения состояния при переключении.
  List<Widget>? _pages;
  
  /// Ключи для доступа к State виджетов страниц для вызова методов обновления.
  final GlobalKey<StatisticsScreenState> _statisticsKey = GlobalKey<StatisticsScreenState>();
  final GlobalKey<ExpensesScreenState> _expensesKey = GlobalKey<ExpensesScreenState>();

  /// Список страниц приложения с их маршрутами.
  /// 
  /// Порядок элементов определяет порядок отображения в навигации.
  /// Все страницы имеют иконки и названия для удобной навигации.
  final List<NavigationItem> _navigationItems = const [
    NavigationItem(
      route: AppRoutes.home,
      label: 'Чат',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    NavigationItem(
      route: AppRoutes.statistics,
      label: 'Статистика',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
    ),
    NavigationItem(
      route: AppRoutes.expenses,
      label: 'Расходы',
      icon: Icons.trending_up_outlined,
      selectedIcon: Icons.trending_up,
    ),
    NavigationItem(
      route: AppRoutes.settings,
      label: 'Настройки',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  // Экземпляры сервисов для передачи в дочерние экраны
  final Analytics _analytics = Analytics();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  late final ExpensesCalculator _expensesCalculator;

  @override
  void initState() {
    super.initState();
    // Инициализируем калькулятор расходов
    _expensesCalculator = ExpensesCalculator(analytics: _analytics);
    
    // Обновляем параметры в роутере при инициализации
    AppRouter.apiClient = widget.apiClient;
    AppRouter.onLogout = widget.onLogout;
    AppRouter.analytics = _analytics;
    AppRouter.performanceMonitor = _performanceMonitor;
    AppRouter.expensesCalculator = _expensesCalculator;
    
    // Инициализируем кэш страниц для сохранения состояния
    _pages ??= _buildPages();
    
    // Обновляем данные для начальной страницы (если это статистика или расходы)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPageData(_selectedIndex);
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем параметры в роутере при изменении виджета
    if (widget.apiClient != oldWidget.apiClient) {
      AppRouter.apiClient = widget.apiClient;
      // Пересоздаем страницы при изменении API клиента
      _pages = _buildPages();
    }
    if (widget.onLogout != oldWidget.onLogout) {
      AppRouter.onLogout = widget.onLogout;
    }
    // Всегда обновляем сервисы, так как они могут измениться
    AppRouter.analytics = _analytics;
    AppRouter.performanceMonitor = _performanceMonitor;
    AppRouter.expensesCalculator = _expensesCalculator;
  }

  /// Обрабатывает изменение выбранного индекса навигации.
  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      return; // Игнорируем повторное нажатие на текущий элемент
    }

    setState(() {
      _selectedIndex = index;
    });
    
    // Обновляем данные при переключении на страницы статистики или расходов
    _refreshPageData(index);
  }
  
  /// Обновляет данные страницы при переключении вкладок.
  void _refreshPageData(int index) {
    // Индексы страниц: 0 - Чат, 1 - Статистика, 2 - Расходы, 3 - Настройки
    if (index == 1) {
      // Статистика
      _statisticsKey.currentState?.refreshData();
    } else if (index == 2) {
      // Расходы
      _expensesKey.currentState?.refreshData();
    }
  }

  /// Создает список виджетов страниц для кэширования состояния.
  /// 
  /// Использует ключи для сохранения состояния при пересоздании виджетов.
  List<Widget> _buildPages() {
    return _navigationItems.map((item) {
      final routeName = item.route;
      
      // Создаем уникальный ключ для каждой страницы для сохранения состояния
      final pageKey = ValueKey('${routeName}_${widget.apiClient?.hashCode ?? 'null'}');
      
      // Создаем виджеты страниц напрямую для правильной работы IndexedStack
      switch (routeName) {
        case AppRoutes.home:
          return ChatScreen(
            key: pageKey,
            apiClient: widget.apiClient,
            onLogout: widget.onLogout,
          );
        
        case AppRoutes.statistics:
          return StatisticsScreen(
            key: _statisticsKey,
            apiClient: widget.apiClient,
            analytics: AppRouter.analytics ?? _analytics,
            performanceMonitor: AppRouter.performanceMonitor ?? _performanceMonitor,
            onLogout: widget.onLogout,
          );
        
        case AppRoutes.expenses:
          return ExpensesScreen(
            key: _expensesKey,
            apiClient: widget.apiClient,
            analytics: AppRouter.analytics ?? _analytics,
            expensesCalculator: AppRouter.expensesCalculator ?? _expensesCalculator,
            onLogout: widget.onLogout,
          );
        
        case AppRoutes.settings:
          return SettingsScreen(key: pageKey);
        
        default:
          // Fallback на главную страницу
          return ChatScreen(
            key: pageKey,
            apiClient: widget.apiClient,
            onLogout: widget.onLogout,
          );
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformUtils.isMobile();

    // Для мобильных устройств используем BottomNavigationBar
    if (isMobile) {
      return Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages ?? [],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: _navigationItems.map((item) {
            return BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: item.selectedIcon != null 
                  ? Icon(item.selectedIcon) 
                  : Icon(item.icon),
              label: item.label,
              tooltip: item.label,
            );
          }).toList(),
        ),
      );
    }

    // Для десктопных платформ используем NavigationRail
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            extended: false,
            destinations: _navigationItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(
                  item.selectedIcon ?? item.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(item.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Основной контент
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages ?? [],
            ),
          ),
        ],
      ),
    );
  }
}

/// Модель элемента навигации.
class NavigationItem {
  /// Маршрут страницы.
  final String route;

  /// Отображаемое название.
  final String label;

  /// Иконка элемента навигации (невыбранное состояние).
  final IconData icon;

  /// Иконка элемента навигации (выбранное состояние).
  final IconData? selectedIcon;

  const NavigationItem({
    required this.route,
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
}
