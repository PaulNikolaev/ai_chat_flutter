import 'package:flutter/material.dart';

/// Анимированный индикатор загрузки с плавными переходами.
///
/// Предоставляет улучшенную визуальную обратную связь при загрузке данных.
/// Поддерживает пульсирующую анимацию и настраиваемые параметры отображения.
///
/// **Пример использования:**
/// ```dart
/// AnimatedLoadingIndicator(
///   size: 40,
///   usePulse: true,
///   message: 'Загрузка данных...',
/// )
/// ```
class AnimatedLoadingIndicator extends StatefulWidget {
  /// Размер индикатора.
  final double? size;

  /// Цвет индикатора.
  final Color? color;

  /// Толщина линии индикатора.
  final double strokeWidth;

  /// Текст под индикатором (опционально).
  final String? message;

  /// Использовать ли пульсирующую анимацию.
  final bool usePulse;

  const AnimatedLoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 4.0,
    this.message,
    this.usePulse = false,
  });

  @override
  State<AnimatedLoadingIndicator> createState() =>
      _AnimatedLoadingIndicatorState();
}

class _AnimatedLoadingIndicatorState extends State<AnimatedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    if (widget.usePulse) {
      _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      );
      _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      );
      _controller.repeat(reverse: true);
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    Widget indicator = SizedBox(
      width: widget.size ?? 40,
      height: widget.size ?? 40,
      child: CircularProgressIndicator(
        strokeWidth: widget.strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );

    if (widget.usePulse) {
      indicator = FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: indicator,
        ),
      );
    }

    if (widget.message != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: 16),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: color,
              fontSize: 14,
            ),
            child: Text(widget.message!),
          ),
        ],
      );
    }

    return indicator;
  }
}

/// Анимированный индикатор загрузки с текстом.
///
/// Упрощенная версия для быстрого использования.
class LoadingWithMessage extends StatelessWidget {
  /// Текст сообщения.
  final String message;

  /// Размер индикатора.
  final double? size;

  const LoadingWithMessage({
    super.key,
    required this.message,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedLoadingIndicator(
            size: size,
            usePulse: true,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
