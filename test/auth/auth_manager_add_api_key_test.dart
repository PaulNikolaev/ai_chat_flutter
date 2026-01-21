import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_chat/auth/auth_manager.dart';
import 'package:ai_chat/auth/auth_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  FlutterSecureStorage.setMockInitialValues({});
  dotenv.testLoad(fileInput: '');

  AuthValidator makeValidator(String provider) => _FakeValidator(provider);

  group('AuthManager addApiKey', () {
    late AuthManager manager;

    setUp(() {
      // Валидатор без реальных HTTP: сразу отдает валидный результат
      manager = AuthManager(validator: makeValidator('openrouter'));
    });

    test('adds OpenRouter key and updates provider', () async {
      manager = AuthManager(validator: makeValidator('openrouter'));
      final res = await manager.addApiKey('sk-or-v1-test-123');
      expect(res.success, isTrue);

      final provider = await manager.getStoredProvider();
      expect(provider, equals('openrouter'));
    });

    test('adds VSEGPT key and updates provider', () async {
      manager = AuthManager(validator: makeValidator('vsegpt'));
      final res = await manager.addApiKey('sk-or-vv-test-456');
      expect(res.success, isTrue);

      final provider = await manager.getStoredProvider();
      expect(provider, equals('vsegpt'));
    });
  });
}

class _FakeValidator extends AuthValidator {
  final String provider;
  _FakeValidator(this.provider);

  @override
  Future<ApiKeyValidationResult> validateApiKey(String apiKey) async {
    return ApiKeyValidationResult(
      isValid: true,
      message: '100.00',
      balance: 100.0,
      provider: provider,
    );
  }
}
