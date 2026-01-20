import 'package:flutter/material.dart';

import '../navigation/app_router.dart';
import '../utils/platform.dart';
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
  final List<NavigationItem> _navigationItems = const [
    NavigationItem(
      route: AppRoutes.home,
      label: 'Чат',
      icon: Icons.chat,
    ),
    NavigationItem(
      route: AppRoutes.statistics,
      label: 'Статистика',
      icon: Icons.analytics,
    ),
    NavigationItem(
      route: AppRoutes.expenses,
      label: 'Расходы',
      icon: Icons.trending_up,
    ),
    NavigationItem(
      route: AppRoutes.settings,
      label: 'Настройки',
      icon: Icons.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Обновляем API клиент в роутере при инициализации
    AppRouter.apiClient = widget.apiClient;
    AppRouter.onLogout = widget.onLogout;
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем API клиент при изменении виджета
    if (widget.apiClient != oldWidget.apiClient) {
      AppRouter.apiClient = widget.apiClient;
    }
    if (widget.onLogout != oldWidget.onLogout) {
      AppRouter.onLogout = widget.onLogout;
    }
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
              label: item.label,
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
            destinations: _navigationItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
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

  /// Иконка элемента навигации.
  final IconData icon;

  const NavigationItem({
    required this.route,
    required this.label,
    required this.icon,
  });
}
