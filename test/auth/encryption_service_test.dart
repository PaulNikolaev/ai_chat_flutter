import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:ai_chat/auth/encryption_service.dart';

/// Простая in-memory реализация secure storage для тестов.
class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WindowsOptions? wOptions, WebOptions? webOptions, MacOsOptions? mOptions}) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WindowsOptions? wOptions, WebOptions? webOptions, MacOsOptions? mOptions}) async {
    return _store[key];
  }

  @override
  Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WindowsOptions? wOptions, WebOptions? webOptions, MacOsOptions? mOptions}) async {
    _store.remove(key);
  }
}

void main() {
  group('EncryptionService', () {
    late EncryptionService service;
    late FakeSecureStorage storage;

    setUp(() {
      storage = FakeSecureStorage();
      service = EncryptionService(secureStorage: storage);
    });

    test('encrypt/decrypt round trip returns original text', () async {
      const text = 'secret-key-123';
      final encrypted = await service.encrypt(text);
      expect(encrypted, isNot(text));

      final decrypted = await service.decrypt(encrypted);
      expect(decrypted, equals(text));
    });

    test('decrypt migrates old base64 format', () async {
      const old = 'legacy-text';
      final oldBase64 = base64Encode(utf8.encode(old));

      final decrypted = await service.decrypt(oldBase64);
      expect(decrypted, equals(old));
    });

    test('format helpers detect aes and base64', () async {
      final enc = await service.encrypt('data');

      expect(EncryptionService.isAesEncrypted(enc), isTrue);
      expect(EncryptionService.isBase64Encoded(enc), isFalse);

      final b64 = base64Encode(utf8.encode('data'));
      expect(EncryptionService.isBase64Encoded(b64), isTrue);
      expect(EncryptionService.isAesEncrypted(b64), isFalse);
    });
  });
}
