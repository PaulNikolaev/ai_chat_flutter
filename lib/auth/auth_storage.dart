import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_repository.dart';

/// Ключи для хранения данных аутентификации (для миграции из старых хранилищ).
class _AuthKeys {
  static const String apiKey = 'api_key';
  static const String pinHash = 'pin_hash';
  static const String provider = 'provider'; // 'openrouter' или 'vsegpt'
}

/// Хранилище данных аутентификации.
///
/// Предоставляет единый интерфейс для работы с данными аутентификации,
/// абстрагируя детали реализации хранения.
///
/// **Основные возможности:**
/// - Сохранение и получение API ключей (с автоматическим шифрованием)
/// - Сохранение и проверка PIN кодов (с хэшированием через SHA-256)
/// - Хранение информации о провайдере (OpenRouter/VSEGPT)
/// - Автоматическая миграция данных из старых хранилищ
///
/// **Архитектура:**
/// - Использует `AuthRepository` для работы с базой данных SQLite
/// - Выполняет автоматическую миграцию данных из старых хранилищ:
///   - `flutter_secure_storage` для API ключей
///   - `shared_preferences` для PIN хэшей и провайдеров
/// - Миграция выполняется автоматически при первом обращении к данным
///
/// **Безопасность:**
/// - API ключи шифруются через AES-256-CBC перед сохранением в БД
/// - Ключ шифрования хранится в flutter_secure_storage
/// - PIN коды хэшируются через SHA-256, исходные значения не сохраняются
/// - Данные хранятся в локальной SQLite базе данных в защищенной директории приложения
/// - Автоматическая миграция данных из Base64 в AES при первом обращении
/// - Миграция данных из старых хранилищ выполняется безопасно с последующей очисткой
///
/// **Пример использования:**
/// ```dart
/// final storage = AuthStorage();
///
/// // Сохранение данных
/// await storage.saveAuth(
///   apiKey: 'sk-or-v1-...',
///   pinHash: AuthStorage.hashPin('1234'),
///   provider: 'openrouter',
/// );
///
/// // Получение API ключа
/// final apiKey = await storage.getApiKey();
///
/// // Проверка PIN
/// final isValid = await storage.verifyPin('1234');
/// ```
class AuthStorage {
  /// Репозиторий для работы с базой данных SQLite.
  ///
  /// Используется для всех операций с данными аутентификации.
  /// Автоматически шифрует/расшифровывает API ключи через AES-256-CBC.
  /// Выполняет автоматическую миграцию данных из Base64 в AES при первом обращении.
  final AuthRepository _repository;

  /// Безопасное хранилище для миграции старых данных (опционально).
  ///
  /// Используется только для миграции API ключей из flutter_secure_storage.
  /// После миграции данные удаляются из этого хранилища.
  final FlutterSecureStorage? _legacySecureStorage;

  /// Предпочтения для миграции старых данных (опционально).
  ///
  /// Используется только для миграции PIN хэшей и провайдеров из shared_preferences.
  /// Инициализируется лениво при необходимости.
  SharedPreferences? _legacyPrefs;

  /// Флаг, указывающий, была ли выполнена миграция.
  ///
  /// Предотвращает повторную попытку миграции при каждом обращении к данным.
  bool _migrationCompleted = false;

  /// Создает экземпляр [AuthStorage].
  ///
  /// Параметры:
  /// - [repository]: Репозиторий для работы с БД (опционально, создается новый по умолчанию).
  /// - [secureStorage]: Безопасное хранилище для миграции (опционально).
  AuthStorage({
    AuthRepository? repository,
    FlutterSecureStorage? secureStorage,
  })  : _repository = repository ?? AuthRepository(),
        _legacySecureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Инициализирует SharedPreferences для миграции (вызывается автоматически при необходимости).
  Future<void> _ensureLegacyPrefs() async {
    _legacyPrefs ??= await SharedPreferences.getInstance();
  }

  /// Выполняет миграцию данных из старых хранилищ в базу данных.
  ///
  /// Проверяет наличие данных в flutter_secure_storage и shared_preferences,
  /// и если они найдены, переносит их в БД через AuthRepository.
  ///
  /// Возвращает true, если миграция выполнена или не требуется, иначе false.
  Future<bool> _migrateLegacyData() async {
    if (_migrationCompleted) {
      return true;
    }

    try {
      // Проверяем, есть ли уже данные в БД
      final hasDbData = await _repository.hasAuth();
      if (hasDbData) {
        _migrationCompleted = true;
        return true;
      }

      // Проверяем наличие данных в старых хранилищах
      await _ensureLegacyPrefs();

      final legacyApiKey =
          await _legacySecureStorage?.read(key: _AuthKeys.apiKey);
      final legacyPinHash = _legacyPrefs?.getString(_AuthKeys.pinHash);
      final legacyProvider = _legacyPrefs?.getString(_AuthKeys.provider);

      // Если есть данные в старых хранилищах, мигрируем их
      if (legacyApiKey != null &&
          legacyPinHash != null &&
          legacyProvider != null) {
        final migrated = await _repository.saveAuth(
          apiKey: legacyApiKey,
          pinHash: legacyPinHash,
          provider: legacyProvider,
        );

        if (migrated) {
          // Очищаем старые хранилища после успешной миграции
          await _legacySecureStorage?.delete(key: _AuthKeys.apiKey);
          await _legacyPrefs?.remove(_AuthKeys.pinHash);
          await _legacyPrefs?.remove(_AuthKeys.provider);
        }

        _migrationCompleted = true;
        return migrated;
      }

      _migrationCompleted = true;
      return true;
    } catch (e) {
      // В случае ошибки миграции продолжаем работу с БД
      _migrationCompleted = true;
      return false;
    }
  }

  /// Сохраняет данные аутентификации.
  ///
  /// Данные сохраняются в базу данных через AuthRepository.
  /// API ключ автоматически шифруется перед сохранением.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для хранения (будет зашифрован и сохранен в БД).
  /// - [pinHash]: Хэш PIN кода для хранения (должен быть уже захеширован).
  /// - [provider]: Провайдер API ('openrouter' или 'vsegpt').
  ///
  /// Возвращает true, если данные сохранены успешно, иначе false.
  Future<bool> saveAuth({
    required String apiKey,
    required String pinHash,
    required String provider,
  }) async {
    try {
      await _migrateLegacyData();
      return await _repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );
    } catch (e) {
      return false;
    }
  }

  /// Получает сохраненный API ключ для указанного провайдера.
  ///
  /// Параметры:
  /// - [provider]: Провайдер для получения ключа (опционально, если null - возвращает активный).
  ///
  /// Возвращает расшифрованный API ключ или null, если он не найден.
  Future<String?> getApiKey({String? provider}) async {
    try {
      await _migrateLegacyData();
      return await _repository.getApiKey(provider: provider);
    } catch (e) {
      return null;
    }
  }

  /// Получает все сохраненные API ключи.
  ///
  /// Возвращает список Map, каждый содержит 'api_key', 'provider', 'created_at', 'last_used'.
  Future<List<Map<String, String>>> getAllApiKeys() async {
    try {
      await _migrateLegacyData();
      return await _repository.getAllAuthKeys();
    } catch (e) {
      return [];
    }
  }

  /// Удаляет API ключ для указанного провайдера.
  ///
  /// Параметры:
  /// - [provider]: Провайдер для удаления ключа.
  ///
  /// Возвращает true, если удаление выполнено успешно.
  Future<bool> deleteApiKey(String provider) async {
    try {
      await _migrateLegacyData();
      return await _repository.deleteApiKey(provider);
    } catch (e) {
      return false;
    }
  }

  /// Обновляет дату последнего использования для указанного провайдера.
  ///
  /// Параметры:
  /// - [provider]: Провайдер для обновления.
  ///
  /// Возвращает true, если обновление выполнено успешно.
  Future<bool> updateLastUsed(String provider) async {
    try {
      await _migrateLegacyData();
      return await _repository.updateLastUsed(provider);
    } catch (e) {
      return false;
    }
  }

  /// Получает сохраненный хэш PIN кода.
  ///
  /// Возвращает хэш PIN или null, если он не найден.
  Future<String?> getPinHash() async {
    try {
      await _migrateLegacyData();
      return await _repository.getPinHash();
    } catch (e) {
      return null;
    }
  }

  /// Получает сохраненного провайдера.
  ///
  /// Возвращает 'openrouter' или 'vsegpt', или null, если не найден.
  Future<String?> getProvider() async {
    try {
      await _migrateLegacyData();
      return await _repository.getProvider();
    } catch (e) {
      return null;
    }
  }

  /// Получает все данные аутентификации.
  ///
  /// Возвращает Map с ключами 'api_key', 'pin_hash', 'provider'
  /// или null, если данные не найдены.
  /// API ключ автоматически расшифровывается.
  Future<Map<String, String>?> getAuth() async {
    try {
      await _migrateLegacyData();
      return await _repository.getAuth();
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
      await _migrateLegacyData();
      return await _repository.verifyPin(pin);
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
  /// Удаляет данные из базы данных через AuthRepository.
  /// Также очищает старые хранилища для полной очистки.
  ///
  /// Возвращает true, если данные очищены успешно, иначе false.
  Future<bool> clearAuth() async {
    try {
      // Выполняем миграцию, если нужно (может выбросить исключение)
      try {
        await _migrateLegacyData();
      } catch (_) {
        // Игнорируем ошибки миграции при очистке
      }

      // Очищаем данные из БД
      final dbCleared = await _repository.clearAuth();

      // Также очищаем старые хранилища на всякий случай
      try {
        await _legacySecureStorage?.delete(key: _AuthKeys.apiKey);
        await _ensureLegacyPrefs();
        await _legacyPrefs?.remove(_AuthKeys.pinHash);
        await _legacyPrefs?.remove(_AuthKeys.provider);
      } catch (_) {
        // Игнорируем ошибки очистки старых хранилищ
      }

      return dbCleared;
    } catch (e) {
      return false;
    }
  }

  /// Проверяет, существуют ли данные аутентификации.
  ///
  /// Возвращает true, если есть сохраненный API ключ и PIN хэш, иначе false.
  Future<bool> hasAuth() async {
    try {
      await _migrateLegacyData();
      return await _repository.hasAuth();
    } catch (e) {
      return false;
    }
  }
}
