import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ключи для хранения данных аутентификации.
class _AuthKeys {
  static const String apiKey = 'api_key';
  static const String pinHash = 'pin_hash';
  static const String provider = 'provider'; // 'openrouter' или 'vsegpt'
}

/// Хранилище данных аутентификации.
///
/// Использует:
/// - `flutter_secure_storage` для безопасного хранения API ключа
/// - `shared_preferences` для хранения хэша PIN кода
///
/// Пример использования:
/// ```dart
/// final storage = AuthStorage();
/// await storage.saveAuth(
///   apiKey: 'sk-or-v1-...',
///   pinHash: 'hashed_pin',
///   provider: 'openrouter',
/// );
/// ```
class AuthStorage {
  /// Безопасное хранилище для API ключа.
  final FlutterSecureStorage _secureStorage;

  /// Предпочтения для хранения PIN хэша.
  SharedPreferences? _prefs;

  /// Создает экземпляр [AuthStorage].
  AuthStorage({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Инициализирует SharedPreferences (вызывается автоматически при первом использовании).
  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Сохраняет данные аутентификации.
  ///
  /// API ключ сохраняется в безопасном хранилище,
  /// PIN хэш сохраняется в SharedPreferences.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для хранения (будет сохранен в безопасном хранилище).
  /// - [pinHash]: Хэш PIN кода для хранения.
  /// - [provider]: Провайдер API ('openrouter' или 'vsegpt').
  ///
  /// Возвращает true, если данные сохранены успешно, иначе false.
  Future<bool> saveAuth({
    required String apiKey,
    required String pinHash,
    required String provider,
  }) async {
    try {
      await _ensurePrefs();
      
      // Сохраняем API ключ в безопасном хранилище
      await _secureStorage.write(
        key: _AuthKeys.apiKey,
        value: apiKey,
      );

      // Сохраняем PIN хэш в SharedPreferences
      await _prefs!.setString(_AuthKeys.pinHash, pinHash);
      
      // Сохраняем провайдера
      await _prefs!.setString(_AuthKeys.provider, provider);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Получает сохраненный API ключ.
  ///
  /// Возвращает API ключ или null, если он не найден.
  Future<String?> getApiKey() async {
    try {
      return await _secureStorage.read(key: _AuthKeys.apiKey);
    } catch (e) {
      return null;
    }
  }

  /// Получает сохраненный хэш PIN кода.
  ///
  /// Возвращает хэш PIN или null, если он не найден.
  Future<String?> getPinHash() async {
    try {
      await _ensurePrefs();
      return _prefs!.getString(_AuthKeys.pinHash);
    } catch (e) {
      return null;
    }
  }

  /// Получает сохраненного провайдера.
  ///
  /// Возвращает 'openrouter' или 'vsegpt', или null, если не найден.
  Future<String?> getProvider() async {
    try {
      await _ensurePrefs();
      return _prefs!.getString(_AuthKeys.provider);
    } catch (e) {
      return null;
    }
  }

  /// Получает все данные аутентификации.
  ///
  /// Возвращает Map с ключами 'api_key', 'pin_hash', 'provider'
  /// или null, если данные не найдены.
  Future<Map<String, String>?> getAuth() async {
    try {
      final apiKey = await getApiKey();
      final pinHash = await getPinHash();
      final provider = await getProvider();

      if (apiKey == null || pinHash == null || provider == null) {
        return null;
      }

      return {
        'api_key': apiKey,
        'pin_hash': pinHash,
        'provider': provider,
      };
    } catch (e) {
      return null;
    }
  }

  /// Проверяет PIN код против сохраненного хэша.
  ///
  /// PIN хэшируется через SHA256 и сравнивается с сохраненным хэшем.
  ///
  /// Параметры:
  /// - [pin]: PIN код для проверки.
  ///
  /// Возвращает true, если PIN валиден, иначе false.
  Future<bool> verifyPin(String pin) async {
    try {
      final storedHash = await getPinHash();
      if (storedHash == null) {
        return false;
      }

      // Хэшируем введенный PIN через SHA256
      final bytes = utf8.encode(pin);
      final digest = sha256.convert(bytes);
      final inputHash = digest.toString();

      return inputHash == storedHash;
    } catch (e) {
      return false;
    }
  }

  /// Хэширует PIN код через SHA256.
  ///
  /// Используется для создания хэша PIN перед сохранением.
  ///
  /// Параметры:
  /// - [pin]: PIN код для хэширования.
  ///
  /// Возвращает хэш PIN в виде строки.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Очищает все данные аутентификации.
  ///
  /// Удаляет API ключ из безопасного хранилища
  /// и PIN хэш из SharedPreferences.
  ///
  /// Возвращает true, если данные очищены успешно, иначе false.
  Future<bool> clearAuth() async {
    try {
      await _ensurePrefs();
      
      // Удаляем API ключ из безопасного хранилища
      await _secureStorage.delete(key: _AuthKeys.apiKey);
      
      // Удаляем PIN хэш из SharedPreferences
      await _prefs!.remove(_AuthKeys.pinHash);
      
      // Удаляем провайдера
      await _prefs!.remove(_AuthKeys.provider);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Проверяет, существуют ли данные аутентификации.
  ///
  /// Возвращает true, если есть сохраненный API ключ и PIN хэш, иначе false.
  Future<bool> hasAuth() async {
    try {
      final apiKey = await getApiKey();
      final pinHash = await getPinHash();
      return apiKey != null && pinHash != null;
    } catch (e) {
      return false;
    }
  }
}
