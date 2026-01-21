import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_chat/auth/auth_storage.dart';

void main() {
  // Инициализируем sqflite_ffi для тестирования на десктопе
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.testLoad(fileInput: '');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AuthStorage Tests', () {
    late AuthStorage storage;

    setUp(() async {
      // Создаем новый экземпляр хранилища для каждого теста
      storage = AuthStorage();
      
      // Очищаем данные перед каждым тестом
      await storage.clearAuth();
    });

    test('saveAuth - сохраняет данные аутентификации', () async {
      const apiKey = 'sk-or-v1-test-storage-key';
      const pinHash = 'test-pin-hash-storage';
      const provider = 'openrouter';

      final result = await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      expect(result, isTrue);
    });

    test('getAuth - получает сохраненные данные', () async {
      const apiKey = 'sk-or-v1-test-storage-get';
      const pinHash = 'test-pin-hash-get';
      const provider = 'vsegpt';

      await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final auth = await storage.getAuth();
      expect(auth, isNotNull);
      expect(auth!['api_key'], equals(apiKey));
      expect(auth['pin_hash'], equals(pinHash));
      expect(auth['provider'], equals(provider));
    });

    test('getApiKey - получает API ключ', () async {
      const apiKey = 'sk-or-v1-test-storage-api';
      const pinHash = 'test-pin-hash-api';
      const provider = 'openrouter';

      await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final retrievedApiKey = await storage.getApiKey();
      expect(retrievedApiKey, equals(apiKey));
    });

    test('getPinHash - получает хэш PIN', () async {
      const apiKey = 'sk-or-v1-test-storage-pin';
      const pinHash = 'test-pin-hash-pin';
      const provider = 'openrouter';

      await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final retrievedPinHash = await storage.getPinHash();
      expect(retrievedPinHash, equals(pinHash));
    });

    test('getProvider - получает провайдера', () async {
      const apiKey = 'sk-or-v1-test-storage-provider';
      const pinHash = 'test-pin-hash-provider';
      const provider = 'vsegpt';

      await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final retrievedProvider = await storage.getProvider();
      expect(retrievedProvider, equals(provider));
    });

    test('verifyPin - проверяет правильный PIN', () async {
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);
      const apiKey = 'sk-or-v1-test-storage-verify';
      const provider = 'openrouter';

      await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final isValid = await storage.verifyPin(pin);
      expect(isValid, isTrue);
    });

    test('verifyPin - отклоняет неправильный PIN', () async {
      const pin = '5678';
      final pinHash = AuthStorage.hashPin(pin);
      const apiKey = 'sk-or-v1-test-storage-verify-fail';
      const provider = 'openrouter';

      await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      final isValid = await storage.verifyPin('9999');
      expect(isValid, isFalse);
    });

    test('clearAuth - очищает данные аутентификации', () async {
      const apiKey = 'sk-or-v1-test-storage-clear';
      const pinHash = 'test-pin-hash-clear';
      const provider = 'openrouter';

      await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: provider,
      );

      // Проверяем, что данные есть
      expect(await storage.hasAuth(), isTrue);

      // Очищаем
      final cleared = await storage.clearAuth();
      expect(cleared, isTrue);

      // Проверяем, что данных нет
      expect(await storage.hasAuth(), isFalse);
      expect(await storage.getAuth(), isNull);
    });

    test('hasAuth - проверяет наличие данных', () async {
      // Изначально данных нет
      expect(await storage.hasAuth(), isFalse);

      // Сохраняем данные
      await storage.saveAuth(
        apiKey: 'sk-or-v1-test-storage-has',
        pinHash: 'test-pin-hash-has',
        provider: 'openrouter',
      );

      // Теперь данные есть
      expect(await storage.hasAuth(), isTrue);
    });

    test('hashPin - хэширует PIN корректно', () {
      const pin = '9876';
      final hash1 = AuthStorage.hashPin(pin);
      final hash2 = AuthStorage.hashPin(pin);

      // Один и тот же PIN должен давать одинаковый хэш
      expect(hash1, equals(hash2));
      expect(hash1.length, greaterThan(0));

      // Разные PIN должны давать разные хэши
      final hash3 = AuthStorage.hashPin('1111');
      expect(hash1, isNot(equals(hash3)));
    });
  });
}
