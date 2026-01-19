import 'dart:io' show Directory, File, FileMode, IOSink;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'platform.dart';

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
/// - Консольный вывод для мониторинга в реальном времени
/// - Несколько уровней логирования (debug, info, warning, error)
/// - Форматированные сообщения с временными метками
/// - Ротация логов по датам
///
/// Пример использования:
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

  /// Инициализирует систему логирования.
  Future<void> _initializeLogger() async {
    try {
      // Определяем директорию для логов
      _logsDirectory = await _getLogsDirectory();
      
      // Создаем директорию, если не существует
      if (_logsDirectory != null && await _ensureLogsDirectory()) {
        // Создаем файл лога с текущей датой: chat_app_YYYY-MM-DD.log
        final currentDate = _dateFormat.format(DateTime.now());
        _currentLogFile = File('${_logsDirectory!.path}/chat_app_$currentDate.log');
        
        // Открываем файл для записи
        _fileSink = _currentLogFile!.openWrite(mode: FileMode.append);
        _fileLoggingEnabled = true;
      }
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
    _logger.level = _convertLogLevel(level);
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
    // Вывод в консоль (всегда)
    for (final line in event.lines) {
      print(line);
    }

    // Вывод в файл (если включен)
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
