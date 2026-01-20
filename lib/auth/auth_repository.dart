import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ai_chat/utils/utils.dart';

/// Репозиторий для работы с данными аутентификации в базе данных.
///
/// Предоставляет методы для сохранения, получения и управления
/// данными аутентификации в таблице `auth_keys` базы данных SQLite.
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
/// - Таблица `auth_keys` поддерживает несколько записей (по одной на провайдера)
/// - Поля: `id`, `api_key` (зашифрован), `pin_hash`, `provider`, `created_at`, `last_used`
/// - Ограничение UNIQUE(provider) гарантирует один ключ на провайдера
/// - Все ключи под одним PIN имеют одинаковый pin_hash
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
  /// Если ключ для данного провайдера уже существует, он будет обновлен.
  /// Если нет - создается новая запись.
  /// API ключ шифруется перед сохранением.
  ///
  /// **Важно:** При добавлении нового ключа от другого провайдера,
  /// pin_hash обновляется для всех существующих ключей, чтобы они были
  /// связаны с одним PIN.
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
        // Проверяем существование ключа для данного провайдера
        final existing = await txn.query(
          'auth_keys',
          columns: ['id', 'created_at', 'pin_hash'],
          where: 'provider = ?',
          whereArgs: [provider],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          // Обновляем существующую запись для этого провайдера
          final existingId = existing.first['id'] as int;
          final existingCreatedAt = existing.first['created_at'] as String?;
          
          // Обновляем pin_hash для всех ключей, если он изменился
          // (это нужно для синхронизации всех ключей под одним PIN)
          final existingPinHash = existing.first['pin_hash'] as String?;
          if (existingPinHash != pinHash) {
            await txn.update(
              'auth_keys',
              {'pin_hash': pinHash},
              where: 'pin_hash = ?',
              whereArgs: [existingPinHash],
            );
          }
          
          final result = await txn.update(
            'auth_keys',
            {
              'api_key': encryptedApiKey,
              'pin_hash': pinHash,
              'created_at': existingCreatedAt ?? now, // Сохраняем оригинальную дату создания
              'last_used': now,
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
          return result > 0;
        } else {
          // Это новый провайдер - проверяем, есть ли другие ключи
          // Если есть другие ключи, синхронизируем pin_hash со всеми существующими ключами
          final otherKeys = await txn.query('auth_keys');
          if (otherKeys.isNotEmpty) {
            // Берем pin_hash из первого существующего ключа
            final otherPinHash = otherKeys.first['pin_hash'] as String?;
            if (otherPinHash != null && otherPinHash.isNotEmpty) {
              // Если у существующих ключей уже есть pin_hash, ВСЕГДА используем его
              // Это гарантирует, что все ключи будут под одним PIN
              // Новый ключ должен использовать существующий PIN, а не создавать новый
              pinHash = otherPinHash;
            } else {
              // Если у существующих ключей нет pin_hash (не должно происходить в нормальной работе),
              // обновляем их на новый pin_hash
              await txn.update(
                'auth_keys',
                {'pin_hash': pinHash},
              );
            }
          }
          
          // Создаем новую запись для нового провайдера с синхронизированным pin_hash
          final result = await txn.insert(
            'auth_keys',
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
  /// для активного провайдера (последнего использованного) или null, если данные не найдены.
  /// API ключ автоматически расшифровывается.
  ///
  /// Для получения всех ключей используйте getAllAuthKeys().
  Future<Map<String, String>?> getAuth() async {
    try {
      final db = await _db;
      final records = await db.query(
        'auth_keys',
        orderBy: 'last_used DESC, id DESC',
        limit: 1,
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
  
  /// Получает все API ключи из базы данных.
  ///
  /// Возвращает список Map, каждый содержит 'api_key', 'provider', 'created_at', 'last_used'.
  /// API ключи автоматически расшифровываются.
  Future<List<Map<String, String>>> getAllAuthKeys() async {
    try {
      final db = await _db;
      final records = await db.query(
        'auth_keys',
        orderBy: 'last_used DESC, created_at DESC',
      );

      return records.map((record) {
        final encryptedApiKey = record['api_key'] as String?;
        final apiKey = encryptedApiKey != null ? _decryptApiKey(encryptedApiKey) : '';
        
        return {
          'api_key': apiKey,
          'provider': record['provider'] as String? ?? '',
          'created_at': record['created_at'] as String? ?? '',
          'last_used': record['last_used'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Получает сохраненный API ключ для указанного провайдера.
  ///
  /// Оптимизировано: выполняет прямой запрос к нужному полю вместо полного getAuth().
  ///
  /// Параметры:
  /// - [provider]: Провайдер для получения ключа (опционально, если null - возвращает активный).
  ///
  /// Возвращает расшифрованный API ключ или null, если он не найден.
  Future<String?> getApiKey({String? provider}) async {
    try {
      final db = await _db;
      final records = provider != null
          ? await db.query(
              'auth_keys',
              columns: ['api_key'],
              where: 'provider = ?',
              whereArgs: [provider],
              limit: 1,
            )
          : await db.query(
              'auth_keys',
              columns: ['api_key'],
              orderBy: 'last_used DESC, id DESC',
              limit: 1,
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
        'auth_keys',
        columns: ['pin_hash'],
        limit: 1,
        orderBy: 'last_used DESC, id DESC',
      );

      if (records.isEmpty) {
        return null;
      }

      return records.first['pin_hash'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Получает активного провайдера (последнего использованного).
  ///
  /// Оптимизировано: выполняет прямой запрос к нужному полю вместо полного getAuth().
  ///
  /// Возвращает 'openrouter' или 'vsegpt', или null, если не найден.
  Future<String?> getProvider() async {
    try {
      final db = await _db;
      final records = await db.query(
        'auth_keys',
        columns: ['provider'],
        orderBy: 'last_used DESC, id DESC',
        limit: 1,
      );

      if (records.isEmpty) {
        return null;
      }

      return records.first['provider'] as String?;
    } catch (e) {
      return null;
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
      final db = await _db;
      final now = DateTime.now().toIso8601String();
      final result = await db.update(
        'auth_keys',
        {'last_used': now},
        where: 'provider = ?',
        whereArgs: [provider],
      );
      return result > 0;
    } catch (e) {
      return false;
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
      final db = await _db;
      final result = await db.delete(
        'auth_keys',
        where: 'provider = ?',
        whereArgs: [provider],
      );
      return result > 0;
    } catch (e) {
      return false;
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
  /// Удаляет все записи из таблицы `auth_keys`.
  ///
  /// Возвращает true, если операция выполнена успешно (включая случай, когда данных нет), иначе false.
  Future<bool> clearAuth() async {
    try {
      final db = await _db;
      await db.delete('auth_keys');
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
  /// Возвращает true, если есть хотя бы один сохраненный API ключ и PIN хэш, иначе false.
  Future<bool> hasAuth() async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM auth_keys WHERE api_key IS NOT NULL AND pin_hash IS NOT NULL',
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
