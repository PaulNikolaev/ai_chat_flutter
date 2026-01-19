import 'dart:developer' as developer;
import 'auth_storage.dart';
import 'auth_validator.dart';
import '../config/env.dart';

/// Результат операции аутентификации.
class AuthResult {
  /// Успешна ли операция.
  final bool success;

  /// Сообщение (PIN, API ключ или ошибка).
  final String message;

  /// Баланс аккаунта (если доступен).
  final String balance;

  const AuthResult({
    required this.success,
    required this.message,
    this.balance = '',
  });
}

/// Менеджер процесса аутентификации.
///
/// Координирует процессы аутентификации, включая валидацию API ключей,
/// генерацию PIN, проверку входа и управление состоянием аутентификации.
///
/// Пример использования:
/// ```dart
/// final manager = AuthManager();
/// final result = await manager.handleFirstLogin('sk-or-v1-...');
/// if (result.success) {
///   print('PIN: ${result.message}');
/// }
/// ```
class AuthManager {
  /// Хранилище данных аутентификации.
  final AuthStorage storage;

  /// Валидатор учетных данных.
  final AuthValidator validator;

  /// Создает экземпляр [AuthManager].
  ///
  /// Параметры:
  /// - [storage]: Экземпляр AuthStorage для хранения данных.
  /// - [validator]: Экземпляр AuthValidator для валидации (опционально).
  AuthManager({
    AuthStorage? storage,
    AuthValidator? validator,
  })  : storage = storage ?? AuthStorage(),
        validator = validator ??
            AuthValidator(
              openRouterBaseUrl: EnvConfig.openRouterBaseUrl,
              vsegptBaseUrl: EnvConfig.vsegptBaseUrl.isEmpty
                  ? null
                  : EnvConfig.vsegptBaseUrl,
            );

  /// Обрабатывает первый вход с валидацией API ключа.
  ///
  /// Валидирует API ключ, проверяет баланс, генерирует PIN и сохраняет
  /// данные аутентификации.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для валидации и сохранения.
  ///
  /// Возвращает [AuthResult] с результатом операции:
  /// - При успехе: success=true, message=сгенерированный PIN, balance=баланс
  /// - При ошибке: success=false, message=сообщение об ошибке
  Future<AuthResult> handleFirstLogin(String apiKey) async {
    developer.log('[AUTH] Starting first login validation', name: 'AuthManager');
    developer.log('[AUTH] API Key prefix: ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...', name: 'AuthManager');
    
    // Валидируем API ключ
    final validationResult = await validator.validateApiKey(apiKey);

    if (!validationResult.isValid) {
      developer.log('[AUTH] ❌ Validation failed: ${validationResult.message}', name: 'AuthManager');
      developer.log('[AUTH] Provider: ${validationResult.provider}, Balance: ${validationResult.balance}', name: 'AuthManager');
      return AuthResult(
        success: false,
        message: validationResult.message,
      );
    }

    developer.log('[AUTH] ✅ Validation successful', name: 'AuthManager');
    developer.log('[AUTH] Provider: ${validationResult.provider}, Balance: ${validationResult.balance}', name: 'AuthManager');

    // Проверяем, что баланс неотрицательный (разрешаем баланс >= 0, включая 0)
    developer.log('[AUTH] Balance from validation: ${validationResult.balance}', name: 'AuthManager');
    developer.log('[AUTH] Balance message: ${validationResult.message}', name: 'AuthManager');
    
    if (validationResult.balance < 0) {
      developer.log('[AUTH] ❌ Balance check failed: balance = ${validationResult.balance}', name: 'AuthManager');
      developer.log('[AUTH] Validation result details: isValid=${validationResult.isValid}, provider=${validationResult.provider}', name: 'AuthManager');
      return AuthResult(
        success: false,
        message: 'API key has negative balance. Current balance: ${validationResult.balance}',
      );
    }
    
    developer.log('[AUTH] ✅ Balance check passed: balance = ${validationResult.balance}', name: 'AuthManager');

    // Генерируем PIN
    final pin = AuthValidator.generatePin();
    final pinHash = AuthValidator.hashPin(pin);
    developer.log('[AUTH] PIN generated: $pin', name: 'AuthManager');

    // Сохраняем данные аутентификации
    final saved = await storage.saveAuth(
      apiKey: apiKey,
      pinHash: pinHash,
      provider: validationResult.provider,
    );

    if (!saved) {
      developer.log('[AUTH] ❌ Failed to save authentication data', name: 'AuthManager');
      return const AuthResult(
        success: false,
        message: 'Failed to save authentication data',
      );
    }

    developer.log('[AUTH] ✅ First login completed successfully', name: 'AuthManager');
    developer.log('[AUTH] Provider: ${validationResult.provider}, Balance: ${validationResult.message}', name: 'AuthManager');
    
    return AuthResult(
      success: true,
      message: pin,
      balance: validationResult.message,
    );
  }

  /// Обрабатывает вход по PIN коду.
  ///
  /// Проверяет PIN и получает сохраненный API ключ.
  ///
  /// Параметры:
  /// - [pin]: PIN код для проверки.
  ///
  /// Возвращает [AuthResult] с результатом операции:
  /// - При успехе: success=true, message=API ключ
  /// - При ошибке: success=false, message=сообщение об ошибке
  Future<AuthResult> handlePinLogin(String pin) async {
    // Проверяем формат PIN
    if (!AuthValidator.validatePinFormat(pin)) {
      return const AuthResult(
        success: false,
        message: 'PIN must be 4 digits (1000-9999)',
      );
    }

    // Проверяем PIN
    final isValid = await storage.verifyPin(pin);
    if (!isValid) {
      return const AuthResult(
        success: false,
        message: 'Invalid PIN',
      );
    }

    // Получаем API ключ
    final apiKey = await storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Authentication data not found',
      );
    }

    return AuthResult(
      success: true,
      message: apiKey,
    );
  }

  /// Обрабатывает вход по API ключу (можно использовать даже если данные уже существуют).
  ///
  /// Валидирует API ключ, проверяет баланс и обновляет сохраненные учетные данные,
  /// если данные аутентификации уже существуют.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для валидации.
  ///
  /// Возвращает [AuthResult] с результатом операции:
  /// - При успехе: success=true, message=сообщение об успехе или PIN (если первый вход), balance=баланс
  /// - При ошибке: success=false, message=сообщение об ошибке
  Future<AuthResult> handleApiKeyLogin(String apiKey) async {
    // Валидируем API ключ
    final validationResult = await validator.validateApiKey(apiKey);

    if (!validationResult.isValid) {
      return AuthResult(
        success: false,
        message: validationResult.message,
      );
    }

    // Проверяем, что баланс неотрицательный (разрешаем баланс >= 0, включая 0)
    if (validationResult.balance < 0) {
      return AuthResult(
        success: false,
        message: 'API key has negative balance. Current balance: ${validationResult.balance}',
      );
    }

    // Проверяем, существуют ли уже данные аутентификации
    final hasExisting = await storage.hasAuth();

    String pinHash;
    String? generatedPin;

    if (hasExisting) {
      // Обновляем существующие данные с новым API ключом
      // Сохраняем существующий PIN хэш или генерируем новый
      final existingPinHash = await storage.getPinHash();
      if (existingPinHash != null && existingPinHash.isNotEmpty) {
        // Сохраняем существующий PIN
        pinHash = existingPinHash;
      } else {
        // Генерируем новый PIN, если почему-то отсутствует
        generatedPin = AuthValidator.generatePin();
        pinHash = AuthValidator.hashPin(generatedPin);
      }
    } else {
      // Генерируем новый PIN для первого входа
      generatedPin = AuthValidator.generatePin();
      pinHash = AuthValidator.hashPin(generatedPin);
    }

    // Сохраняем или обновляем данные аутентификации
    final saved = await storage.saveAuth(
      apiKey: apiKey,
      pinHash: pinHash,
      provider: validationResult.provider,
    );

    if (!saved) {
      return const AuthResult(
        success: false,
        message: 'Failed to save authentication data',
      );
    }

    if (hasExisting) {
      return AuthResult(
        success: true,
        message: 'API key updated successfully',
        balance: validationResult.message,
      );
    } else {
      // Возвращаем сгенерированный PIN для первого входа
      return AuthResult(
        success: true,
        message: generatedPin ?? '',
        balance: validationResult.message,
      );
    }
  }

  /// Сбрасывает аутентификацию, очищая сохраненные данные.
  ///
  /// Возвращает true, если сброс выполнен успешно, иначе false.
  Future<bool> handleReset() async {
    return await storage.clearAuth();
  }

  /// Проверяет, аутентифицирован ли пользователь.
  ///
  /// Возвращает true, если данные аутентификации существуют, иначе false.
  Future<bool> isAuthenticated() async {
    return await storage.hasAuth();
  }

  /// Получает сохраненный API ключ без проверки PIN.
  ///
  /// Этот метод полезен для случаев, когда API ключ нужен,
  /// но проверка PIN уже была выполнена.
  ///
  /// Возвращает сохраненный API ключ или пустую строку, если не найден.
  Future<String> getStoredApiKey() async {
    final apiKey = await storage.getApiKey();
    return apiKey ?? '';
  }

  /// Получает сохраненного провайдера.
  ///
  /// Возвращает 'openrouter' или 'vsegpt', или null, если не найден.
  Future<String?> getStoredProvider() async {
    return await storage.getProvider();
  }
}
