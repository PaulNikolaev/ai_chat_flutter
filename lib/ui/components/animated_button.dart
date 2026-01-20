import 'package:flutter/material.dart';

/// Анимированная кнопка с улучшенной обратной связью.
///
/// Предоставляет плавные анимации при нажатии и hover эффекты для десктопных платформ.
/// Использует scale анимацию для тактильной обратной связи.
///
/// **Пример использования:**
/// ```dart
/// AnimatedButton(
///   onPressed: () => print('Нажато'),
///   useScaleAnimation: true,
///   child: Text('Нажми меня'),
/// )
/// ```
class AnimatedButton extends StatefulWidget {
  /// Виджет-ребенок кнопки.
  final Widget child;

  /// Callback при нажатии.
  final VoidCallback? onPressed;

  /// Стиль кнопки.
  final ButtonStyle? style;

  /// Использовать ли scale анимацию при нажатии.
  final bool useScaleAnimation;

  /// Использовать ли ripple эффект.
  final bool useRipple;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.useScaleAnimation = true,
    this.useRipple = true,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.useScaleAnimation) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.useScaleAnimation) {
      _controller.reverse();
    }
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (widget.useScaleAnimation) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget button = widget.useScaleAnimation
        ? ScaleTransition(
            scale: _scaleAnimation,
            child: widget.child,
          )
        : widget.child;

    if (widget.useRipple && widget.onPressed != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(8),
            child: button,
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: button,
    );
  }
}

/// Анимированная иконка-кнопка с hover эффектом.
class AnimatedIconButton extends StatefulWidget {
  /// Иконка кнопки.
  final IconData icon;

  /// Callback при нажатии.
  final VoidCallback? onPressed;

  /// Подсказка для кнопки.
  final String? tooltip;

  /// Размер иконки.
  final double? iconSize;

  /// Цвет иконки.
  final Color? color;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconSize,
    this.color,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget iconButton = ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(widget.icon),
        iconSize: widget.iconSize,
        color: widget.color,
        onPressed: widget.onPressed,
        tooltip: widget.tooltip,
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        _controller.forward();
      },
      onExit: (_) {
        _controller.reverse();
      },
      child: iconButton,
    );
  }
}
