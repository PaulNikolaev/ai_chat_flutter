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
  /// Выполняет полный цикл аутентификации:
  /// 1. Валидирует API ключ через соответствующий провайдер (OpenRouter или VSEGPT)
  /// 2. Проверяет баланс аккаунта (должен быть >= 0)
  /// 3. Генерирует 4-значный PIN код
  /// 4. Сохраняет данные в базу данных через AuthStorage
  ///
  /// Валидация ключа выполняется для обоих провайдеров:
  /// - OpenRouter: ключи начинаются с 'sk-or-v1-...'
  /// - VSEGPT: ключи начинаются с 'sk-or-vv-...'
  ///
  /// Проверка баланса выполняется через соответствующий API endpoint:
  /// - OpenRouter: /api/v1/credits
  /// - VSEGPT: /v1/balance
  ///
  /// PIN генерируется только при успешной валидации и неотрицательном балансе (>= 0).
  /// Данные сохраняются в БД только после успешной валидации и проверки баланса.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для валидации и сохранения.
  ///
  /// Возвращает [AuthResult] с результатом операции:
  /// - При успехе: success=true, message=сгенерированный PIN, balance=баланс
  /// - При ошибке: success=false, message=сообщение об ошибке
  Future<AuthResult> handleFirstLogin(String apiKey) async {
    // Шаг 1: Валидируем API ключ
    // Метод validateApiKey автоматически определяет провайдера по префиксу ключа
    // и выполняет валидацию через соответствующий API endpoint
    final validationResult = await validator.validateApiKey(apiKey);

    // Проверяем результат валидации
    if (!validationResult.isValid) {
      return AuthResult(
        success: false,
        message: validationResult.message,
      );
    }

    // Проверяем, что провайдер определен корректно
    if (validationResult.provider != 'openrouter' && 
        validationResult.provider != 'vsegpt') {
      return const AuthResult(
        success: false,
        message: 'Invalid provider detected. Supported providers: openrouter, vsegpt',
      );
    }

    // Шаг 2: Проверяем баланс аккаунта
    // Баланс должен быть неотрицательным (>= 0), включая нулевой баланс
    // Это позволяет подключаться даже с нулевым балансом для тестирования
    if (validationResult.balance < 0) {
      return AuthResult(
        success: false,
        message: 'API key has negative balance. Current balance: ${validationResult.balance.toStringAsFixed(2)}',
      );
    }

    // Шаг 3: Генерируем PIN код только при успешной валидации и неотрицательном балансе
    // PIN генерируется как случайное 4-значное число от 1000 до 9999
    final pin = AuthValidator.generatePin();
    // Хэшируем PIN перед сохранением в БД
    final pinHash = AuthValidator.hashPin(pin);

    // Шаг 4: Сохраняем данные аутентификации в базу данных
    // Данные сохраняются через AuthStorage, который использует AuthRepository
    // API ключ автоматически шифруется перед сохранением в БД
    final saved = await storage.saveAuth(
      apiKey: apiKey,
      pinHash: pinHash,
      provider: validationResult.provider,
    );

    // Проверяем, что данные успешно сохранены
    if (!saved) {
      return const AuthResult(
        success: false,
        message: 'Failed to save authentication data to database',
      );
    }

    // Дополнительная проверка: убеждаемся, что данные действительно сохранены в БД
    final hasAuthData = await storage.hasAuth();
    if (!hasAuthData) {
      return const AuthResult(
        success: false,
        message: 'Authentication data was not saved correctly. Please try again',
      );
    }

    // Возвращаем успешный результат с сгенерированным PIN и балансом
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
