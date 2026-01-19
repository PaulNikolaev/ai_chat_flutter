import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/database/database.dart';

/// Репозиторий для работы с данными аутентификации в базе данных.
///
/// Предоставляет методы для сохранения, получения и управления
/// данными аутентификации в таблице `auth` базы данных SQLite.
///
/// **Оптимизации производительности:**
/// - Использует транзакции для атомарных операций
/// - Выполняет прямые запросы к нужным полям вместо полного getAuth()
/// - Использует COUNT запросы для быстрой проверки наличия данных
/// - Минимизирует количество обращений к базе данных
///
/// **Безопасность:**
/// - API ключи шифруются через base64 перед сохранением
/// - PIN коды хранятся только в виде хэшей (SHA-256)
/// - Исходные значения PIN никогда не сохраняются
///
/// **Структура данных:**
/// - Таблица `auth` содержит только одну запись
/// - Поля: `id`, `api_key` (зашифрован), `pin_hash`, `provider`, `created_at`, `last_used`
/// - При обновлении данных сохраняется оригинальная дата создания
///
/// **Пример использования:**
/// ```dart
/// final repository = AuthRepository();
/// 
/// // Сохранение данных
/// await repository.saveAuth(
///   apiKey: 'sk-or-v1-...',
///   pinHash: AuthRepository.hashPin('1234'),
///   provider: 'openrouter',
/// );
/// 
/// // Получение API ключа
/// final apiKey = await repository.getApiKey();
/// 
/// // Проверка PIN
/// final isValid = await repository.verifyPin('1234');
/// 
/// // Проверка наличия данных
/// final hasAuth = await repository.hasAuth();
/// ```
class AuthRepository {
  /// Получает экземпляр базы данных.
  ///
  /// Использует singleton DatabaseHelper для получения соединения с БД.
  /// Соединение создается при первом обращении и переиспользуется.
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
  /// Оптимизировано: использует транзакцию и оптимизированный запрос
  /// для уменьшения количества обращений к БД.
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
      final now = DateTime.now().toIso8601String();
      
      // Используем транзакцию для атомарности операции
      return await db.transaction((txn) async {
        // Проверяем существование записи одним запросом
        final existing = await txn.query(
          'auth',
          columns: ['id', 'created_at'],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          // Обновляем существующую запись, сохраняя created_at
          final existingId = existing.first['id'] as int;
          final existingCreatedAt = existing.first['created_at'] as String?;
          
          final result = await txn.update(
            'auth',
            {
              'api_key': encryptedApiKey,
              'pin_hash': pinHash,
              'provider': provider,
              'created_at': existingCreatedAt ?? now, // Сохраняем оригинальную дату создания
              'last_used': now,
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
          return result > 0;
        } else {
          // Создаем новую запись
          final result = await txn.insert(
            'auth',
            {
              'api_key': encryptedApiKey,
              'pin_hash': pinHash,
              'provider': provider,
              'created_at': now,
              'last_used': now,
            },
          );
          return result > 0;
        }
      });
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
  /// Оптимизировано: выполняет прямой запрос к нужному полю вместо полного getAuth().
  ///
  /// Возвращает расшифрованный API ключ или null, если он не найден.
  Future<String?> getApiKey() async {
    try {
      final db = await _db;
      final records = await db.query(
        'auth',
        columns: ['api_key'],
        limit: 1,
        orderBy: 'id DESC',
      );

      if (records.isEmpty) {
        return null;
      }

      final encryptedApiKey = records.first['api_key'] as String?;
      if (encryptedApiKey == null) {
        return null;
      }

      return _decryptApiKey(encryptedApiKey);
    } catch (e) {
      return null;
    }
  }

  /// Получает сохраненный хэш PIN кода.
  ///
  /// Оптимизировано: выполняет прямой запрос к нужному полю вместо полного getAuth().
  ///
  /// Возвращает хэш PIN или null, если он не найден.
  Future<String?> getPinHash() async {
    try {
      final db = await _db;
      final records = await db.query(
        'auth',
        columns: ['pin_hash'],
        limit: 1,
        orderBy: 'id DESC',
      );

      if (records.isEmpty) {
        return null;
      }

      return records.first['pin_hash'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Получает сохраненного провайдера.
  ///
  /// Оптимизировано: выполняет прямой запрос к нужному полю вместо полного getAuth().
  ///
  /// Возвращает 'openrouter' или 'vsegpt', или null, если не найден.
  Future<String?> getProvider() async {
    try {
      final db = await _db;
      final records = await db.query(
        'auth',
        columns: ['provider'],
        limit: 1,
        orderBy: 'id DESC',
      );

      if (records.isEmpty) {
        return null;
      }

      return records.first['provider'] as String?;
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
  /// Возвращает true, если операция выполнена успешно (включая случай, когда данных нет), иначе false.
  Future<bool> clearAuth() async {
    try {
      final db = await _db;
      await db.delete('auth');
      // Возвращаем true, даже если записей не было (цель - очистить данные, и она достигнута)
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Проверяет, существуют ли данные аутентификации.
  ///
  /// Оптимизировано: выполняет быстрый COUNT запрос вместо полного getAuth().
  ///
  /// Возвращает true, если есть сохраненный API ключ и PIN хэш, иначе false.
  Future<bool> hasAuth() async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM auth WHERE api_key IS NOT NULL AND pin_hash IS NOT NULL',
      );
      
      if (result.isEmpty) {
        return false;
      }
      
      final count = result.first['count'] as int?;
      return count != null && count > 0;
    } catch (e) {
      return false;
    }
  }
}
