# Руководство для разработчиков

## Начало работы

### Требования

- **Flutter SDK**: 3.0.0 или выше
- **Dart SDK**: 3.0.0 или выше (включается с Flutter)
- **Git**: для работы с версионированием
- **IDE**: VS Code или Android Studio с плагинами Flutter/Dart

### Установка окружения

1. **Установите Flutter SDK**: https://docs.flutter.dev/get-started/install
2. **Проверьте установку**:
   ```bash
   flutter doctor
   ```
3. **Клонируйте проект**:
   ```bash
   git clone <repository-url>
   cd ai_chat_flutter
   ```
4. **Установите зависимости**:
   ```bash
   flutter pub get
   ```

### Настройка переменных окружения

Создайте файл `.env` в корне проекта:

```env
OPENROUTER_API_KEY=ваш_api_ключ
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
VSEGPT_BASE_URL=https://api.vsegpt.ru/v1
MAX_TOKENS=1000
TEMPERATURE=0.7
DEBUG_LOG_HTTP=false
```

**Важно:** Файл `.env` не должен попадать в git (он уже в `.gitignore`).

### Первичный вход в приложение

1. Запустите приложение.
2. Введите API ключ:
   - **OpenRouter**: ключ начинается с `sk-or-v1-...`
   - **VSEGPT**: ключ начинается с `sk-or-vv-...`
3. Придумайте и введите PIN (4 цифры): допускается `0000` или любое число от `1000` до `9999`.
4. Сохраните PIN в безопасном месте — он понадобится для быстрого входа офлайн.

## Структура проекта

```
lib/
├── api/                        # API клиенты
│   ├── api.dart               # Базовый API клиент
│   └── openrouter_client.dart # OpenRouter API клиент
│
├── auth/                       # Аутентификация
│   ├── auth.dart              # Публичный API
│   ├── auth_manager.dart      # Менеджер аутентификации
│   ├── auth_repository.dart   # Репозиторий для работы с БД
│   ├── auth_storage.dart      # Хранилище аутентификации
│   └── auth_validator.dart    # Валидатор API ключей
│
├── config/                     # Конфигурация
│   ├── config.dart            # Конфигурация приложения
│   └── env.dart               # Загрузка переменных окружения
│
├── models/                     # Модели данных
│   ├── analytics_record.dart  # Модель аналитики
│   ├── chat_message.dart      # Модель сообщения
│   ├── model_info.dart        # Информация о моделях
│   └── models.dart            # Экспорт всех моделей
│
├── navigation/                 # Навигация
│   ├── app_router.dart        # Роутер приложения
│   └── navigation.dart        # Экспорт навигации
│
├── screens/                    # Экраны приложения
│   ├── analytics_dialog.dart  # Диалог аналитики
│   ├── chat_screen.dart       # Экран чата
│   ├── expenses_screen.dart   # Экран расходов
│   ├── home_screen.dart       # Главный экран
│   ├── settings_screen.dart   # Экран настроек
│   ├── statistics_screen.dart # Экран статистики
│   └── screens.dart           # Экспорт экранов
│
├── ui/                         # UI компоненты
│   ├── components/            # Переиспользуемые компоненты
│   │   ├── animated_button.dart
│   │   ├── animated_loading_indicator.dart
│   │   ├── components.dart
│   │   ├── message_bubble.dart
│   │   └── model_selector.dart
│   ├── login/                 # Экран входа
│   │   └── login_screen.dart
│   ├── transitions/           # Анимации переходов
│   │   └── page_transitions.dart
│   ├── styles.dart            # Стили и адаптивные методы
│   ├── theme.dart             # Тема приложения
│   └── ui.dart                # Экспорт UI
│
├── utils/                      # Утилиты
│   ├── analytics.dart         # Аналитика
│   ├── cache.dart             # Кэш сообщений
│   ├── constants.dart         # Константы
│   ├── database/              # Работа с БД
│   │   └── database.dart
│   ├── expenses_calculator.dart # Калькулятор расходов
│   ├── logger.dart            # Логирование
│   ├── monitor.dart           # Мониторинг производительности
│   ├── platform.dart          # Определение платформы
│   ├── preferences_service.dart # Сервис настроек
│   └── utils.dart             # Экспорт утилит
│
├── app.dart                    # Основной класс приложения
└── main.dart                   # Точка входа
```

## Основные команды разработки

### Запуск приложения

```bash
# Запуск на Windows
flutter run -d windows

# Запуск на Android
flutter run -d android

# Запуск на iOS (только macOS)
flutter run -d ios

# Запуск на Linux
flutter run -d linux

# Запуск на macOS
flutter run -d macos
```

### Анализ кода

```bash
# Статический анализ кода
flutter analyze

# Форматирование кода
flutter format .

# Проверка форматирования
flutter format --dry-run .
```

### Сборка десктопного приложения (release)

#### Требования

- Flutter SDK установлен и доступен в PATH
- Для **Windows**: Visual Studio 2022 + “Desktop development with C++”
- Для **Linux**: CMake, pkg-config, GTK dev packages
- Для **macOS**: Xcode + CocoaPods

#### Сборка

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

#### Где искать сборки

- **Windows**: `build/windows/x64/runner/Release/`
- **Linux**: `build/linux/x64/release/bundle/`
- **macOS**: `build/macos/Build/Products/Release/`

---

### Сборка мобильного приложения (release)

## Android

#### Требования

- Android SDK (API 21+), установлены platform-tools и build-tools
- JDK 11+ (рекомендуется 17, если окружение Flutter настроено под него)

#### Подпись (release)

1. **Сгенерируйте keystore** (один раз):

```bash
keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. **Создайте `android/key.properties`** (не коммитить):

```properties
storePassword=<ваш_пароль>
keyPassword=<ваш_пароль>
keyAlias=upload
storeFile=key.jks
```

3. **Проверьте `android/app/build.gradle.kts`** — `signingConfig`/`buildTypes` должны читать `key.properties` (или используйте свою схему подписи).

#### Сборка

- APK: `flutter build apk --release`
- AAB (Google Play): `flutter build appbundle --release`

#### Где искать сборки

- APK: `build/app/outputs/flutter-apk/app-release.apk`  
  (оригинал: `android/app/build/outputs/flutter-apk/app-release.apk`)
- AAB: `build/app/outputs/bundle/release/app-release.aab`  
  (оригинал: `android/app/build/outputs/bundle/release/app-release.aab`)

## iOS (только macOS)

#### Требования

- macOS, Xcode, CocoaPods

#### Сборка

- IPA (через Xcode архив): `flutter build ipa --release`
- Или сборка для запуска на устройстве: `flutter build ios --release`

### Очистка проекта

```bash
# Очистка build артефактов
flutter clean

# Переустановка зависимостей
flutter pub get

# Полная очистка (включая .dart_tool)
flutter clean && flutter pub get
```

## Тестирование

### Запуск тестов

```bash
# Запустить все тесты
flutter test

# Запустить тесты с покрытием
flutter test --coverage

# Запустить конкретный тест
flutter test test/auth/auth_manager_test.dart

# Запустить тесты с подробным выводом
flutter test --reporter expanded

# Запустить тесты в watch режиме
flutter test --watch
```

### Запуск тестов по категориям

**Важно:** Из-за использования общей БД (DatabaseHelper.instance), тесты лучше запускать отдельно:

```bash
# Тесты API
flutter test test/api/

# Тесты аутентификации (по отдельности)
flutter test test/auth/auth_repository_test.dart
flutter test test/auth/auth_storage_test.dart
flutter test test/auth/auth_manager_test.dart

# Тесты UI
flutter test test/ui/

# Тесты утилит
flutter test test/utils/
```

### Просмотр покрытия кода

```bash
# Генерировать отчет о покрытии
flutter test --coverage

# Просмотр отчета (требуется lcov)
# Windows: choco install lcov
# macOS: brew install lcov
# Linux: sudo apt-get install lcov
genhtml coverage/lcov.info -o coverage/html
```

## Стандарты кодирования

### Форматирование

Проект использует стандартное форматирование Dart. Перед коммитом:

```bash
flutter format .
```

### Стиль кода

- Используйте `flutter_lints` для проверки стиля
- Следуйте [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Используйте meaningful имена переменных и функций
- Комментируйте сложную логику

### Структура файлов

- Один публичный класс/функция на файл
- Используйте barrel exports (`*.dart` файлы, которые экспортируют другие)
- Группируйте связанные функции в папки

## Архитектура

### Паттерны

- **Repository Pattern**: для работы с данными (`auth_repository.dart`)
- **Manager Pattern**: для бизнес-логики (`auth_manager.dart`)
- **Service Pattern**: для сервисов (`preferences_service.dart`)

### Состояние

- Используется `StatefulWidget` для локального состояния
- Используется `Provider` или `InheritedWidget` для глобального состояния (если нужно)

### База данных

- Используется SQLite через `sqflite`
- База данных находится в `chat_cache.db`
- Схема БД управляется через миграции в `utils/database/database.dart`

## Зависимости

### Основные

- **http**: HTTP запросы к API
- **sqflite**: База данных SQLite
- **sqflite_common_ffi**: SQLite для desktop платформ
- **flutter_dotenv**: Переменные окружения
- **logger**: Логирование
- **shared_preferences**: Хранилище настроек
- **flutter_secure_storage**: Безопасное хранилище
- **path_provider**: Пути к директориям
- **intl**: Форматирование дат
- **crypto**: Криптография
- **fl_chart**: Графики и визуализация

### Добавление зависимостей

```bash
# Добавить зависимость
flutter pub add <package_name>

# Добавить dev зависимость
flutter pub add --dev <package_name>

# Обновить зависимости
flutter pub upgrade

# Проверить устаревшие зависимости
flutter pub outdated
```

## Платформы

### Windows

- Требуется Visual Studio 2022 с "Desktop development with C++"
- См. раздел [Сборка приложения](#сборка-приложения) выше

### Android

- Требуется Android Studio
- Android SDK (API 21+)
- JDK 11+
- См. раздел [Сборка приложения](#сборка-приложения) выше

### iOS (только macOS)

- Требуется macOS 10.14+
- Xcode 12+
- CocoaPods
- См. раздел [Сборка приложения](#сборка-приложения) выше

### Linux

- Требуется CMake и pkg-config
- GTK development libraries
- См. раздел [Сборка приложения](#сборка-приложения) выше

### macOS

- Требуется Xcode 12+
- CocoaPods
- См. раздел [Сборка приложения](#сборка-приложения) выше

## Отладка

### Логирование

Приложение использует `logger` пакет для логирования. Логи можно найти в:

- Консоль приложения (debug режим)
- Файлы логов (если настроено)

#### HTTP debug logging

Для отладки сетевых запросов можно включить подробные логи HTTP через переменные окружения:

```env
DEBUG=true
LOG_LEVEL=DEBUG
DEBUG_LOG_HTTP=true
```

В production/release детальные логи должны быть выключены.

### DevTools

```bash
# Запуск DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### Hot Reload / Hot Restart

- **Hot Reload** (Ctrl+Shift+F5): Быстрая перезагрузка изменений
- **Hot Restart** (Ctrl+Shift+F6): Полная перезагрузка приложения

## Git Workflow

### Создание коммитов

Используйте conventional commits:

```
<тип>: <краткое описание>

<подробное описание (опционально)>
```

Типы:
- `feat`: Новая функциональность
- `fix`: Исправление ошибки
- `docs`: Изменение документации
- `style`: Форматирование кода
- `refactor`: Рефакторинг
- `test`: Добавление тестов
- `chore`: Изменения в процессе сборки

### Перед коммитом

```bash
# Проверить форматирование
flutter format --dry-run .

# Запустить анализ
flutter analyze

# Запустить тесты
flutter test
```

## Полезные ссылки

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Flutter API Reference](https://api.flutter.dev/)

## Получение помощи

- Проверьте логи приложения
- Запустите `flutter doctor` для диагностики окружения
- См. раздел [Начало работы](#начало-работы) выше для вопросов по установке
