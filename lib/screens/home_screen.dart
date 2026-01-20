import 'package:flutter/material.dart';

import '../navigation/app_router.dart';
import '../utils/platform.dart';
import '../utils/analytics.dart';
import '../utils/monitor.dart';
import '../utils/expenses_calculator.dart';
import 'chat_screen.dart';
import '../api/openrouter_client.dart';

/// Главная страница приложения с навигацией между разделами.
///
/// Предоставляет навигацию между основными страницами приложения:
/// - Чат (главная страница)
/// - Настройки
/// - Статистика
/// - Расходы
///
/// Использует адаптивный UI:
/// - BottomNavigationBar для мобильных устройств
/// - NavigationRail для десктопных платформ
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
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем параметры в роутере при изменении виджета
    if (widget.apiClient != oldWidget.apiClient) {
      AppRouter.apiClient = widget.apiClient;
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
  }

  /// Получает текущую страницу в зависимости от выбранного индекса.
  Widget _getPage(int index) {
    final routeName = _navigationItems[index].route;
    
    // Для главной страницы возвращаем ChatScreen напрямую
    if (routeName == AppRoutes.home) {
      return ChatScreen(
        apiClient: widget.apiClient,
        onLogout: widget.onLogout,
      );
    }
    
    // Для остальных страниц используем генератор роутов
    final routeSettings = RouteSettings(name: routeName);
    final route = AppRouter.onGenerateRoute(routeSettings);
    
    if (route != null && route is MaterialPageRoute) {
      return Builder(
        builder: (context) => route.builder(context),
      );
    }
    
    // Fallback на главную страницу
    return ChatScreen(
      apiClient: widget.apiClient,
      onLogout: widget.onLogout,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformUtils.isMobile();

    // Для мобильных устройств используем BottomNavigationBar
    if (isMobile) {
      return Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _navigationItems.asMap().entries.map((entry) {
            final index = entry.key;
            return _getPage(index);
          }).toList(),
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
              children: _navigationItems.asMap().entries.map((entry) {
                final index = entry.key;
                return _getPage(index);
              }).toList(),
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
