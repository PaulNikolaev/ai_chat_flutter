import 'package:flutter/material.dart';

/// Кастомные переходы между страницами для улучшения UX.
///
/// Предоставляет плавные анимации переходов между экранами приложения.
/// Все переходы используют оптимизированные кривые анимации для плавности.
///
/// **Пример использования:**
/// ```dart
/// Navigator.push(
///   context,
///   PageTransitions.fadeSlideRoute(
///     builder: (context) => MyScreen(),
///   ),
/// );
/// ```
class PageTransitions {
  /// Приватный конструктор для предотвращения создания экземпляров.
  PageTransitions._();

  /// Длительность стандартного перехода.
  static const Duration defaultDuration = Duration(milliseconds: 300);

  /// Длительность быстрого перехода.
  static const Duration fastDuration = Duration(milliseconds: 200);

  /// Длительность медленного перехода.
  static const Duration slowDuration = Duration(milliseconds: 500);

  /// Создает плавный fade переход между страницами.
  ///
  /// Используется для переходов между основными экранами приложения.
  static PageRoute<T> fadeRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = defaultDuration,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Создает slide переход снизу вверх (для мобильных устройств).
  ///
  /// Используется для модальных окон и диалогов.
  static PageRoute<T> slideUpRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = defaultDuration,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Создает slide переход слева направо (для десктопных устройств).
  ///
  /// Используется для переходов между основными экранами на десктопе.
  static PageRoute<T> slideRightRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = defaultDuration,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Создает комбинированный fade + slide переход.
  ///
  /// Используется для плавных переходов между основными экранами.
  static PageRoute<T> fadeSlideRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = defaultDuration,
    Offset beginOffset = const Offset(0.0, 0.1),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var slideTween = Tween(begin: beginOffset, end: end).chain(
          CurveTween(curve: curve),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Создает масштабирующий переход (zoom).
  ///
  /// Используется для акцента на важных экранах.
  static PageRoute<T> scaleRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = defaultDuration,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.9,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}
