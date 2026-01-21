import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ключ для хранения ключа шифрования в secure storage.
const String _encryptionKeyStorageKey = 'api_key_encryption_key';

/// Сервис для управления шифрованием API ключей.
///
/// Предоставляет методы для шифрования и расшифровки API ключей
/// с использованием AES-256-CBC. Ключ шифрования хранится в
/// flutter_secure_storage для обеспечения безопасности.
///
/// **Безопасность:**
/// - Использует AES-256-CBC для шифрования
/// - Ключ шифрования генерируется случайно при первом использовании
/// - Ключ хранится в flutter_secure_storage (защищенное хранилище)
/// - IV (Initialization Vector) генерируется случайно для каждого шифрования
///
/// **Пример использования:**
/// ```dart
/// final service = EncryptionService();
///
/// // Шифрование
/// final encrypted = await service.encrypt('sk-or-v1-...');
///
/// // Расшифровка
/// final decrypted = await service.decrypt(encrypted);
/// ```
class EncryptionService {
  /// Secure storage для хранения ключа шифрования.
  final FlutterSecureStorage _secureStorage;

  /// Кэш ключа шифрования (загружается один раз при первом использовании).
  Key? _cachedKey;

  /// Создает экземпляр [EncryptionService].
  ///
  /// Параметры:
  /// - [secureStorage]: Экземпляр FlutterSecureStorage (опционально).
  EncryptionService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Получает или создает ключ шифрования.
  ///
  /// Если ключ не существует в secure storage, генерирует новый случайный ключ
  /// и сохраняет его. Если ключ уже существует, загружает его из secure storage.
  ///
  /// Возвращает [Key] для использования в шифровании.
  ///
  /// Выбрасывает [EncryptionException] если не удалось создать или загрузить ключ.
  Future<Key> _getOrCreateEncryptionKey() async {
    // Используем кэшированный ключ, если он уже загружен
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    try {
      // Пытаемся загрузить существующий ключ из secure storage
      final keyString = await _secureStorage.read(key: _encryptionKeyStorageKey);

      if (keyString != null && keyString.isNotEmpty) {
        // Ключ существует - декодируем его из base64
        try {
          final keyBytes = base64Decode(keyString);
          _cachedKey = Key(keyBytes);
          return _cachedKey!;
        } catch (e) {
          // Если декодирование не удалось, генерируем новый ключ
          // (старый ключ мог быть поврежден)
        }
      }

      // Ключ не существует или поврежден - генерируем новый
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      final newKey = Key(Uint8List.fromList(keyBytes));

      // Сохраняем новый ключ в secure storage (base64 для удобства)
      final keyBase64 = base64Encode(keyBytes);
      await _secureStorage.write(
        key: _encryptionKeyStorageKey,
        value: keyBase64,
      );

      _cachedKey = newKey;
      return newKey;
    } catch (e) {
      throw EncryptionException(
        'Failed to get or create encryption key: $e',
      );
    }
  }

  /// Шифрует строку с использованием AES-256-CBC.
  ///
  /// Генерирует случайный IV для каждого шифрования и добавляет его
  /// к зашифрованным данным в формате base64.
  ///
  /// Параметры:
  /// - [plainText]: Текст для шифрования.
  ///
  /// Возвращает зашифрованную строку в формате base64.
  ///
  /// Выбрасывает [EncryptionException] если шифрование не удалось.
  Future<String> encrypt(String plainText) async {
    if (plainText.isEmpty) {
      return '';
    }

    try {
      final key = await _getOrCreateEncryptionKey();
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Сохраняем IV вместе с зашифрованными данными
      // Формат: base64(iv) + ':' + base64(encrypted)
      final ivBase64 = base64Encode(iv.bytes);
      final encryptedBase64 = encrypted.base64;

      return '$ivBase64:$encryptedBase64';
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Расшифровывает строку, зашифрованную с использованием AES-256-CBC.
  ///
  /// Извлекает IV из зашифрованных данных и использует его для расшифровки.
  /// Поддерживает как новый формат (IV:encrypted), так и старый формат (base64)
  /// для обратной совместимости с данными, зашифрованными через base64.
  ///
  /// Параметры:
  /// - [encryptedText]: Зашифрованная строка в формате base64.
  ///
  /// Возвращает расшифрованную строку.
  ///
  /// Выбрасывает [EncryptionException] если расшифровка не удалась.
  Future<String> decrypt(String encryptedText) async {
    if (encryptedText.isEmpty) {
      return '';
    }

    try {
      // Проверяем, является ли это старым форматом (только base64, без IV)
      // Старый формат использовался для base64-кодированных данных
      if (!encryptedText.contains(':')) {
        // Пытаемся декодировать как base64 (старый формат)
        try {
          final bytes = base64Decode(encryptedText);
          return utf8.decode(bytes);
        } catch (e) {
          // Если не удалось декодировать как base64, пробуем как AES
          // (может быть зашифровано без IV в старых версиях)
          throw EncryptionException(
            'Failed to decrypt: invalid format. Data may need migration.',
          );
        }
      }

      // Новый формат: IV:encrypted
      final parts = encryptedText.split(':');
      if (parts.length != 2) {
        throw EncryptionException(
          'Invalid encrypted format: expected "IV:encrypted"',
        );
      }

      final ivBase64 = parts[0];
      final encryptedBase64 = parts[1];

      final key = await _getOrCreateEncryptionKey();
      final iv = IV(base64Decode(ivBase64));
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

      final encrypted = Encrypted.fromBase64(encryptedBase64);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      if (e is EncryptionException) {
        rethrow;
      }
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Проверяет, является ли строка зашифрованной в новом формате (AES).
  ///
  /// Параметры:
  /// - [text]: Текст для проверки.
  ///
  /// Возвращает true, если строка зашифрована в формате AES (содержит ':').
  static bool isAesEncrypted(String text) {
    return text.contains(':') && text.split(':').length == 2;
  }

  /// Проверяет, является ли строка закодированной в старом формате (base64).
  ///
  /// Параметры:
  /// - [text]: Текст для проверки.
  ///
  /// Возвращает true, если строка может быть декодирована из base64.
  static bool isBase64Encoded(String text) {
    if (text.isEmpty) return false;
    try {
      base64Decode(text);
      return !text.contains(':'); // Base64 не содержит ':'
    } catch (e) {
      return false;
    }
  }

  /// Очищает кэш ключа шифрования.
  ///
  /// Используется для принудительной перезагрузки ключа из secure storage.
  void clearCache() {
    _cachedKey = null;
  }

  /// Удаляет ключ шифрования из secure storage.
  ///
  /// **ВНИМАНИЕ:** Это удалит ключ шифрования, что сделает невозможным
  /// расшифровку существующих зашифрованных данных. Используйте с осторожностью!
  ///
  /// Возвращает true, если ключ успешно удален, иначе false.
  Future<bool> deleteEncryptionKey() async {
    try {
      await _secureStorage.delete(key: _encryptionKeyStorageKey);
      _cachedKey = null;
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Исключение, возникающее при ошибках шифрования/расшифровки.
class EncryptionException implements Exception {
  final String message;

  EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
