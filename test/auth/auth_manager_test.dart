import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_chat/auth/auth_manager.dart';
import 'package:ai_chat/auth/auth_storage.dart';
import 'package:ai_chat/auth/auth_validator.dart';

// Мок классы для тестирования
class MockAuthStorage extends AuthStorage {
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

  void reset() {
    _hasAuth = false;
    _saveShouldFail = false;
    _hasAuthShouldFail = false;
    _verifyPinShouldFail = false;
    _getApiKeyShouldFail = false;
    _clearAuthShouldFail = false;
    _storedApiKey = null;
    _storedPinHash = null;
    _storedProvider = null;
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

class MockAuthValidator extends AuthValidator {
  ApiKeyValidationResult? _validationResult;
  bool _shouldThrow = false;
  Exception? _exceptionToThrow;

  MockAuthValidator() : super(
    openRouterBaseUrl: 'https://test.openrouter.ai/api/v1',
    vsegptBaseUrl: 'https://test.vsegpt.ru/v1',
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

  group('AuthManager handleFirstLogin Tests', () {
    late MockAuthStorage mockStorage;
    late MockAuthValidator mockValidator;
    late AuthManager authManager;

    setUp(() {
      mockStorage = MockAuthStorage();
      mockValidator = MockAuthValidator();
      authManager = AuthManager(
        storage: mockStorage,
        validator: mockValidator,
      );
      mockStorage.reset();
      mockValidator.reset();
    });

    test('handleFirstLogin - успешный вход с валидным OpenRouter ключом', () async {
      // Настраиваем мок валидатора для успешной валидации OpenRouter ключа
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.50',
          balance: 100.50,
          provider: 'openrouter',
        ),
      );

      const apiKey = 'sk-or-v1-test-key-openrouter-12345';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isTrue);
      expect(result.message.length, equals(4)); // PIN должен быть 4-значным
      expect(int.tryParse(result.message), isNotNull);
      expect(int.parse(result.message), greaterThanOrEqualTo(1000));
      expect(int.parse(result.message), lessThanOrEqualTo(9999));
      expect(result.balance, equals('100.50'));

      // Проверяем, что данные были сохранены
      expect(await mockStorage.hasAuth(), isTrue);
    });

    test('handleFirstLogin - успешный вход с валидным VSEGPT ключом', () async {
      // Настраиваем мок валидатора для успешной валидации VSEGPT ключа
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '250.75',
          balance: 250.75,
          provider: 'vsegpt',
        ),
      );

      const apiKey = 'sk-or-vv-test-key-vsegpt-67890';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isTrue);
      expect(result.message.length, equals(4)); // PIN должен быть 4-значным
      expect(int.tryParse(result.message), isNotNull);
      expect(int.parse(result.message), greaterThanOrEqualTo(1000));
      expect(int.parse(result.message), lessThanOrEqualTo(9999));
      expect(result.balance, equals('250.75'));

      // Проверяем, что данные были сохранены
      expect(await mockStorage.hasAuth(), isTrue);
    });

    test('handleFirstLogin - ошибка при неверном ключе (401)', () async {
      // Настраиваем мок валидатора для ошибки 401
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: false,
          message: 'Invalid OpenRouter API key. Details: Unauthorized',
          balance: 0.0,
          provider: 'openrouter',
        ),
      );

      const apiKey = 'sk-or-v1-invalid-key';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid API key'));
      expect(result.message, contains('correct'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - ошибка при неверном формате ключа', () async {
      const apiKey = 'invalid-key-format';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid API key format'));
      expect(result.message, contains('sk-or-vv-'));
      expect(result.message, contains('sk-or-v1-'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - ошибка при пустом ключе', () async {
      const apiKey = '';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('cannot be empty'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - успешный вход с нулевым балансом', () async {
      // Настраиваем мок валидатора для нулевого баланса
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '0.00',
          balance: 0.0,
          provider: 'openrouter',
        ),
      );

      const apiKey = 'sk-or-v1-test-key-zero-balance';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isTrue);
      expect(result.message.length, equals(4)); // PIN должен быть 4-значным
      expect(result.balance, equals('0.00'));

      // Проверяем, что данные были сохранены даже с нулевым балансом
      expect(await mockStorage.hasAuth(), isTrue);
    });

    test('handleFirstLogin - ошибка при отрицательном балансе', () async {
      // Настраиваем мок валидатора для отрицательного баланса
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '-10.50',
          balance: -10.50,
          provider: 'openrouter',
        ),
      );

      const apiKey = 'sk-or-v1-test-key-negative-balance';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Insufficient balance'));
      expect(result.message, contains('negative'));
      expect(result.message, contains('-10.50'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - ошибка при отсутствии сети (Network error)', () async {
      // Настраиваем мок валидатора для сетевой ошибки
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: false,
          message: 'Network error while validating OpenRouter key: Connection refused',
          balance: 0.0,
          provider: 'openrouter',
        ),
      );

      const apiKey = 'sk-or-v1-test-key-network-error';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Network error'));
      expect(result.message, contains('internet connection'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - ошибка при таймауте', () async {
      // Настраиваем мок валидатора для таймаута
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: false,
          message: 'Request timeout while validating OpenRouter key: TimeoutException',
          balance: 0.0,
          provider: 'openrouter',
        ),
      );

      const apiKey = 'sk-or-v1-test-key-timeout';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('timeout'));
      expect(result.message, contains('did not respond'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - ошибка при неожиданном исключении в валидаторе', () async {
      // Настраиваем мок валидатора для выброса исключения
      mockValidator.setShouldThrow(true, Exception('Unexpected error'));

      const apiKey = 'sk-or-v1-test-key-exception';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Unexpected error'));
      expect(result.message, contains('try again'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - ошибка при сохранении в БД', () async {
      // Настраиваем мок валидатора для успешной валидации
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '50.00',
          balance: 50.0,
          provider: 'openrouter',
        ),
      );

      // Настраиваем мок хранилища для ошибки сохранения
      mockStorage.setSaveShouldFail(true);

      const apiKey = 'sk-or-v1-test-key-save-error';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Failed to save'));
      expect(result.message, contains('database'));

      // Проверяем, что данные не были сохранены
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleFirstLogin - ошибка при проверке сохраненных данных', () async {
      // Настраиваем мок валидатора для успешной валидации
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '75.00',
          balance: 75.0,
          provider: 'openrouter',
        ),
      );

      // Настраиваем мок хранилища для ошибки проверки
      mockStorage.setHasAuthShouldFail(true);

      const apiKey = 'sk-or-v1-test-key-verify-error';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Error verifying'));
      expect(result.message, contains('try again'));
    });

    test('handleFirstLogin - ошибка при неверном провайдере', () async {
      // Настраиваем мок валидатора для неверного провайдера
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'unknown',
        ),
      );

      const apiKey = 'sk-or-v1-test-key-unknown-provider';

      final result = await authManager.handleFirstLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid provider'));
      expect(result.message, contains('openrouter'));
      expect(result.message, contains('vsegpt'));
    });
  });

  group('AuthManager handlePinLogin Tests', () {
    late MockAuthStorage mockStorage;
    late MockAuthValidator mockValidator;
    late AuthManager authManager;

    setUp(() {
      mockStorage = MockAuthStorage();
      mockValidator = MockAuthValidator();
      authManager = AuthManager(
        storage: mockStorage,
        validator: mockValidator,
      );
      mockStorage.reset();
      mockValidator.reset();
    });

    test('handlePinLogin - успешный вход с валидным PIN', () async {
      // Настраиваем мок хранилища с сохраненными данными
      const apiKey = 'sk-or-v1-test-key-pin-login';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      final result = await authManager.handlePinLogin(pin);

      expect(result.success, isTrue);
      expect(result.message, equals(apiKey));
    });

    test('handlePinLogin - ошибка при неверном PIN', () async {
      // Настраиваем мок хранилища с сохраненными данными
      const apiKey = 'sk-or-v1-test-key-wrong-pin';
      const correctPin = '5678';
      final pinHash = AuthStorage.hashPin(correctPin);

      await mockStorage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      const wrongPin = '9999';
      final result = await authManager.handlePinLogin(wrongPin);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid PIN'));
    });

    test('handlePinLogin - ошибка при неверном формате PIN', () async {
      const invalidPin = '123'; // Не 4 цифры

      final result = await authManager.handlePinLogin(invalidPin);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid PIN format'));
      expect(result.message, contains('4 digits'));
    });

    test('handlePinLogin - ошибка при отсутствии данных аутентификации', () async {
      const pin = '1234';

      final result = await authManager.handlePinLogin(pin);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid PIN'));
    });

    test('handlePinLogin - ошибка при проверке PIN в БД', () async {
      // Настраиваем мок хранилища
      const apiKey = 'sk-or-v1-test-key-pin-error';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      // Настраиваем мок для ошибки при проверке PIN
      mockStorage.setVerifyPinShouldFail(true);

      final result = await authManager.handlePinLogin(pin);

      expect(result.success, isFalse);
      expect(result.message, contains('Error verifying PIN'));
    });

    test('handlePinLogin - ошибка при извлечении API ключа из БД', () async {
      // Настраиваем мок хранилища
      const apiKey = 'sk-or-v1-test-key-api-error';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      // Настраиваем мок для ошибки при извлечении API ключа
      mockStorage.setGetApiKeyShouldFail(true);

      final result = await authManager.handlePinLogin(pin);

      expect(result.success, isFalse);
      expect(result.message, contains('Error retrieving API key'));
    });

    test('handlePinLogin - ошибка при отсутствии API ключа в БД', () async {
      // Настраиваем мок хранилища без API ключа
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      // Сохраняем только PIN хэш, но не API ключ
      await mockStorage.saveAuth(
        apiKey: '', // Пустой ключ
        pinHash: pinHash,
        provider: 'openrouter',
      );

      final result = await authManager.handlePinLogin(pin);

      expect(result.success, isFalse);
      expect(result.message, contains('Authentication data not found'));
    });
  });

  group('AuthManager handleReset Tests', () {
    late MockAuthStorage mockStorage;
    late MockAuthValidator mockValidator;
    late AuthManager authManager;

    setUp(() {
      mockStorage = MockAuthStorage();
      mockValidator = MockAuthValidator();
      authManager = AuthManager(
        storage: mockStorage,
        validator: mockValidator,
      );
      mockStorage.reset();
      mockValidator.reset();
    });

    test('handleReset - успешный сброс данных аутентификации', () async {
      // Настраиваем мок хранилища с сохраненными данными
      const apiKey = 'sk-or-v1-test-key-reset';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      // Проверяем, что данные есть
      expect(await mockStorage.hasAuth(), isTrue);

      // Выполняем сброс
      final result = await authManager.handleReset();

      expect(result, isTrue);
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleReset - успешный сброс при отсутствии данных', () async {
      // Данных нет, но сброс должен быть успешным
      final result = await authManager.handleReset();

      expect(result, isTrue);
      expect(await mockStorage.hasAuth(), isFalse);
    });

    test('handleReset - ошибка при сбросе данных', () async {
      // Настраиваем мок хранилища с сохраненными данными
      const apiKey = 'sk-or-v1-test-key-reset-error';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      // Настраиваем мок для ошибки при очистке
      mockStorage.setClearAuthShouldFail(true);

      final result = await authManager.handleReset();

      expect(result, isFalse);
    });

    test('handleReset - ошибка при проверке удаления данных', () async {
      // Настраиваем мок хранилища с сохраненными данными
      const apiKey = 'sk-or-v1-test-key-reset-verify-error';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      // Настраиваем мок для ошибки при проверке hasAuth после очистки
      // clearAuth успешен, но hasAuth выбросит исключение
      mockStorage.setHasAuthShouldFail(true);

      // В этом случае метод должен вернуть true (данные могли быть удалены)
      final result = await authManager.handleReset();

      expect(result, isTrue);
    });
  });

  group('AuthManager handleApiKeyLogin Tests', () {
    late MockAuthStorage mockStorage;
    late MockAuthValidator mockValidator;
    late AuthManager authManager;

    setUp(() {
      mockStorage = MockAuthStorage();
      mockValidator = MockAuthValidator();
      authManager = AuthManager(
        storage: mockStorage,
        validator: mockValidator,
      );
      mockStorage.reset();
      mockValidator.reset();
    });

    test('handleApiKeyLogin - обновление существующего ключа с сохранением PIN', () async {
      // Настраиваем существующие данные
      const oldApiKey = 'sk-or-v1-old-key';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: oldApiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      // Настраиваем мок валидатора для нового ключа
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '200.00',
          balance: 200.0,
          provider: 'openrouter',
        ),
      );

      const newApiKey = 'sk-or-v1-new-key';

      final result = await authManager.handleApiKeyLogin(newApiKey);

      expect(result.success, isTrue);
      expect(result.message, equals('API key updated successfully'));
      expect(result.balance, equals('200.00'));

      // Проверяем, что PIN сохранился
      final storedPinHash = await mockStorage.getPinHash();
      expect(storedPinHash, equals(pinHash));

      // Проверяем, что новый ключ сохранен
      final storedApiKey = await mockStorage.getApiKey();
      expect(storedApiKey, equals(newApiKey));
    });

    test('handleApiKeyLogin - первый вход с новым ключом (генерация PIN)', () async {
      // Данных нет
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '150.00',
          balance: 150.0,
          provider: 'openrouter',
        ),
      );

      const apiKey = 'sk-or-v1-first-login-key';

      final result = await authManager.handleApiKeyLogin(apiKey);

      expect(result.success, isTrue);
      expect(result.message.length, equals(4)); // PIN должен быть 4-значным
      expect(int.tryParse(result.message), isNotNull);
      expect(int.parse(result.message), greaterThanOrEqualTo(1000));
      expect(int.parse(result.message), lessThanOrEqualTo(9999));
      expect(result.balance, equals('150.00'));

      // Проверяем, что данные сохранены
      expect(await mockStorage.hasAuth(), isTrue);
    });

    test('handleApiKeyLogin - ошибка при валидации нового ключа', () async {
      // Настраиваем существующие данные
      const oldApiKey = 'sk-or-v1-old-key';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: oldApiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      // Настраиваем мок валидатора для неверного ключа
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: false,
          message: 'Invalid API key',
          balance: 0.0,
          provider: 'openrouter',
        ),
      );

      const newApiKey = 'sk-or-v1-invalid-key';

      final result = await authManager.handleApiKeyLogin(newApiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid API key'));

      // Проверяем, что старый ключ не изменился
      final storedApiKey = await mockStorage.getApiKey();
      expect(storedApiKey, equals(oldApiKey));
    });

    test('handleApiKeyLogin - ошибка при проверке существующих данных', () async {
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'openrouter',
        ),
      );

      // Настраиваем мок для ошибки при проверке hasAuth
      mockStorage.setHasAuthShouldFail(true);

      const apiKey = 'sk-or-v1-check-error';

      final result = await authManager.handleApiKeyLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Error checking existing'));
    });

    test('handleApiKeyLogin - ошибка при сохранении данных', () async {
      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '100.00',
          balance: 100.0,
          provider: 'openrouter',
        ),
      );

      // Настраиваем мок для ошибки при сохранении
      mockStorage.setSaveShouldFail(true);

      const apiKey = 'sk-or-v1-save-error';

      final result = await authManager.handleApiKeyLogin(apiKey);

      expect(result.success, isFalse);
      expect(result.message, contains('Failed to save'));
    });

    test('handleApiKeyLogin - обновление ключа с нулевым балансом', () async {
      // Настраиваем существующие данные
      const oldApiKey = 'sk-or-v1-old-key';
      const pin = '1234';
      final pinHash = AuthStorage.hashPin(pin);

      await mockStorage.saveAuth(
        apiKey: oldApiKey,
        pinHash: pinHash,
        provider: 'openrouter',
      );

      mockValidator.setValidationResult(
        const ApiKeyValidationResult(
          isValid: true,
          message: '0.00',
          balance: 0.0,
          provider: 'openrouter',
        ),
      );

      const newApiKey = 'sk-or-v1-zero-balance-key';

      final result = await authManager.handleApiKeyLogin(newApiKey);

      expect(result.success, isTrue);
      expect(result.message, equals('API key updated successfully'));
      expect(result.balance, equals('0.00'));
    });
  });
}
