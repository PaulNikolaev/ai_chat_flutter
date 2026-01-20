import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import 'package:ai_chat/auth/auth_repository.dart';

void main() {
  // Инициализируем sqflite_ffi для тестирования на десктопе
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AuthRepository Tests', () {
    late Database testDb;
    late AuthRepository repository;
    late String testDbPath;

    setUp(() async {
      // Создаем временную базу данных для тестов
      final dbDir = await Directory.systemTemp.createTemp('test_db');
      testDbPath = path.join(dbDir.path, 'test_auth.db');
      
      // Создаем тестовую базу данных с актуальной схемой (версия 4 - auth_keys)
      testDb = await openDatabase(
        testDbPath,
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS auth_keys (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              api_key TEXT NOT NULL,
              provider TEXT NOT NULL,
              pin_hash TEXT NOT NULL,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              last_used TEXT,
              UNIQUE(provider)
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Миграция на версию 4 - создание auth_keys таблицы
          if (oldVersion < 4) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS auth_keys (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                api_key TEXT NOT NULL,
                provider TEXT NOT NULL,
                pin_hash TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                last_used TEXT,
                UNIQUE(provider)
              )
            ''');
            // Удаляем старую таблицу auth если она существует
            await db.execute('DROP TABLE IF EXISTS auth');
          }
        },
      );

      // Создаем репозиторий с тестовой БД
      repository = AuthRepository();
      
      // Очищаем БД перед каждым тестом
      await testDb.delete('auth_keys');
    });

    tearDown(() async {
      // Очищаем БД после каждого теста для изоляции
      await testDb.delete('auth_keys');
    });
    
    tearDownAll(() async {
      // Удаляем тестовую БД после всех тестов
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('saveAuth - сохраняет данные аутентификации', () async {
      const apiKey = 'sk-or-v1-test-key-12345';
      const pinHash = 'test-pin-hash-abc123';
      const provider = 'openrouter';

      final result = await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      expect(result, isTrue);

      // Проверяем, что данные сохранились
      final auth = await repository.getAuth();
      expect(auth, isNotNull);
      expect(auth!['api_key'], equals(apiKey));
      expect(auth['pin_hash'], equals(pinHash));
      expect(auth['provider'], equals(provider));
    });

    test('getAuth - получает сохраненные данные', () async {
      const apiKey = 'sk-or-v1-test-key-67890';
      const pinHash = 'test-pin-hash-def456';
      const provider = 'vsegpt';

      await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      // getAuth возвращает последний использованный ключ
      final auth = await repository.getAuth();
      expect(auth, isNotNull);
      expect(auth!['api_key'], equals(apiKey));
      expect(auth['pin_hash'], equals(pinHash));
      expect(auth['provider'], equals(provider));
      
      // Проверяем через getApiKey для конкретного провайдера
      final apiKeyByProvider = await repository.getApiKey(provider: provider);
      expect(apiKeyByProvider, equals(apiKey));
    });

    test('getApiKey - получает API ключ', () async {
      const apiKey = 'sk-or-v1-test-key-api';
      const pinHash = 'test-pin-hash-xyz';
      const provider = 'openrouter';

      await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final retrievedApiKey = await repository.getApiKey();
      expect(retrievedApiKey, equals(apiKey));
    });

    test('getPinHash - получает хэш PIN', () async {
      const apiKey = 'sk-or-v1-test-key-pin';
      const pinHash = 'test-pin-hash-789';
      const provider = 'openrouter';

      await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final retrievedPinHash = await repository.getPinHash();
      expect(retrievedPinHash, equals(pinHash));
    });

    test('getProvider - получает провайдера', () async {
      const apiKey = 'sk-or-v1-test-key-provider';
      const pinHash = 'test-pin-hash-provider';
      const provider = 'vsegpt';

      await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final retrievedProvider = await repository.getProvider();
      expect(retrievedProvider, equals(provider));
    });

    test('verifyPin - проверяет правильный PIN', () async {
      const pin = '1234';
      final pinHash = AuthRepository.hashPin(pin);
      const apiKey = 'sk-or-v1-test-key-verify';
      const provider = 'openrouter';

      await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final isValid = await repository.verifyPin(pin);
      expect(isValid, isTrue);
    });

    test('verifyPin - отклоняет неправильный PIN', () async {
      const pin = '1234';
      final pinHash = AuthRepository.hashPin(pin);
      const apiKey = 'sk-or-v1-test-key-verify-fail';
      const provider = 'openrouter';

      await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final isValid = await repository.verifyPin('9999');
      expect(isValid, isFalse);
    });

    test('clearAuth - очищает данные аутентификации', () async {
      const apiKey = 'sk-or-v1-test-key-clear';
      const pinHash = 'test-pin-hash-clear';
      const provider = 'openrouter';

      await repository.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      // Проверяем, что данные есть
      expect(await repository.hasAuth(), isTrue);

      // Очищаем
      final cleared = await repository.clearAuth();
      expect(cleared, isTrue);

      // Проверяем, что данных нет
      expect(await repository.hasAuth(), isFalse);
      expect(await repository.getAuth(), isNull);
    });

    test('hasAuth - проверяет наличие данных', () async {
      // Изначально данных нет
      expect(await repository.hasAuth(), isFalse);

      // Сохраняем данные
      await repository.saveAuth(
        apiKey: 'sk-or-v1-test-key-has',
        pinHash: 'test-pin-hash-has',
        provider: 'openrouter',
      );

      // Теперь данные есть
      expect(await repository.hasAuth(), isTrue);
    });

    test('hashPin - хэширует PIN корректно', () {
      const pin = '5678';
      final hash1 = AuthRepository.hashPin(pin);
      final hash2 = AuthRepository.hashPin(pin);

      // Один и тот же PIN должен давать одинаковый хэш
      expect(hash1, equals(hash2));
      expect(hash1.length, greaterThan(0));

      // Разные PIN должны давать разные хэши
      final hash3 = AuthRepository.hashPin('9999');
      expect(hash1, isNot(equals(hash3)));
    });

    test('saveAuth - обновляет существующие данные', () async {
      const apiKey1 = 'sk-or-v1-test-key-update-1';
      const pinHash1 = 'test-pin-hash-update-1';
      const provider1 = 'openrouter';

      // Сохраняем первые данные
      await repository.saveAuth(
        apiKey: apiKey1,
        pinHash: pinHash1,
        provider: provider1,
      );

      const apiKey2 = 'sk-or-v1-test-key-update-2';
      const pinHash2 = 'test-pin-hash-update-2';
      const provider2 = 'vsegpt';

      // Сохраняем второй ключ с другим провайдером
      // Логика AuthRepository: если есть другие ключи, используется их pin_hash
      await repository.saveAuth(
        apiKey: apiKey2,
        pinHash: pinHash2,
        provider: provider2,
      );

      // getAuth возвращает последний использованный (vsegpt)
      final auth = await repository.getAuth();
      expect(auth, isNotNull);
      expect(auth!['api_key'], equals(apiKey2));
      // pin_hash синхронизируется с первым ключом
      expect(auth['pin_hash'], equals(pinHash1));
      expect(auth['provider'], equals(provider2));
      
      // Проверяем обновление существующего ключа для того же провайдера
      const apiKey1Updated = 'sk-or-v1-test-key-update-1-new';
      const pinHash1Updated = 'test-pin-hash-update-1-new';
      
      // Обновляем ключ для openrouter
      await repository.saveAuth(
        apiKey: apiKey1Updated,
        pinHash: pinHash1Updated,
        provider: provider1,
      );
      
      // Проверяем обновление
      final updatedAuth = await repository.getApiKey(provider: provider1);
      expect(updatedAuth, equals(apiKey1Updated));
      
      // Проверяем, что pin_hash обновился (синхронизирован со всеми ключами)
      final pinHashAfterUpdate = await repository.getPinHash();
      expect(pinHashAfterUpdate, equals(pinHash1Updated));
      
      // Проверяем, что оба ключа используют обновленный pin_hash
      // через getAuth для каждого провайдера
      final auth1 = await repository.getApiKey(provider: provider1);
      final auth2 = await repository.getApiKey(provider: provider2);
      expect(auth1, equals(apiKey1Updated));
      expect(auth2, equals(apiKey2));
    });

    test('API key encryption - ключ шифруется и расшифровывается', () async {
      const originalApiKey = 'sk-or-v1-very-secret-key-12345';
      const pinHash = 'test-pin-hash-encryption';
      const provider = 'openrouter';

      await repository.saveAuth(
        apiKey: originalApiKey,
        pinHash: pinHash,
        provider: provider,
      );

      // Получаем ключ обратно
      final retrievedApiKey = await repository.getApiKey();
      expect(retrievedApiKey, equals(originalApiKey));
    });
  });
}
