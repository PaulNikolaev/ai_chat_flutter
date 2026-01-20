import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для работы с пользовательскими настройками.
///
/// Предоставляет единую точку доступа к SharedPreferences для хранения
/// пользовательских настроек приложения. Использует Singleton паттерн
/// для единообразного доступа к настройкам.
///
/// **Пример использования:**
/// ```dart
/// final prefs = PreferencesService.instance;
/// await prefs.saveString('key', 'value');
/// final value = await prefs.getString('key');
/// ```
class PreferencesService {
  /// Единственный экземпляр PreferencesService (Singleton).
  static final PreferencesService instance = PreferencesService._internal();

  /// Внутренний конструктор для Singleton.
  PreferencesService._internal();

  /// Кэш экземпляра SharedPreferences.
  SharedPreferences? _prefs;

  /// Получает экземпляр SharedPreferences, создавая его при необходимости.
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Сохраняет строковое значение по ключу.
  ///
  /// Параметры:
  /// - [key]: Ключ для сохранения значения.
  /// - [value]: Значение для сохранения.
  ///
  /// Возвращает true, если значение успешно сохранено.
  Future<bool> saveString(String key, String value) async {
    try {
      final prefs = await _preferences;
      return await prefs.setString(key, value);
    } catch (e) {
      return false;
    }
  }

  /// Получает строковое значение по ключу.
  ///
  /// Параметры:
  /// - [key]: Ключ для получения значения.
  ///
  /// Возвращает сохраненное значение или null, если ключ не найден.
  Future<String?> getString(String key) async {
    try {
      final prefs = await _preferences;
      return prefs.getString(key);
    } catch (e) {
      return null;
    }
  }

  /// Удаляет значение по ключу.
  ///
  /// Параметры:
  /// - [key]: Ключ для удаления.
  ///
  /// Возвращает true, если значение успешно удалено.
  Future<bool> remove(String key) async {
    try {
      final prefs = await _preferences;
      return await prefs.remove(key);
    } catch (e) {
      return false;
    }
  }

  /// Очищает все настройки.
  ///
  /// Возвращает true, если настройки успешно очищены.
  Future<bool> clear() async {
    try {
      final prefs = await _preferences;
      return await prefs.clear();
    } catch (e) {
      return false;
    }
  }

  /// Проверяет, существует ли ключ в настройках.
  ///
  /// Параметры:
  /// - [key]: Ключ для проверки.
  ///
  /// Возвращает true, если ключ существует.
  Future<bool> containsKey(String key) async {
    try {
      final prefs = await _preferences;
      return prefs.containsKey(key);
    } catch (e) {
      return false;
    }
  }
}
