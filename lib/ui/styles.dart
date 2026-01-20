import 'package:flutter/material.dart';
import 'package:ai_chat/utils/utils.dart';

/// Централизованные стили приложения.
///
/// Содержит константы стилей для всех визуальных элементов UI.
/// Обеспечивает единообразное оформление и упрощает управление темами.
class AppStyles {
  AppStyles._();

  // ==================== Цветовая палитра ====================

  /// Основной цвет фона (темный)
  static const Color backgroundColor = Color(0xFF121212); // GREY_900

  /// Цвет фона вторичных элементов
  static const Color surfaceColor = Color(0xFF1E1E1E); // GREY_800

  /// Цвет фона карточек и контейнеров
  static const Color cardColor = Color(0xFF2D2D2D); // GREY_900 variant

  /// Основной цвет текста
  static const Color textPrimary = Colors.white;

  /// Вторичный цвет текста
  static const Color textSecondary = Color(0xFFB0B0B0); // GREY_400

  /// Цвет границ
  static const Color borderColor = Color(0xFF424242); // GREY_700

  /// Акцентный цвет (синий)
  static const Color accentColor = Color(0xFF42A5F5); // BLUE_400

  /// Акцентный цвет кнопок (темно-синий)
  static const Color buttonPrimaryColor = Color(0xFF1976D2); // BLUE_700

  /// Цвет успеха (зеленый)
  static const Color successColor = Color(0xFF66BB6A); // GREEN_400

  /// Цвет предупреждения (оранжевый)
  static const Color warningColor = Color(0xFFE65100); // ORANGE_700

  /// Цвет ошибки (красный)
  static const Color errorColor = Color(0xFFD32F2F); // RED_700

  // ==================== Размеры и отступы ====================

  /// Стандартный отступ
  static const double padding = 20.0;

  /// Малый отступ
  static const double paddingSmall = 10.0;

  /// Большой отступ
  static const double paddingLarge = 30.0;

  /// Радиус скругления углов
  static const double borderRadius = 8.0;

  /// Большой радиус скругления
  static const double borderRadiusLarge = 10.0;

  /// Высота кнопок (базовая)
  static const double buttonHeight = 40.0;

  /// Высота кнопок на мобильных устройствах (увеличена для удобства)
  static const double buttonHeightMobile = 48.0;

  /// Высота кнопок на планшетах
  static const double buttonHeightTablet = 44.0;

  /// Высота полей ввода (базовая)
  static const double inputHeight = 50.0;

  /// Высота полей ввода на мобильных устройствах (увеличена для удобства)
  static const double inputHeightMobile = 56.0;

  /// Высота полей ввода на планшетах
  static const double inputHeightTablet = 52.0;

  /// Высота поля поиска
  static const double searchFieldHeight = 45.0;

  /// Ширина кнопок по умолчанию (десктоп)
  static const double buttonWidth = 130.0;

  /// Ширина полей ввода по умолчанию (десктоп)
  static const double inputWidth = 400.0;

  /// Ширина поля поиска (десктоп)
  static const double searchFieldWidth = 400.0;

  /// Ширина строки ввода (десктоп)
  static const double inputRowWidth = 920.0;

  /// Ширина окна входа (десктоп)
  static const double loginWindowWidth = 500.0;

  /// Высота истории чата (десктоп)
  static const double chatHistoryHeight = 400.0;

  /// Ширина окна приложения (десктоп)
  static const double windowWidth = 600.0;

  /// Высота окна приложения (десктоп)
  static const double windowHeight = 800.0;

  // ==================== Типографика ====================

  /// Размер шрифта по умолчанию
  static const double fontSizeDefault = 16.0;

  /// Размер шрифта для баланса
  static const double fontSizeBalance = 16.0;

  /// Размер шрифта для подсказок
  static const double fontSizeHint = 14.0;

  /// Межстрочный интервал
  static const double lineSpacing = 1.2;

  // ==================== Адаптивные методы ====================

  /// Получает адаптивную ширину для десктопных платформ.
  ///
  /// На мобильных платформах возвращает null для автоматического размера.
  static double? getResponsiveWidth(double defaultWidth) {
    return PlatformUtils.isMobile() ? null : defaultWidth;
  }

  /// Получает адаптивную высоту истории чата.
  ///
  /// На мобильных платформах возвращает null для автоматического размера.
  static double? getChatHistoryHeight() {
    return PlatformUtils.isMobile() ? null : chatHistoryHeight;
  }

  /// Получает адаптивную ширину для строки ввода.
  ///
  /// На мобильных платформах возвращает null для автоматического размера.
  static double? getInputRowWidth() {
    return PlatformUtils.isMobile() ? null : inputRowWidth;
  }

  /// Получает адаптивную высоту кнопки на основе размера экрана.
  ///
  /// Возвращает увеличенную высоту для мобильных устройств и планшетов.
  static double getButtonHeight(BuildContext context) {
    final screenSize = PlatformUtils.getScreenSize(context);
    switch (screenSize) {
      case 'small':
        return buttonHeightMobile;
      case 'medium':
        return buttonHeightTablet;
      default:
        return buttonHeight;
    }
  }

  /// Получает адаптивную высоту поля ввода на основе размера экрана.
  ///
  /// Возвращает увеличенную высоту для мобильных устройств и планшетов.
  static double getInputHeight(BuildContext context) {
    final screenSize = PlatformUtils.getScreenSize(context);
    switch (screenSize) {
      case 'small':
        return inputHeightMobile;
      case 'medium':
        return inputHeightTablet;
      default:
        return inputHeight;
    }
  }

  /// Получает адаптивный отступ на основе размера экрана.
  ///
  /// Возвращает большие отступы для больших экранов и меньшие для мобильных.
  static double getPadding(BuildContext context) {
    final screenSize = PlatformUtils.getScreenSize(context);
    switch (screenSize) {
      case 'small':
        return paddingSmall;
      case 'medium':
        return padding;
      default:
        return paddingLarge;
    }
  }

  /// Получает максимальную ширину контента для планшетов.
  ///
  /// Используется для ограничения ширины контента на планшетах
  /// для лучшей читаемости.
  static double? getMaxContentWidth(BuildContext context) {
    final screenSize = PlatformUtils.getScreenSize(context);
    if (screenSize == 'medium') {
      return 800.0; // Оптимальная ширина для планшетов
    }
    return null;
  }

  // ==================== Стили компонентов ====================

  /// Стиль для текста баланса
  static const TextStyle balanceTextStyle = TextStyle(
    fontSize: fontSizeBalance,
    color: successColor,
    fontWeight: FontWeight.bold,
  );

  /// Стиль для основного текста
  static const TextStyle primaryTextStyle = TextStyle(
    fontSize: fontSizeDefault,
    color: textPrimary,
  );

  /// Стиль для вторичного текста
  static const TextStyle secondaryTextStyle = TextStyle(
    fontSize: fontSizeDefault,
    color: textSecondary,
  );

  /// Стиль для подсказок
  static const TextStyle hintTextStyle = TextStyle(
    fontSize: fontSizeHint,
    color: textSecondary,
  );

  /// Стиль для кнопок
  static ButtonStyle getButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.all(
        backgroundColor ?? buttonPrimaryColor,
      ),
      foregroundColor: WidgetStateProperty.all(
        foregroundColor ?? textPrimary,
      ),
      padding: WidgetStateProperty.all(
        padding ?? const EdgeInsets.all(paddingSmall),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Стиль для кнопки отправки
  static ButtonStyle get sendButtonStyle => getButtonStyle(
        backgroundColor: buttonPrimaryColor,
        foregroundColor: textPrimary,
      );

  /// Стиль для кнопки сохранения
  static ButtonStyle get saveButtonStyle => getButtonStyle(
        backgroundColor: buttonPrimaryColor,
        foregroundColor: textPrimary,
      );

  /// Стиль для кнопки очистки
  static ButtonStyle get clearButtonStyle => getButtonStyle(
        backgroundColor: errorColor,
        foregroundColor: textPrimary,
      );

  /// Стиль для кнопки аналитики
  static ButtonStyle get analyticsButtonStyle => getButtonStyle(
        backgroundColor: successColor,
        foregroundColor: textPrimary,
      );

  /// Стиль для кнопки выхода
  static ButtonStyle get logoutButtonStyle => getButtonStyle(
        backgroundColor: warningColor,
        foregroundColor: textPrimary,
      );

  /// Стиль для поля ввода
  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: accentColor, width: 2.0),
        ),
        hintStyle: hintTextStyle,
        contentPadding: const EdgeInsets.all(paddingSmall),
      );

  /// Стиль для контейнера баланса
  static BoxDecoration get balanceContainerDecoration => BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.0),
      );

  /// Стиль для окна входа
  static BoxDecoration get loginWindowDecoration => BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        border: Border.all(color: borderColor, width: 1.0),
      );
}
