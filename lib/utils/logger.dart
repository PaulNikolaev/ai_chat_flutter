import 'dart:io' show Directory, File, FileMode, IOSink;
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'platform.dart';
import 'package:ai_chat/config/config.dart';

/// Уровни логирования приложения.
enum LogLevel {
  /// Детальная отладочная информация.
  debug,

  /// Информационные сообщения о работе приложения.
  info,

  /// Предупреждения о потенциальных проблемах.
  warning,

  /// Ошибки и критические проблемы.
  error,
}

/// Система логирования приложения с записью в файлы и консоль.
///
/// Предоставляет централизованную функциональность логирования:
/// - Ежедневные лог-файлы с датой в названии
/// - Консольный вывод для мониторинга в реальном времени (только в debug режиме)
/// - Несколько уровней логирования (debug, info, warning, error)
/// - Форматированные сообщения с временными метками
/// - Ротация логов по датам
/// - Автоматическая очистка старых логов (старше 30 дней)
/// - Контроль размера лог-файлов (максимум 10 MB на файл)
/// - Настройка уровня логирования через EnvConfig.LOG_LEVEL
///
/// **Безопасность логирования:**
/// - debugPrint автоматически отключается в release builds
/// - Чувствительные данные (API ключи, пароли) НЕ должны логироваться
/// - Authorization заголовки НЕ логируются (проверено в OpenRouterClient)
///
/// **Ротация логов:**
/// - Новый файл создается каждый день: chat_app_YYYY-MM-DD.log
/// - Старые файлы (старше 30 дней) автоматически удаляются
/// - При превышении размера 10 MB создается новый файл с суффиксом
///
/// **Пример использования:**
/// ```dart
/// final logger = await AppLogger.create();
/// logger.info('Приложение запущено');
/// logger.error('Ошибка подключения', error: e);
/// ```
class AppLogger {
  /// Экземпляр logger для форматирования и вывода.
  late final Logger _logger;

  /// Директория для хранения лог-файлов.
  Directory? _logsDirectory;

  /// Текущий файл лога.
  File? _currentLogFile;

  /// Поток для записи в файл.
  IOSink? _fileSink;

  /// Флаг, указывающий, включена ли запись в файл.
  bool _fileLoggingEnabled = false;

  /// Текущий уровень логирования.
  LogLevel _currentLevel = LogLevel.debug;

  /// Формат даты для имен файлов: YYYY-MM-DD.
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Формат времени для логов: YYYY-MM-DD HH:MM:SS.
  static final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Создает экземпляр AppLogger.
  ///
  /// Для полной инициализации используйте [AppLogger.create()].
  AppLogger._();

  /// Создает и инициализирует экземпляр AppLogger.
  ///
  /// Настраивает директорию логов с учетом платформы, файловый обработчик
  /// с датой в названии, консольный обработчик и форматирование сообщений.
  /// Включает механизмы отката для мобильных платформ и проблем с доступом
  /// к файловой системе.
  ///
  /// На Android логи сохраняются во внутренней директории приложения.
  /// На десктопе логи сохраняются в директории 'logs' относительно приложения.
  ///
  /// Пример использования:
  /// ```dart
  /// final logger = await AppLogger.create();
  /// logger.info('Приложение запущено');
  /// ```
  static Future<AppLogger> create() async {
    final instance = AppLogger._();
    await instance._initializeLogger();
    return instance;
  }

  /// Максимальный возраст лог-файлов в днях (30 дней).
  ///
  /// Файлы старше этого периода будут автоматически удаляться при инициализации.
  static const int maxLogAgeDays = 30;

  /// Максимальный размер лог-файла в байтах (10 MB).
  ///
  /// Если файл превышает этот размер, создается новый файл с суффиксом номера.
  static const int maxLogFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  /// Инициализирует систему логирования.
  ///
  /// Выполняет очистку старых лог-файлов, проверяет размер текущего файла
  /// и настраивает уровень логирования из конфигурации окружения.
  Future<void> _initializeLogger() async {
    try {
      // Определяем директорию для логов
      _logsDirectory = await _getLogsDirectory();

      // Создаем директорию, если не существует
      if (_logsDirectory != null && await _ensureLogsDirectory()) {
        // Очищаем старые лог-файлы перед созданием нового
        await _cleanOldLogs();

        // Создаем файл лога с текущей датой: chat_app_YYYY-MM-DD.log
        final currentDate = _dateFormat.format(DateTime.now());
        _currentLogFile =
            File('${_logsDirectory!.path}/chat_app_$currentDate.log');

        // Проверяем размер файла и создаем новый, если превышен лимит
        await _ensureLogFileSize();

        // Открываем файл для записи
        _fileSink = _currentLogFile!.openWrite(mode: FileMode.append);
        _fileLoggingEnabled = true;
      }

      // Устанавливаем уровень логирования из конфигурации окружения
      _initializeLogLevel();
    } catch (e) {
      // Fallback: продолжаем только с консольным логированием
      _fileLoggingEnabled = false;
    }

    // Настраиваем logger с кастомным output
    _logger = Logger(
      level: _convertLogLevel(_currentLevel),
      output: _CustomLogOutput(
        fileSink: _fileSink,
        fileLoggingEnabled: _fileLoggingEnabled,
      ),
      printer: _CustomLogPrinter(),
    );
  }

  /// Инициализирует уровень логирования из конфигурации окружения.
  ///
  /// Читает значение LOG_LEVEL из EnvConfig и устанавливает соответствующий уровень.
  /// Если конфигурация не загружена или значение не задано, используется значение по умолчанию:
  /// - INFO для production режима
  /// - DEBUG для development режима
  void _initializeLogLevel() {
    try {
      // Пытаемся получить уровень логирования из конфигурации
      if (EnvConfig.isLoaded) {
        final levelStr = EnvConfig.logLevel.toUpperCase();
        switch (levelStr) {
          case 'DEBUG':
            _currentLevel = LogLevel.debug;
            break;
          case 'INFO':
            _currentLevel = LogLevel.info;
            break;
          case 'WARNING':
          case 'WARN':
            _currentLevel = LogLevel.warning;
            break;
          case 'ERROR':
            _currentLevel = LogLevel.error;
            break;
          default:
            // Если уровень неизвестен, используем значение по умолчанию
            _currentLevel = EnvConfig.isProduction
                ? LogLevel.info
                : LogLevel.debug;
        }
      } else {
        // Если конфигурация не загружена, используем значение по умолчанию
        _currentLevel = LogLevel.info;
      }
    } catch (_) {
      // Если не удалось загрузить конфигурацию, используем значение по умолчанию
      _currentLevel = LogLevel.info;
    }
  }

  /// Очищает старые лог-файлы.
  ///
  /// Удаляет файлы старше [maxLogAgeDays] дней для предотвращения переполнения диска.
  /// Выполняется автоматически при инициализации logger.
  Future<void> _cleanOldLogs() async {
    if (_logsDirectory == null) return;

    try {
      final now = DateTime.now();
      final files = _logsDirectory!.listSync();

      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          try {
            final stat = await file.stat();
            final age = now.difference(stat.modified);
            if (age.inDays > maxLogAgeDays) {
              await file.delete();
            }
          } catch (_) {
            // Игнорируем ошибки при удалении отдельных файлов
          }
        }
      }
    } catch (_) {
      // Игнорируем ошибки очистки старых логов
    }
  }

  /// Проверяет размер текущего лог-файла и создает новый, если превышен лимит.
  ///
  /// Если файл превышает [maxLogFileSizeBytes], создается новый файл с суффиксом.
  Future<void> _ensureLogFileSize() async {
    if (_currentLogFile == null) return;

    try {
      if (await _currentLogFile!.exists()) {
        final stat = await _currentLogFile!.stat();
        if (stat.size > maxLogFileSizeBytes) {
          // Создаем новый файл с номером
          int counter = 1;
          File? newFile;
          do {
            final baseName = _currentLogFile!.path.replaceAll('.log', '');
            newFile = File('${baseName}_$counter.log');
            counter++;
          } while (await newFile.exists());

          _currentLogFile = newFile;
        }
      }
    } catch (_) {
      // Игнорируем ошибки проверки размера файла
    }
  }

  /// Получает путь к директории логов в зависимости от платформы.
  ///
  /// На мобильных платформах (Android/iOS) использует внутреннее хранилище приложения.
  /// На десктопных платформах использует директорию 'logs' относительно приложения.
  ///
  /// Возвращает [Directory] для логов или null, если не удалось определить путь.
  Future<Directory?> _getLogsDirectory() async {
    try {
      if (PlatformUtils.isMobile()) {
        // На мобильных платформах используем директорию приложения
        final appDir = await getApplicationDocumentsDirectory();
        return Directory('${appDir.path}/logs');
      } else {
        // На десктопе используем директорию 'logs' относительно приложения
        final appDir = await getApplicationSupportDirectory();
        return Directory('${appDir.path}/logs');
      }
    } catch (e) {
      // Fallback: используем текущую директорию
      try {
        return Directory('logs');
      } catch (_) {
        return null;
      }
    }
  }

  /// Убеждается, что директория логов существует и доступна для записи.
  ///
  /// Создает директорию, если она не существует, и проверяет права на запись.
  /// Обрабатывает потенциальные проблемы с доступом к файловой системе.
  ///
  /// Возвращает true, если директория доступна и доступна для записи, иначе false.
  Future<bool> _ensureLogsDirectory() async {
    if (_logsDirectory == null) return false;

    try {
      // Проверяем, существует ли директория
      if (!await _logsDirectory!.exists()) {
        // Создаем директорию с родительскими директориями при необходимости
        await _logsDirectory!.create(recursive: true);
      }

      // Проверяем, доступна ли директория для записи, создавая тестовый файл
      final testFile = File('${_logsDirectory!.path}/.test_write');
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Конвертирует [LogLevel] в [Level] пакета logger.
  Level _convertLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Level.debug;
      case LogLevel.info:
        return Level.info;
      case LogLevel.warning:
        return Level.warning;
      case LogLevel.error:
        return Level.error;
    }
  }

  /// Устанавливает уровень логирования.
  ///
  /// Сообщения с уровнем ниже установленного не будут логироваться.
  ///
  /// Пример:
  /// ```dart
  /// logger.setLevel(LogLevel.info); // Только info, warning, error
  /// ```
  void setLevel(LogLevel level) {
    _currentLevel = level;
    _logger = Logger(
      level: _convertLogLevel(level),
      output: _CustomLogOutput(
        fileSink: _fileSink,
        fileLoggingEnabled: _fileLoggingEnabled,
      ),
      printer: _CustomLogPrinter(),
    );
  }

  /// Логирует информационное сообщение.
  ///
  /// Используется для записи важной информации о работе приложения:
  /// успешные операции, статус выполнения, информация о состоянии.
  ///
  /// Пример:
  /// ```dart
  /// logger.info('Пользователь успешно авторизован');
  /// ```
  void info(String message) {
    _logger.i(message);
  }

  /// Логирует сообщение об ошибке.
  ///
  /// Используется для записи информации об ошибках: исключения, сбои,
  /// критические ошибки. Может включать информацию об исключении.
  ///
  /// Пример:
  /// ```dart
  /// logger.error('Ошибка подключения к API', error: e, stackTrace: stack);
  /// ```
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (error != null || stackTrace != null) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.e(message);
    }
  }

  /// Логирует отладочное сообщение.
  ///
  /// Используется для записи детальной отладочной информации:
  /// значения переменных, промежуточные результаты, детали выполнения.
  ///
  /// Пример:
  /// ```dart
  /// logger.debug('Текущее состояние: $state');
  /// ```
  void debug(String message) {
    _logger.d(message);
  }

  /// Логирует предупреждение.
  ///
  /// Используется для записи предупреждений: потенциальные проблемы,
  /// нежелательные ситуации, предупреждения о состоянии.
  ///
  /// Пример:
  /// ```dart
  /// logger.warning('Низкий баланс API ключа');
  /// ```
  void warning(String message) {
    _logger.w(message);
  }

  /// Закрывает файловый поток и освобождает ресурсы.
  ///
  /// Должен вызываться при завершении работы приложения для корректного
  /// закрытия файловых потоков.
  Future<void> dispose() async {
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
  }
}

/// Кастомный output для записи логов в файл и консоль.
class _CustomLogOutput extends LogOutput {
  final IOSink? fileSink;
  final bool fileLoggingEnabled;

  _CustomLogOutput({
    required this.fileSink,
    required this.fileLoggingEnabled,
  });

  @override
  void output(OutputEvent event) {
    // Вывод в консоль (только в debug режиме, не в release)
    // debugPrint автоматически отключается в release builds
    if (!kReleaseMode) {
      for (final line in event.lines) {
        debugPrint(line);
      }
    }

    // Вывод в файл (если включен)
    // В production также ведется файловое логирование для анализа проблем
    if (fileLoggingEnabled && fileSink != null) {
      for (final line in event.lines) {
        fileSink!.writeln(line);
      }
    }
  }
}

/// Кастомный принтер для форматирования логов.
///
/// Формат: YYYY-MM-DD HH:MM:SS - LEVEL - Message
class _CustomLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final time = AppLogger._timeFormat.format(DateTime.now());
    final level = _getLevelString(event.level);
    final message = event.message;

    String logLine = '$time - $level - $message';

    // Добавляем информацию об ошибке, если есть
    if (event.error != null) {
      logLine += '\nError: ${event.error}';
    }

    // Добавляем stack trace, если есть
    if (event.stackTrace != null) {
      logLine += '\n${event.stackTrace}';
    }

    return [logLine];
  }

  String _getLevelString(Level level) {
    switch (level) {
      case Level.debug:
        return 'DEBUG';
      case Level.info:
        return 'INFO';
      case Level.warning:
        return 'WARNING';
      case Level.error:
        return 'ERROR';
      default:
        return level.name.toUpperCase();
    }
  }
}
