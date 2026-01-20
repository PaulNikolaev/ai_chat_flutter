import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

/// Версия базы данных для управления миграциями.
const int _databaseVersion = 4;

/// Имя файла базы данных.
const String _databaseName = 'chat_cache.db';

/// Класс для управления схемой базы данных SQLite.
///
/// Предоставляет методы для создания таблиц и управления миграциями базы данных.
/// Использует sqflite для работы с SQLite на всех платформах.
class DatabaseHelper {
  /// Единственный экземпляр DatabaseHelper (Singleton).
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Внутренний конструктор для Singleton.
  DatabaseHelper._internal();

  /// Экземпляр базы данных.
  static Database? _database;

  /// Получает экземпляр базы данных, создавая его при необходимости.
  ///
  /// Возвращает открытую базу данных SQLite.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Инициализирует базу данных.
  ///
  /// Создает файл базы данных, если его нет, и выполняет миграции.
  Future<Database> _initDatabase() async {
    String path;

    // Для десктопных платформ используем getDatabasesPath из sqflite_common_ffi
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _databaseName);
    } else {
      // Для мобильных платформ используем стандартный путь
      path = join(await getDatabasesPath(), _databaseName);
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Создает все таблицы при первом создании базы данных.
  ///
  /// Выполняется только при создании новой базы данных.
  Future<void> _onCreate(Database db, int version) async {
    await _createMessagesTable(db);
    await _createAnalyticsTable(db);
    await _createAuthTable(db);
  }

  /// Выполняет миграции при обновлении версии базы данных.
  ///
  /// Все миграции выполняются в одной транзакции для обеспечения атомарности
  /// и отката при ошибке.
  ///
  /// [oldVersion] - предыдущая версия БД.
  /// [newVersion] - новая версия БД.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Выполняем все миграции в транзакции для атомарности
    await db.transaction((txn) async {
      // Миграция с версии 1 на версию 2: добавление поля provider в таблицу auth
      if (oldVersion < 2) {
        // Проверяем, существует ли колонка provider
        final tableInfo = await txn.rawQuery('PRAGMA table_info(auth)');
        final hasProviderColumn =
            tableInfo.any((column) => column['name'] == 'provider');

        if (!hasProviderColumn) {
          // Добавляем колонку provider с значением по умолчанию 'openrouter'
          await txn.execute('''
            ALTER TABLE auth ADD COLUMN provider TEXT NOT NULL DEFAULT 'openrouter'
          ''');
        }
      }

      // Миграция с версии 2 на версию 3: добавление полей для токенов и стоимости
      if (oldVersion < 3) {
        final tableInfo =
            await txn.rawQuery('PRAGMA table_info(analytics_messages)');
        final columnNames =
            tableInfo.map((column) => column['name'] as String).toList();

        // Добавляем prompt_tokens если его нет
        if (!columnNames.contains('prompt_tokens')) {
          await txn.execute('''
            ALTER TABLE analytics_messages ADD COLUMN prompt_tokens INTEGER
          ''');
        }

        // Добавляем completion_tokens если его нет
        if (!columnNames.contains('completion_tokens')) {
          await txn.execute('''
            ALTER TABLE analytics_messages ADD COLUMN completion_tokens INTEGER
          ''');
        }

        // Добавляем cost если его нет
        if (!columnNames.contains('cost')) {
          await txn.execute('''
            ALTER TABLE analytics_messages ADD COLUMN cost REAL
          ''');
        }
      }

      // Миграция с версии 3 на версию 4: поддержка нескольких API ключей от разных провайдеров
      if (oldVersion < 4) {
        // Создаем новую таблицу auth_keys для хранения нескольких ключей
        await txn.execute('''
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

        // Мигрируем существующие данные из auth в auth_keys
        final existingAuth = await txn.query('auth', limit: 1);
        if (existingAuth.isNotEmpty) {
          final record = existingAuth.first;
          await txn.insert('auth_keys', {
            'api_key': record['api_key'],
            'provider': record['provider'] ?? 'openrouter',
            'pin_hash': record['pin_hash'],
            'created_at':
                record['created_at'] ?? DateTime.now().toIso8601String(),
            'last_used': record['last_used'],
          });
        }

        // Удаляем старую таблицу auth (после миграции данных)
        await txn.execute('DROP TABLE IF EXISTS auth');
      }
    });
  }

  /// Создает таблицу `messages` для хранения сообщений чата.
  ///
  /// Таблица содержит:
  /// - id: уникальный идентификатор (PRIMARY KEY AUTOINCREMENT)
  /// - model: идентификатор модели AI
  /// - user_message: текст сообщения пользователя
  /// - ai_response: текст ответа AI
  /// - timestamp: временная метка сообщения
  /// - tokens_used: количество использованных токенов
  Future<void> _createMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model TEXT NOT NULL,
        user_message TEXT NOT NULL,
        ai_response TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        tokens_used INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Создаем индекс для быстрого поиска по timestamp
    // Используется в ORDER BY timestamp DESC для getChatHistory
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_messages_timestamp 
      ON messages(timestamp DESC)
    ''');

    // Создаем индекс для поиска по модели
    // Используется в фильтрации и статистике по моделям
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_messages_model 
      ON messages(model)
    ''');
  }

  /// Создает таблицу `analytics_messages` для хранения аналитических данных.
  ///
  /// Таблица содержит:
  /// - id: уникальный идентификатор (PRIMARY KEY AUTOINCREMENT)
  /// - timestamp: временная метка записи
  /// - model: идентификатор модели AI
  /// - message_length: длина сообщения в символах
  /// - response_time: время ответа в секундах
  /// - tokens_used: количество использованных токенов
  /// - prompt_tokens: количество токенов в промпте (опционально)
  /// - completion_tokens: количество токенов в завершении (опционально)
  /// - cost: стоимость запроса в долларах (опционально)
  Future<void> _createAnalyticsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS analytics_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        model TEXT NOT NULL,
        message_length INTEGER NOT NULL,
        response_time REAL NOT NULL,
        tokens_used INTEGER NOT NULL DEFAULT 0,
        prompt_tokens INTEGER,
        completion_tokens INTEGER,
        cost REAL
      )
    ''');

    // Создаем индекс для быстрого поиска по timestamp
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_analytics_timestamp 
      ON analytics_messages(timestamp ASC)
    ''');

    // Создаем индекс для группировки по модели
    // Используется в GROUP BY model, фильтрации по модели и статистике
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_analytics_model 
      ON analytics_messages(model)
    ''');

    // Создаем составной индекс для оптимизации частых запросов
    // (model, timestamp) используется в getAnalyticsHistoryFiltered с фильтрами по model и дате
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_analytics_model_timestamp 
      ON analytics_messages(model, timestamp ASC)
    ''');
  }

  /// Создает таблицу `auth_keys` для хранения данных аутентификации.
  ///
  /// Таблица содержит:
  /// - id: уникальный идентификатор (PRIMARY KEY AUTOINCREMENT)
  /// - api_key: API ключ (зашифрован)
  /// - provider: провайдер API ('openrouter' или 'vsegpt')
  /// - pin_hash: хэш PIN кода (общий для всех ключей под одним PIN)
  /// - created_at: дата создания записи
  /// - last_used: дата последнего использования
  /// - UNIQUE(provider): ограничение на уникальность провайдера
  ///
  /// Поддерживает хранение нескольких API ключей от разных провайдеров
  /// под одним PIN кодом.
  Future<void> _createAuthTable(Database db) async {
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

    // Создаем индекс для быстрого поиска по провайдеру
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_auth_keys_provider 
      ON auth_keys(provider)
    ''');

    // Создаем индекс для поиска по pin_hash
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_auth_keys_pin_hash 
      ON auth_keys(pin_hash)
    ''');
  }

  /// Закрывает базу данных и освобождает ресурсы.
  ///
  /// Должен вызываться при завершении работы приложения.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Удаляет базу данных (используется для тестирования или сброса).
  ///
  /// **Внимание:** Удаляет все данные!
  Future<void> deleteDatabase() async {
    String path;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _databaseName);
    } else {
      path = join(await getDatabasesPath(), _databaseName);
    }

    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Получает информацию о версии базы данных.
  Future<int> getVersion() async {
    final db = await database;
    return await db.getVersion();
  }

  /// Выполняет SQL запрос напрямую (для отладки и специальных случаев).
  ///
  /// **Используйте с осторожностью!** Предпочтительно использовать методы
  /// из классов работы с данными.
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }
}
