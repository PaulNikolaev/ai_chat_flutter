import 'package:ai_chat/config/config.dart';
import 'auth_storage.dart';
import 'auth_validator.dart';

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
/// **Основные функции:**
/// - Первый вход с валидацией API ключа и генерацией PIN
/// - Повторный вход по PIN коду
/// - Обновление API ключа с сохранением PIN
/// - Сброс всех данных аутентификации
/// - Проверка статуса аутентификации
///
/// **Поддерживаемые провайдеры:**
/// - OpenRouter (ключи начинаются с `sk-or-v1-...`)
/// - VSEGPT (ключи начинаются с `sk-or-vv-...`)
///
/// **Пример использования:**
/// ```dart
/// final manager = AuthManager();
///
/// // Первый вход
/// final result = await manager.handleFirstLogin('sk-or-v1-...');
/// if (result.success) {
///   print('PIN: ${result.message}');
///   print('Balance: ${result.balance}');
/// }
///
/// // Повторный вход по PIN
/// final pinResult = await manager.handlePinLogin('1234');
/// if (pinResult.success) {
///   print('API Key: ${pinResult.message}');
/// }
/// ```
class AuthManager {
  /// Хранилище данных аутентификации.
  ///
  /// Используется для сохранения и получения данных из базы данных SQLite.
  /// Автоматически выполняет миграцию данных из старых хранилищ.
  final AuthStorage storage;

  /// Валидатор учетных данных.
  ///
  /// Используется для валидации API ключей через соответствующие API endpoints.
  /// Поддерживает валидацию для OpenRouter и VSEGPT провайдеров.
  final AuthValidator validator;

  /// Создает экземпляр [AuthManager].
  ///
  /// Если параметры не указаны, создаются экземпляры по умолчанию:
  /// - [storage] создается как новый экземпляр AuthStorage
  /// - [validator] создается с настройками из EnvConfig
  ///
  /// Параметры:
  /// - [storage]: Экземпляр AuthStorage для хранения данных (опционально).
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
  /// - При успехе: success=true, message=указанный пользователем PIN, balance=баланс
  /// - При ошибке: success=false, message=сообщение об ошибке
  Future<AuthResult> handleFirstLogin(
    String apiKey,
    String pin,
  ) async {
    // Проверка формата ключа перед валидацией
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'API key cannot be empty. Please enter a valid API key.',
      );
    }

    // Проверяем базовый формат ключа (должен начинаться с sk-or-)
    if (!trimmedKey.startsWith('sk-or-')) {
      return const AuthResult(
        success: false,
        message:
            'Invalid API key format. Key must start with "sk-or-vv-" (VSEGPT) or "sk-or-v1-" (OpenRouter).',
      );
    }

    // Проверяем формат пользовательского PIN (обязателен при первом входе)
    // Проверяем формат PIN: 4 цифры (0000–9999), допускаем ведущие нули для удобства
    if (!AuthValidator.validatePinFormat(pin, allowLeadingZeros: true)) {
      return const AuthResult(
        success: false,
        message: 'Invalid PIN format. PIN must be 4 digits (0000-9999).',
      );
    }

    // Шаг 1: Валидируем API ключ
    // Метод validateApiKey автоматически определяет провайдера по префиксу ключа
    // и выполняет валидацию через соответствующий API endpoint
    ApiKeyValidationResult validationResult;
    try {
      validationResult = await validator.validateApiKey(apiKey);
    } catch (e) {
      // Обработка неожиданных ошибок при валидации
      return AuthResult(
        success: false,
        message:
            'Unexpected error during API key validation: $e. Please try again.',
      );
    }

    // Обработка неверного формата ключа
    if (!validationResult.isValid) {
      final errorMessage = validationResult.message;

      // Проверяем, является ли это ошибкой формата ключа
      if (validationResult.provider == 'unknown' ||
          errorMessage.contains('Invalid API key format') ||
          errorMessage.contains('must start with')) {
        return const AuthResult(
          success: false,
          message:
              'Invalid API key format. Key must start with "sk-or-vv-" (VSEGPT) or "sk-or-v1-" (OpenRouter).',
        );
      }

      // Обработка неверного ключа (401 Unauthorized)
      if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized') ||
          errorMessage.contains('Invalid') && errorMessage.contains('key')) {
        return const AuthResult(
          success: false,
          message:
              'Invalid API key. Please check that your key is correct and has not been revoked.',
        );
      }

      // Обработка сетевых ошибок
      if (errorMessage.contains('Network error') ||
          errorMessage.contains('network') ||
          errorMessage.contains('Connection')) {
        return const AuthResult(
          success: false,
          message:
              'Network error: Unable to connect to the API server. Please check your internet connection and try again.',
        );
      }

      // Обработка таймаута
      if (errorMessage.contains('timeout') ||
          errorMessage.contains('Timeout')) {
        return const AuthResult(
          success: false,
          message:
              'Request timeout: The server did not respond in time. Please check your internet connection and try again.',
        );
      }

      // Обработка ошибок сервера (5xx)
      if (errorMessage.contains('server error') ||
          errorMessage.contains('500') ||
          errorMessage.contains('502') ||
          errorMessage.contains('503')) {
        return const AuthResult(
          success: false,
          message:
              'Server error: The API server is temporarily unavailable. Please try again later.',
        );
      }

      // Обработка rate limit (429)
      if (errorMessage.contains('429') || errorMessage.contains('rate limit')) {
        return const AuthResult(
          success: false,
          message:
              'Rate limit exceeded: Too many requests. Please wait a moment and try again.',
        );
      }

      // Для всех остальных ошибок возвращаем оригинальное сообщение
      return AuthResult(
        success: false,
        message: errorMessage,
      );
    }

    // Проверяем, что провайдер определен корректно
    if (validationResult.provider != 'openrouter' &&
        validationResult.provider != 'vsegpt') {
      return const AuthResult(
        success: false,
        message:
            'Invalid provider detected. Supported providers: openrouter, vsegpt',
      );
    }

    // Шаг 2: Проверяем баланс аккаунта
    // Баланс должен быть неотрицательным (>= 0), включая нулевой баланс
    // Это позволяет подключаться даже с нулевым балансом для тестирования
    if (validationResult.balance < 0) {
      return AuthResult(
        success: false,
        message:
            'Insufficient balance: Your account balance is negative (${validationResult.balance.toStringAsFixed(2)}). Please add funds to your account before continuing.',
      );
    }

    // Информируем о нулевом балансе (но разрешаем подключение)
    if (validationResult.balance == 0) {
      // Это информационное сообщение, но не ошибка - продолжаем выполнение
    }

    // Шаг 3: Используем пользовательский PIN (предварительно проверенный)
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
        message:
            'Failed to save authentication data to database. Please check database permissions and try again.',
      );
    }

    // Дополнительная проверка: убеждаемся, что данные действительно сохранены в БД
    bool hasAuthData;
    try {
      hasAuthData = await storage.hasAuth();
    } catch (e) {
      return AuthResult(
        success: false,
        message:
            'Error verifying saved authentication data: $e. Please try again.',
      );
    }

    if (!hasAuthData) {
      return const AuthResult(
        success: false,
        message:
            'Authentication data was not saved correctly. Please try again.',
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
  /// Выполняет полный цикл аутентификации по PIN:
  /// 1. Проверяет формат PIN (должен быть 4-значным числом 1000-9999)
  /// 2. Проверяет PIN через базу данных (сравнивает хэш введенного PIN с сохраненным)
  /// 3. Извлекает API ключ из базы данных после успешной проверки PIN
  ///
  /// Проверка PIN выполняется через AuthStorage, который использует AuthRepository
  /// для работы с базой данных. PIN хэшируется через SHA-256 и сравнивается
  /// с сохраненным хэшем в таблице `auth`.
  ///
  /// API ключ извлекается из БД и автоматически расшифровывается перед возвратом.
  ///
  /// Параметры:
  /// - [pin]: PIN код для проверки.
  ///
  /// Возвращает [AuthResult] с результатом операции:
  /// - При успехе: success=true, message=расшифрованный API ключ
  /// - При ошибке: success=false, message=сообщение об ошибке
  Future<AuthResult> handlePinLogin(String pin) async {
    // Шаг 1: Проверяем формат PIN перед проверкой в БД
    // PIN должен быть 4-значным числом (0000-9999), допускаем ведущие нули
    if (!AuthValidator.validatePinFormat(pin, allowLeadingZeros: true)) {
      return const AuthResult(
        success: false,
        message: 'Invalid PIN format. PIN must be 4 digits (0000-9999).',
      );
    }

    // Шаг 2: Проверяем PIN через базу данных
    // Метод verifyPin хэширует введенный PIN через SHA-256 и сравнивает
    // с сохраненным хэшем в таблице auth через AuthRepository
    bool isValid;
    try {
      isValid = await storage.verifyPin(pin);
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Error verifying PIN: $e. Please try again.',
      );
    }

    if (!isValid) {
      return const AuthResult(
        success: false,
        message: 'Invalid PIN. Please check your PIN and try again.',
      );
    }

    // Шаг 3: Извлекаем активный API ключ из базы данных после успешной проверки PIN
    // API ключ автоматически расшифровывается при извлечении из БД
    String? apiKey;
    String? provider;
    try {
      // Получаем список всех доступных ключей, отсортированных по last_used
      final allKeys = await storage.getAllApiKeys();

      if (allKeys.isEmpty) {
        return const AuthResult(
          success: false,
          message:
              'No API keys found in database. Please log in with your API key again.',
        );
      }

      // Выбираем активного провайдера (последнего использованного)
      // Список уже отсортирован по last_used DESC в getAllApiKeys()
      provider = allKeys.first['provider'];

      // Если провайдер не найден в первой записи, берем любого доступного
      if (provider == null || provider.isEmpty) {
        // Ищем первого провайдера с непустым значением
        for (final key in allKeys) {
          final keyProvider = key['provider'];
          if (keyProvider != null && keyProvider.isNotEmpty) {
            provider = keyProvider;
            break;
          }
        }
      }

      // Если все еще не нашли провайдера, это ошибка
      if (provider == null || provider.isEmpty) {
        return const AuthResult(
          success: false,
          message:
              'Invalid provider data in database. Please log in with your API key again.',
        );
      }

      // Получаем API ключ для найденного провайдера
      apiKey = await storage.getApiKey(provider: provider);
    } catch (e) {
      return AuthResult(
        success: false,
        message:
            'Error retrieving API key from database: $e. Please try again.',
      );
    }

    if (apiKey == null || apiKey.isEmpty) {
      return const AuthResult(
        success: false,
        message:
            'Authentication data not found in database. Please log in with your API key again.',
      );
    }

    // Обновляем дату последнего использования для активного провайдера
    // Это гарантирует, что при следующем входе будет выбран тот же провайдер
    await storage.updateLastUsed(provider);

    // Возвращаем успешный результат с расшифрованным API ключом
    return AuthResult(
      success: true,
      message: apiKey,
    );
  }

  /// Обрабатывает вход по API ключу (можно использовать даже если данные уже существуют).
  ///
  /// Выполняет полный цикл аутентификации или обновления API ключа:
  /// 1. Валидирует API ключ через соответствующий провайдер
  /// 2. Проверяет баланс аккаунта (должен быть >= 0)
  /// 3. Проверяет наличие существующих данных аутентификации
  /// 4. Сохраняет существующий PIN при обновлении ключа (если данные уже есть)
  /// 5. Генерирует новый PIN только для первого входа
  /// 6. Сохраняет или обновляет данные в базе данных
  ///
  /// **Важно:** При обновлении существующего API ключа PIN сохраняется.
  /// Это позволяет пользователю продолжать использовать тот же PIN код
  /// после обновления ключа.
  ///
  /// Параметры:
  /// - [apiKey]: API ключ для валидации и сохранения.
  ///
  /// Возвращает [AuthResult] с результатом операции:
  /// - При успехе (обновление): success=true, message='API key updated successfully', balance=баланс
  /// - При успехе (первый вход): success=true, message=сгенерированный PIN, balance=баланс
  /// - При ошибке: success=false, message=сообщение об ошибке
  Future<AuthResult> handleApiKeyLogin(String apiKey) async {
    // Шаг 1: Валидируем API ключ
    ApiKeyValidationResult validationResult;
    try {
      validationResult = await validator.validateApiKey(apiKey);
    } catch (e) {
      return AuthResult(
        success: false,
        message:
            'Unexpected error during API key validation: $e. Please try again.',
      );
    }

    if (!validationResult.isValid) {
      // Используем сообщение об ошибке из валидатора
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
        message:
            'Invalid provider detected. Supported providers: openrouter, vsegpt',
      );
    }

    // Шаг 2: Проверяем баланс аккаунта
    // Баланс должен быть неотрицательным (>= 0), включая нулевой баланс
    if (validationResult.balance < 0) {
      return AuthResult(
        success: false,
        message:
            'Insufficient balance: Your account balance is negative (${validationResult.balance.toStringAsFixed(2)}). Please add funds to your account before continuing.',
      );
    }

    // Шаг 3: Проверяем, существуют ли уже данные аутентификации
    bool hasExisting;
    try {
      hasExisting = await storage.hasAuth();
    } catch (e) {
      return AuthResult(
        success: false,
        message:
            'Error checking existing authentication data: $e. Please try again.',
      );
    }

    String pinHash;
    String? generatedPin;

    if (hasExisting) {
      // Шаг 4: Обновляем существующие данные с новым API ключом
      // Важно: Сохраняем существующий PIN хэш, чтобы пользователь мог
      // продолжать использовать тот же PIN код после обновления ключа
      String? existingPinHash;
      try {
        existingPinHash = await storage.getPinHash();
      } catch (e) {
        return AuthResult(
          success: false,
          message: 'Error retrieving existing PIN hash: $e. Please try again.',
        );
      }

      if (existingPinHash != null && existingPinHash.isNotEmpty) {
        // Сохраняем существующий PIN при обновлении ключа
        pinHash = existingPinHash;
      } else {
        // Генерируем новый PIN, если почему-то отсутствует
        generatedPin = AuthValidator.generatePin();
        pinHash = AuthValidator.hashPin(generatedPin);
      }
    } else {
      // Шаг 5: Генерируем новый PIN для первого входа
      generatedPin = AuthValidator.generatePin();
      pinHash = AuthValidator.hashPin(generatedPin);
    }

    // Шаг 6: Сохраняем или обновляем данные аутентификации в базе данных
    // API ключ автоматически шифруется перед сохранением в БД
    bool saved;
    try {
      saved = await storage.saveAuth(
        apiKey: apiKey,
        pinHash: pinHash,
        provider: validationResult.provider,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message:
            'Error saving authentication data to database: $e. Please try again.',
      );
    }

    if (!saved) {
      return const AuthResult(
        success: false,
        message:
            'Failed to save authentication data to database. Please check database permissions and try again.',
      );
    }

    // Дополнительная проверка: убеждаемся, что данные действительно сохранены
    bool hasAuthData;
    try {
      hasAuthData = await storage.hasAuth();
    } catch (e) {
      // Если проверка не удалась, считаем операцию успешной
      // (данные могли быть сохранены, но проверка не удалась)
      hasAuthData = true;
    }

    if (!hasAuthData) {
      return const AuthResult(
        success: false,
        message:
            'Authentication data was not saved correctly. Please try again.',
      );
    }

    // Возвращаем результат в зависимости от того, были ли существующие данные
    if (hasExisting) {
      // При обновлении ключа PIN сохраняется, поэтому не возвращаем его
      return AuthResult(
        success: true,
        message: 'API key updated successfully',
        balance: validationResult.message,
      );
    } else {
      // При первом входе возвращаем сгенерированный PIN
      return AuthResult(
        success: true,
        message: generatedPin ?? '',
        balance: validationResult.message,
      );
    }
  }

  /// Сбрасывает аутентификацию, очищая сохраненные данные.
  ///
  /// Выполняет полную очистку данных аутентификации:
  /// 1. Удаляет все данные из базы данных (таблица `auth`)
  /// 2. Очищает старые хранилища (flutter_secure_storage и shared_preferences)
  /// 3. Проверяет, что данные действительно удалены
  ///
  /// Все данные аутентификации удаляются из БД через AuthStorage,
  /// который использует AuthRepository для удаления записей из таблицы `auth`.
  /// Также очищаются старые хранилища для полной очистки.
  ///
  /// **Важно:** Подтверждение сброса должно быть выполнено в UI перед вызовом этого метода.
  ///
  /// Возвращает true, если сброс выполнен успешно, иначе false.
  Future<bool> handleReset() async {
    try {
      // Очищаем данные аутентификации из БД и старых хранилищ
      final cleared = await storage.clearAuth();

      if (!cleared) {
        // Если очистка не удалась, возвращаем false
        return false;
      }

      // Проверяем, что данные действительно удалены из БД
      bool hasAuthData;
      try {
        hasAuthData = await storage.hasAuth();
      } catch (e) {
        // Если проверка не удалась, считаем, что очистка прошла успешно
        // (данные могли быть удалены, но проверка не удалась)
        return true;
      }

      // Если данные все еще есть, возвращаем false
      if (hasAuthData) {
        return false;
      }

      // Все данные успешно удалены
      return true;
    } catch (e) {
      // В случае неожиданной ошибки возвращаем false
      return false;
    }
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
  /// Параметры:
  /// - [provider]: Провайдер для получения ключа (опционально, если null - возвращает активный).
  ///
  /// Возвращает сохраненный API ключ или пустую строку, если не найден.
  Future<String> getStoredApiKey({String? provider}) async {
    final apiKey = await storage.getApiKey(provider: provider);
    return apiKey ?? '';
  }

  /// Получает все сохраненные API ключи.
  ///
  /// Возвращает список Map, каждый содержит 'api_key', 'provider', 'created_at', 'last_used'.
  Future<List<Map<String, String>>> getAllStoredApiKeys() async {
    return await storage.getAllApiKeys();
  }

  /// Удаляет API ключ для указанного провайдера.
  ///
  /// Параметры:
  /// - [provider]: Провайдер для удаления ключа.
  ///
  /// Возвращает true, если удаление выполнено успешно.
  Future<bool> deleteApiKey(String provider) async {
    return await storage.deleteApiKey(provider);
  }

  /// Обновляет дату последнего использования для указанного провайдера.
  ///
  /// Параметры:
  /// - [provider]: Провайдер для обновления.
  ///
  /// Возвращает true, если обновление выполнено успешно.
  Future<bool> updateLastUsed(String provider) async {
    return await storage.updateLastUsed(provider);
  }

  /// Получает сохраненного провайдера.
  ///
  /// Возвращает 'openrouter' или 'vsegpt', или null, если не найден.
  Future<String?> getStoredProvider() async {
    return await storage.getProvider();
  }

  /// Обновляет активного провайдера (переключает на другой существующий ключ).
  ///
  /// Проверяет наличие ключа для указанного провайдера и обновляет дату последнего использования.
  ///
  /// **Параметры:**
  /// - [newProvider]: Новый провайдер ('openrouter' или 'vsegpt').
  ///
  /// **Возвращает:** [AuthResult] с результатом операции.
  Future<AuthResult> updateProvider(String newProvider) async {
    // Проверяем, что провайдер валиден
    if (newProvider != 'openrouter' && newProvider != 'vsegpt') {
      return const AuthResult(
        success: false,
        message: 'Invalid provider. Supported providers: openrouter, vsegpt',
      );
    }

    // Проверяем, существует ли ключ для этого провайдера
    final apiKey = await storage.getApiKey(provider: newProvider);
    if (apiKey == null || apiKey.isEmpty) {
      return AuthResult(
        success: false,
        message:
            'API key for $newProvider not found. Please add an API key for this provider first.',
      );
    }

    // Обновляем дату последнего использования
    final updated = await storage.updateLastUsed(newProvider);
    if (!updated) {
      return const AuthResult(
        success: false,
        message: 'Failed to update provider. Please try again.',
      );
    }

    return AuthResult(
      success: true,
      message: 'Provider switched to $newProvider',
    );
  }

  /// Добавляет новый API ключ от другого провайдера.
  ///
  /// Валидирует ключ и добавляет его к существующим ключам под тем же PIN.
  /// Если ключ для этого провайдера уже существует, он будет обновлен.
  ///
  /// **Параметры:**
  /// - [apiKey]: API ключ для добавления.
  ///
  /// **Возвращает:** [AuthResult] с результатом операции.
  Future<AuthResult> addApiKey(String apiKey) async {
    // Валидируем API ключ
    ApiKeyValidationResult validationResult;
    try {
      validationResult = await validator.validateApiKey(apiKey);
    } catch (e) {
      return AuthResult(
        success: false,
        message:
            'Unexpected error during API key validation: $e. Please try again.',
      );
    }

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
        message:
            'Invalid provider detected. Supported providers: openrouter, vsegpt',
      );
    }

    // Проверяем баланс аккаунта
    if (validationResult.balance < 0) {
      return AuthResult(
        success: false,
        message:
            'Insufficient balance: Your account balance is negative (${validationResult.balance.toStringAsFixed(2)}). Please add funds to your account before continuing.',
      );
    }

    // Получаем существующий PIN хэш или создаем новый
    String pinHash;
    String? generatedPin;
    bool isNewAuth = false;

    try {
      final existingPinHash = await storage.getPinHash();
      if (existingPinHash != null && existingPinHash.isNotEmpty) {
        // Используем существующий PIN хэш
        pinHash = existingPinHash;
      } else {
        // Генерируем новый PIN для первого ключа
        generatedPin = AuthValidator.generatePin();
        pinHash = AuthValidator.hashPin(generatedPin);
        isNewAuth = true;
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Error retrieving PIN hash: $e. Please try again.',
      );
    }

    // Сохраняем или обновляем ключ для этого провайдера
    final saved = await storage.saveAuth(
      apiKey: apiKey,
      pinHash: pinHash,
      provider: validationResult.provider,
    );

    if (!saved) {
      return const AuthResult(
        success: false,
        message: 'Failed to save API key. Please try again.',
      );
    }

    // Обновляем дату последнего использования
    await storage.updateLastUsed(validationResult.provider);

    // Возвращаем результат
    if (isNewAuth && generatedPin != null) {
      // Если это первый ключ, возвращаем сгенерированный PIN
      return AuthResult(
        success: true,
        message: generatedPin,
        balance: validationResult.message,
      );
    } else {
      return AuthResult(
        success: true,
        message: 'API key for ${validationResult.provider} added successfully',
        balance: validationResult.message,
      );
    }
  }
}
