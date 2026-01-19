import 'package:flutter/material.dart';
import 'styles.dart';

/// Темная тема приложения.
///
/// Определяет цветовую схему, типографику и стили компонентов
/// для темной темы приложения.
class AppTheme {
  AppTheme._();

  /// Темная тема приложения
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Цветовая схема
      colorScheme: const ColorScheme.dark(
        primary: AppStyles.buttonPrimaryColor,
        secondary: AppStyles.accentColor,
        surface: AppStyles.surfaceColor,
        error: AppStyles.errorColor,
        onPrimary: AppStyles.textPrimary,
        onSecondary: AppStyles.textPrimary,
        onSurface: AppStyles.textPrimary,
        onError: AppStyles.textPrimary,
      ),

      // Типографика
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppStyles.textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppStyles.textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppStyles.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppStyles.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppStyles.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppStyles.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: AppStyles.fontSizeDefault,
          color: AppStyles.textPrimary,
          height: AppStyles.lineSpacing,
        ),
        bodyMedium: TextStyle(
          fontSize: AppStyles.fontSizeDefault,
          color: AppStyles.textPrimary,
          height: AppStyles.lineSpacing,
        ),
        bodySmall: TextStyle(
          fontSize: AppStyles.fontSizeHint,
          color: AppStyles.textSecondary,
          height: AppStyles.lineSpacing,
        ),
        labelLarge: TextStyle(
          fontSize: AppStyles.fontSizeDefault,
          fontWeight: FontWeight.w500,
          color: AppStyles.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: AppStyles.fontSizeHint,
          color: AppStyles.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          color: AppStyles.textSecondary,
        ),
      ),

      // Стили компонентов
      scaffoldBackgroundColor: AppStyles.backgroundColor,
      cardColor: AppStyles.cardColor,
      dividerColor: AppStyles.borderColor,

      // Стили полей ввода
      inputDecorationTheme: AppStyles.inputDecorationTheme,

      // Стили кнопок
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppStyles.sendButtonStyle,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppStyles.textPrimary,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppStyles.textPrimary,
          side: const BorderSide(color: AppStyles.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          ),
        ),
      ),

      // Стили карточек
      cardTheme: CardThemeData(
        color: AppStyles.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          side: const BorderSide(color: AppStyles.borderColor, width: 1),
        ),
      ),

      // Стили диалогов
      dialogTheme: DialogThemeData(
        backgroundColor: AppStyles.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusLarge),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppStyles.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: AppStyles.fontSizeDefault,
          color: AppStyles.textPrimary,
        ),
      ),

      // Стили AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppStyles.cardColor,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppStyles.textPrimary,
        ),
      ),

      // Стили BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppStyles.cardColor,
        selectedItemColor: AppStyles.accentColor,
        unselectedItemColor: AppStyles.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),

      // Стили FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppStyles.buttonPrimaryColor,
        foregroundColor: AppStyles.textPrimary,
      ),

      // Стили Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppStyles.cardColor,
      ),

      // Стили ListTile
      listTileTheme: const ListTileThemeData(
        textColor: AppStyles.textPrimary,
        iconColor: AppStyles.textSecondary,
      ),

      // Стили Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppStyles.surfaceColor,
        deleteIconColor: AppStyles.textPrimary,
        labelStyle: const TextStyle(color: AppStyles.textPrimary),
        secondaryLabelStyle: const TextStyle(color: AppStyles.textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppStyles.paddingSmall,
          vertical: 4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          side: const BorderSide(color: AppStyles.borderColor),
        ),
      ),

      // Стили Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppStyles.accentColor;
          }
          return AppStyles.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppStyles.accentColor.withValues(alpha: 0.5);
          }
          return AppStyles.surfaceColor;
        }),
      ),

      // Стили Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppStyles.accentColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppStyles.textPrimary),
        side: const BorderSide(color: AppStyles.borderColor),
      ),

      // Стили Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppStyles.accentColor;
          }
          return AppStyles.textSecondary;
        }),
      ),

      // Стили Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: AppStyles.accentColor,
        inactiveTrackColor: AppStyles.surfaceColor,
        thumbColor: AppStyles.accentColor,
        overlayColor: AppStyles.accentColor.withValues(alpha: 0.2),
      ),

      // Стили ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppStyles.accentColor,
        linearTrackColor: AppStyles.surfaceColor,
        circularTrackColor: AppStyles.surfaceColor,
      ),

      // Стили Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppStyles.cardColor,
        contentTextStyle: const TextStyle(color: AppStyles.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Стили Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppStyles.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          border: Border.all(color: AppStyles.borderColor),
        ),
        textStyle: const TextStyle(
          color: AppStyles.textPrimary,
          fontSize: AppStyles.fontSizeHint,
        ),
      ),
    );
  }
}
