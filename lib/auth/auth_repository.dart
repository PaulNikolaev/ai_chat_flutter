import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/database/database.dart';

/// Репозиторий для работы с данными аутентификации в базе данных.
///
/// Предоставляет методы для сохранения, получения и управления
/// данными аутентификации в таблице `auth` базы данных SQLite.
///
/// Использует простое шифрование API ключа через base64 для базовой защиты.
///
/// Пример использования:
/// ```dart
/// final repository = AuthRepository();
/// await repository.saveAuth(
///   apiKey: 'sk-or-v1-...',
///   pinHash: 'hashed_pin',
///   provider: 'openrouter',
/// );
/// ```
class AuthRepository {
  /// Получает экземпляр базы данных.
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// Шифрует API ключ перед сохранением в БД.
  ///
  /// Использует base64 encoding для базовой защиты.
  /// В будущем можно заменить на более надежное шифрование (AES).
  String _encryptApiKey(String apiKey) {
    final bytes = utf8.encode(apiKey);
    return base64Encode(bytes);
  }

  /// Расшифровывает API ключ после получения из БД.
  ///
  /// Декодирует base64 обратно в исходную строку.
  String _decryptApiKey(String encryptedApiKey) {
    try {
      final bytes = base64Decode(encryptedApiKey);
      return utf8.decode(bytes);
    } catch (e) {
      // Если расшифровка не удалась, возвращаем как есть (для обратной совместимости)
      return encryptedApiKey;
    }
  }

  /// Сохраняет данные аутентификации в базу данных.
  ///
  /// Если запись уже существует, она будет обновлена.
  /// API ключ шифруется перед сохранением.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для сохранения (будет зашифрован).
  /// - [pinHash]: Хэш PIN кода для сохранения.
  /// - [provider]: Провайдер API ('openrouter' или 'vsegpt').
  ///
  /// Возвращает true, если данные сохранены успешно, иначе false.
  Future<bool> saveAuth({
    required String apiKey,
    required String pinHash,
    required String provider,
  }) async {
    try {
      final db = await _db;
      
      // Шифруем API ключ перед сохранением
      final encryptedApiKey = _encryptApiKey(apiKey);
      
      // Проверяем, существует ли уже запись
      final existingRecords = await db.query(
        'auth',
        limit: 1,
      );

      if (existingRecords.isNotEmpty) {
        // Обновляем существующую запись
        final result = await db.update(
          'auth',
          {
            'api_key': encryptedApiKey,
            'pin_hash': pinHash,
            'provider': provider,
            'last_used': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existingRecords.first['id']],
        );
        return result > 0;
      } else {
        // Создаем новую запись
        final result = await db.insert(
          'auth',
          {
            'api_key': encryptedApiKey,
            'pin_hash': pinHash,
            'provider': provider,
            'created_at': DateTime.now().toIso8601String(),
            'last_used': DateTime.now().toIso8601String(),
          },
        );
        return result > 0;
      }
    } catch (e) {
      return false;
    }
  }

  /// Получает все данные аутентификации из базы данных.
  ///
  /// Возвращает Map с ключами 'api_key', 'pin_hash', 'provider'
  /// или null, если данные не найдены.
  /// API ключ автоматически расшифровывается.
  Future<Map<String, String>?> getAuth() async {
    try {
      final db = await _db;
      final records = await db.query(
        'auth',
        limit: 1,
        orderBy: 'id DESC',
      );

      if (records.isEmpty) {
        return null;
      }

      final record = records.first;
      final encryptedApiKey = record['api_key'] as String?;
      
      if (encryptedApiKey == null) {
        return null;
      }

      // Расшифровываем API ключ
      final apiKey = _decryptApiKey(encryptedApiKey);
      final pinHash = record['pin_hash'] as String?;
      final provider = record['provider'] as String?;

      if (pinHash == null || provider == null) {
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

  /// Получает сохраненный API ключ.
  ///
  /// Возвращает расшифрованный API ключ или null, если он не найден.
  Future<String?> getApiKey() async {
    try {
      final auth = await getAuth();
      return auth?['api_key'];
    } catch (e) {
      return null;
    }
  }

  /// Получает сохраненный хэш PIN кода.
  ///
  /// Возвращает хэш PIN или null, если он не найден.
  Future<String?> getPinHash() async {
    try {
      final auth = await getAuth();
      return auth?['pin_hash'];
    } catch (e) {
      return null;
    }
  }

  /// Получает сохраненного провайдера.
  ///
  /// Возвращает 'openrouter' или 'vsegpt', или null, если не найден.
  Future<String?> getProvider() async {
    try {
      final auth = await getAuth();
      return auth?['provider'];
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

  /// Очищает все данные аутентификации из базы данных.
  ///
  /// Удаляет все записи из таблицы `auth`.
  ///
  /// Возвращает true, если данные очищены успешно, иначе false.
  Future<bool> clearAuth() async {
    try {
      final db = await _db;
      final result = await db.delete('auth');
      return result > 0;
    } catch (e) {
      return false;
    }
  }

  /// Проверяет, существуют ли данные аутентификации.
  ///
  /// Возвращает true, если есть сохраненный API ключ и PIN хэш, иначе false.
  Future<bool> hasAuth() async {
    try {
      final auth = await getAuth();
      return auth != null && 
             auth['api_key'] != null && 
             auth['pin_hash'] != null;
    } catch (e) {
      return false;
    }
  }
}
