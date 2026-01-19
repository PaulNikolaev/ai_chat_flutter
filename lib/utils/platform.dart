import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Утилиты для определения платформы, на которой запущено приложение.
class PlatformUtils {
  /// Определяет, запущено ли приложение на мобильной платформе (Android или iOS).
  ///
  /// Возвращает `true`, если приложение работает на Android или iOS.
  ///
  /// Пример использования:
  /// ```dart
  /// if (PlatformUtils.isMobile()) {
  ///   // Мобильная версия UI
  /// }
  /// ```
  static bool isMobile() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Определяет, запущено ли приложение на десктопной платформе.
  ///
  /// Возвращает `true`, если приложение работает на Windows, Linux или macOS.
  ///
  /// Пример использования:
  /// ```dart
  /// if (PlatformUtils.isDesktop()) {
  ///   // Десктопная версия UI
  /// }
  /// ```
  static bool isDesktop() {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Определяет, запущено ли приложение в веб-браузере.
  ///
  /// Возвращает `true`, если приложение работает в веб-версии.
  ///
  /// Пример использования:
  /// ```dart
  /// if (PlatformUtils.isWeb()) {
  ///   // Веб-версия UI
  /// }
  /// ```
  static bool isWeb() {
    return kIsWeb;
  }

  /// Определяет конкретную платформу.
  ///
  /// Возвращает строку с названием платформы:
  /// - "android" для Android
  /// - "ios" для iOS
  /// - "windows" для Windows
  /// - "linux" для Linux
  /// - "macos" для macOS
  /// - "web" для веб-версии
  /// - "unknown" для неизвестной платформы
  ///
  /// Пример использования:
  /// ```dart
  /// final platform = PlatformUtils.getPlatform();
  /// debugPrint('Текущая платформа: $platform');
  /// ```
  static String getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  /// Определяет размер экрана на основе ширины.
  ///
  /// Возвращает:
  /// - "small" для маленьких экранов (< 600px) - телефоны
  /// - "medium" для средних экранов (600-1024px) - планшеты
  /// - "large" для больших экранов (> 1024px) - десктопы
  ///
  /// Пример использования:
  /// ```dart
  /// final screenSize = PlatformUtils.getScreenSize(context);
  /// if (screenSize == 'medium') {
  ///   // Layout для планшета
  /// }
  /// ```
  static String getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return 'small';
    } else if (width < 1024) {
      return 'medium';
    } else {
      return 'large';
    }
  }

  /// Определяет, является ли экран планшетом.
  ///
  /// Возвращает `true`, если ширина экрана между 600 и 1024 пикселями.
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == 'medium';
  }

  /// Определяет ориентацию экрана.
  ///
  /// Возвращает:
  /// - "portrait" для портретной ориентации
  /// - "landscape" для альбомной ориентации
  static String getOrientation(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height ? 'landscape' : 'portrait';
  }

  /// Определяет, находится ли экран в альбомной ориентации.
  static bool isLandscape(BuildContext context) {
    return getOrientation(context) == 'landscape';
  }
}
