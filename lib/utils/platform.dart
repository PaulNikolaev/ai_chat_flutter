import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

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
}
