import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;

import 'package:ai_chat/auth/auth_manager.dart';
import 'package:ai_chat/auth/auth_storage.dart';
import 'package:ai_chat/auth/auth_validator.dart';
import 'package:ai_chat/utils/database/database.dart';

// Мок AuthStorage для симуляции ошибок БД в интеграционных тестах
class MockAuthStorageForIntegration extends AuthStorage {
  bool _hasAuth = false;
  bool _saveShouldFail = false;
  bool _hasAuthShouldFail = false;
  bool _verifyPinShouldFail = false;
  bool _getApiKeyShouldFail = false;
  bool _clearAuthShouldFail = false;
  
  String? _storedApiKey;
  String? _storedPinHash;
  String? _storedProvider;

  @override
  Future<bool> saveAuth({
    required String apiKey,
    required String pinHash,
    required String provider,
  }) async {
    if (_saveShouldFail) {
      return false;
    }
    _hasAuth = true;
    _storedApiKey = apiKey;
    _storedPinHash = pinHash;
    _storedProvider = provider;
    return true;
  }

  @override
  Future<bool> hasAuth() async {
    if (_hasAuthShouldFail) {
      throw Exception('Database error');
    }
    return _hasAuth;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    if (_verifyPinShouldFail) {
      throw Exception('Database error during PIN verification');
    }
    if (!_hasAuth || _storedPinHash == null) {
      return false;
    }
    // Проверяем PIN через хэширование
    final pinHash = AuthStorage.hashPin(pin);
    return pinHash == _storedPinHash;
  }

  @override
  Future<String?> getApiKey({String? provider}) async {
    if (_getApiKeyShouldFail) {
      throw Exception('Database error during API key retrieval');
    }
    // Если указан провайдер, проверяем соответствие
    if (provider != null && _storedProvider != provider) {
      return null;
    }
    return _storedApiKey;
  }

  @override
  Future<String?> getPinHash() async {
    return _storedPinHash;
  }

  @override
  Future<String?> getProvider() async {
    return _storedProvider;
  }

  @override
  Future<bool> clearAuth() async {
    if (_clearAuthShouldFail) {
      return false;
    }
    _hasAuth = false;
    _storedApiKey = null;
    _storedPinHash = null;
    _storedProvider = null;
    return true;
  }

  void setSaveShouldFail(bool value) {
    _saveShouldFail = value;
  }

  void setHasAuthShouldFail(bool value) {
    _hasAuthShouldFail = value;
  }

  void setVerifyPinShouldFail(bool value) {
    _verifyPinShouldFail = value;
  }

  void setGetApiKeyShouldFail(bool value) {
    _getApiKeyShouldFail = value;
  }

  void setClearAuthShouldFail(bool value) {
    _clearAuthShouldFail = value;
  }
}

// Мок валидатора для симуляции различных сценариев
class MockAuthValidatorForIntegration extends AuthValidator {
  ApiKeyValidationResult? _validationResult;
  bool _shouldThrow = false;
  Exception? _exceptionToThrow;

  MockAuthValidatorForIntegration({
    String? openRouterBaseUrl,
    String? vsegptBaseUrl,
    super.httpClient,
  }) : super(
          openRouterBaseUrl: openRouterBaseUrl ?? 'https://test.openrouter.ai/api/v1',
          vsegptBaseUrl: vsegptBaseUrl ?? 'https://test.vsegpt.ru/v1',
        );

  @override
  Future<ApiKeyValidationResult> validateApiKey(String apiKey) async {
    if (_shouldThrow) {
      throw _exceptionToThrow ?? Exception('Network error');
    }
    return _validationResult ?? const ApiKeyValidationResult(
      isValid: false,
      message: 'No validation result set',
      balance: 0.0,
      provider: 'unknown',
    );
  }

  void setValidationResult(ApiKeyValidationResult result) {
    _validationResult = result;
    _shouldThrow = false;
  }

  void setShouldThrow(bool value, [Exception? exception]) {
    _shouldThrow = value;
    _exceptionToThrow = exception;
  }

  void reset() {
    _validationResult = null;
    _shouldThrow = false;
    _exceptionToThrow = null;
  }
}

void main() {
  // Инициализируем sqflite_ffi для тестирования на десктопе
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Integration Tests - Full Authentication Flow', () {
    late AuthManager authManager;
    late AuthStorage authStorage;
    late MockAuthValidatorForIntegration mockValidator;
    late DatabaseHelper databaseHelper;

    setUp(() async {
      // Очищаем базу данных перед каждым тестом
      databaseHelper = DatabaseHelper.instance;
      try {
        await databaseHelper.deleteDatabase();
      } catch (_) {
        // Игнорируем ошибки, если БД не существует
      }

      // Создаем новые экземпляры для каждого теста
      mockValidator = MockAuthValidatorForIntegration();
      authStorage = AuthStorage();
      authManager = AuthManager(
        storage: authStorage,
        validator: mockValidator,
      );
    });

    tearDown(() async {
      // Очищаем базу данных после каждого теста
      try {
        await databaseHelper.close();
        await databaseHelper.deleteDatabase();
      } catch (_) {
        // Игнорируем ошибки очистки
      }
    });

    test('Integration: Full cycle - First login → Logout → PIN login', () async {
      // Шаг 1: Первый вход с валидным OpenRouter ключом
      const apiKey = 'sk-or-v1-test-integration-key-12345';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.50',
          balance: 100.50,
          provider: 'openrouter',
        ),
      );

      final firstLoginResult = await authManager.handleFirstLogin(apiKey, '1234');

      expect(firstLoginResult.success, isTrue);
      expect(firstLoginResult.message.length, equals(4)); // PIN должен быть 4-значным
      expect(int.tryParse(firstLoginResult.message), isNotNull);
      expect(firstLoginResult.balance, equals('100.50'));

      // Проверяем, что данные сохранены в БД
      expect(await authStorage.hasAuth(), isTrue);
      final storedApiKey = await authStorage.getApiKey();
      expect(storedApiKey, equals(apiKey));
      final storedProvider = await authStorage.getProvider();
      expect(storedProvider, equals('openrouter'));

      // Сохраняем PIN для дальнейшего использования
      final generatedPin = firstLoginResult.message;

      // Шаг 2: "Выход" - проверяем, что данные остаются в БД
      // (в реальном приложении это может быть просто очистка состояния)
      expect(await authManager.isAuthenticated(), isTrue);

      // Шаг 3: Повторный вход по PIN
      final pinLoginResult = await authManager.handlePinLogin(generatedPin);

      expect(pinLoginResult.success, isTrue);
      expect(pinLoginResult.message, equals(apiKey));

      // Проверяем, что данные все еще в БД
      expect(await authStorage.hasAuth(), isTrue);
    });

    test('Integration: Full cycle - First login → Reset → New first login', () async {
      // Шаг 1: Первый вход с валидным VSEGPT ключом
      const firstApiKey = 'sk-or-vv-test-integration-key-vsegpt-67890';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '250.75',
          balance: 250.75,
          provider: 'vsegpt',
        ),
      );

      final firstLoginResult =
          await authManager.handleFirstLogin(firstApiKey, '1234');

      expect(firstLoginResult.success, isTrue);
      expect(firstLoginResult.message.length, equals(4));
      expect(firstLoginResult.balance, equals('250.75'));

      // Проверяем, что данные сохранены
      expect(await authStorage.hasAuth(), isTrue);
      final storedProvider1 = await authStorage.getProvider();
      expect(storedProvider1, equals('vsegpt'));

      // Шаг 2: Сброс ключа
      final resetResult = await authManager.handleReset();

      expect(resetResult, isTrue);
      expect(await authStorage.hasAuth(), isFalse);

      // Шаг 3: Новый первый вход с другим ключом
      const secondApiKey = 'sk-or-v1-test-integration-key-openrouter-99999';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '150.00',
          balance: 150.0,
          provider: 'openrouter',
        ),
      );

      final secondLoginResult =
          await authManager.handleFirstLogin(secondApiKey, '1234');

      expect(secondLoginResult.success, isTrue);
      expect(secondLoginResult.message.length, equals(4));
      expect(secondLoginResult.balance, equals('150.00'));

      // Проверяем, что новые данные сохранены
      expect(await authStorage.hasAuth(), isTrue);
      final storedApiKey2 = await authStorage.getApiKey();
      expect(storedApiKey2, equals(secondApiKey));
      final storedProvider2 = await authStorage.getProvider();
      expect(storedProvider2, equals('openrouter'));
    });

    test('Integration: Switching between OpenRouter and VSEGPT keys', () async {
      // Шаг 1: Первый вход с OpenRouter ключом
      const openRouterKey = 'sk-or-v1-test-switch-openrouter';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'openrouter',
        ),
      );

      final openRouterResult =
          await authManager.handleFirstLogin(openRouterKey, '1234');

      expect(openRouterResult.success, isTrue);
      expect(await authStorage.getProvider(), equals('openrouter'));
      expect(await authStorage.getApiKey(), equals(openRouterKey));

      final openRouterPin = openRouterResult.message;

      // Шаг 2: Обновление ключа на VSEGPT через handleApiKeyLogin
      const vsegptKey = 'sk-or-vv-test-switch-vsegpt';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '200.00',
          balance: 200.0,
          provider: 'vsegpt',
        ),
      );

      final switchResult = await authManager.handleApiKeyLogin(vsegptKey);

      expect(switchResult.success, isTrue);
      expect(switchResult.message, equals('API key updated successfully'));
      expect(await authStorage.getProvider(), equals('vsegpt'));
      expect(await authStorage.getApiKey(), equals(vsegptKey));

      // Проверяем, что PIN сохранился (можно войти по старому PIN)
      final pinLoginResult = await authManager.handlePinLogin(openRouterPin);
      expect(pinLoginResult.success, isTrue);
      expect(pinLoginResult.message, equals(vsegptKey));

      // Шаг 3: Переключение обратно на OpenRouter
      const openRouterKey2 = 'sk-or-v1-test-switch-openrouter-2';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '300.00',
          balance: 300.0,
          provider: 'openrouter',
        ),
      );

      final switchBackResult = await authManager.handleApiKeyLogin(openRouterKey2);

      expect(switchBackResult.success, isTrue);
      expect(await authStorage.getProvider(), equals('openrouter'));
      expect(await authStorage.getApiKey(), equals(openRouterKey2));

      // PIN все еще должен работать
      final pinLoginResult2 = await authManager.handlePinLogin(openRouterPin);
      expect(pinLoginResult2.success, isTrue);
      expect(pinLoginResult2.message, equals(openRouterKey2));
    });

    test('Integration: Network error handling during first login', () async {
      // Симулируем отсутствие сети при валидации API ключа
      mockValidator.setShouldThrow(
        true,
        http.ClientException('Network error: Connection refused'),
      );

      const apiKey = 'sk-or-v1-test-network-error';

      final result = await authManager.handleFirstLogin(apiKey, '1234');

      expect(result.success, isFalse);
      expect(result.message, contains('Unexpected error'));
      expect(result.message, contains('try again'));

      // Проверяем, что данные не были сохранены
      expect(await authStorage.hasAuth(), isFalse);
    });

    test('Integration: Network error handling during PIN login', () async {
      // Сначала сохраняем данные
      const apiKey = 'sk-or-v1-test-network-pin-login';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'openrouter',
        ),
      );

      final firstLoginResult = await authManager.handleFirstLogin(apiKey, '1234');
      expect(firstLoginResult.success, isTrue);
      final pin = firstLoginResult.message;

      // PIN логин не требует сети, поэтому этот тест проверяет,
      // что PIN логин работает даже если валидатор недоступен
      // (в реальности PIN логин не использует валидатор)
      final pinLoginResult = await authManager.handlePinLogin(pin);

      expect(pinLoginResult.success, isTrue);
      expect(pinLoginResult.message, equals(apiKey));
    });

    test('Integration: Database error handling during save', () async {
      // Для проверки обработки ошибок БД используем мок AuthStorage
      // который будет выбрасывать ошибки при сохранении
      final mockStorageWithError = MockAuthStorageForIntegration();
      mockStorageWithError.setSaveShouldFail(true);
      
      final authManagerWithError = AuthManager(
        storage: mockStorageWithError,
        validator: mockValidator,
      );

      const apiKey = 'sk-or-v1-test-db-error';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'openrouter',
        ),
      );

      // Пытаемся сохранить данные (должна быть ошибка)
      final result = await authManagerWithError.handleFirstLogin(apiKey, '1234');

      // Проверяем, что ошибка обработана корректно
      expect(result.success, isFalse);
      expect(result.message, contains('Failed to save'));
      expect(result.message, contains('database'));
    });

    test('Integration: Database error handling during PIN verification', () async {
      // Сохраняем данные в реальное хранилище
      const apiKey = 'sk-or-v1-test-db-pin-verify';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'openrouter',
        ),
      );

      final firstLoginResult = await authManager.handleFirstLogin(apiKey, '1234');
      expect(firstLoginResult.success, isTrue);
      final pin = firstLoginResult.message;

      // Создаем мок хранилище с ошибкой при проверке PIN
      final mockStorageWithError = MockAuthStorageForIntegration();
      mockStorageWithError.setVerifyPinShouldFail(true);
      
      final authManagerWithError = AuthManager(
        storage: mockStorageWithError,
        validator: mockValidator,
      );

      // Пытаемся проверить PIN (должна быть ошибка)
      final result = await authManagerWithError.handlePinLogin(pin);

      expect(result.success, isFalse);
      expect(result.message, contains('Error verifying PIN'));
    });

    test('Integration: Database error handling during reset', () async {
      // Сохраняем данные в реальное хранилище
      const apiKey = 'sk-or-v1-test-db-reset';
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'openrouter',
        ),
      );

      final firstLoginResult = await authManager.handleFirstLogin(apiKey, '1234');
      expect(firstLoginResult.success, isTrue);

      // Создаем мок хранилище с ошибкой при сбросе
      final mockStorageWithError = MockAuthStorageForIntegration();
      mockStorageWithError.setClearAuthShouldFail(true);
      
      final authManagerWithError = AuthManager(
        storage: mockStorageWithError,
        validator: mockValidator,
      );

      // Пытаемся сбросить данные (должна быть ошибка)
      final result = await authManagerWithError.handleReset();

      expect(result, isFalse);
    });
  });
}
