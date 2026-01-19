# AI Chat - Flutter приложение

Чат-приложение на Flutter, использующее API OpenRouter для взаимодействия с различными моделями искусственного интеллекта.

## Поддержка платформ

- **Desktop**: Windows, Linux, macOS
- **Mobile**: Android, iOS

Подробные инструкции: [INSTALL.md](INSTALL.md), [DESKTOP_BUILD.md](DESKTOP_BUILD.md), [MOBILE_BUILD.md](MOBILE_BUILD.md)

## Быстрый старт

### Требования
- Flutter SDK 3.0.0+
- Git

### Установка

1. **Установите Flutter SDK**: https://docs.flutter.dev/get-started/install
2. **Клонируйте проект**:
   ```bash
   git clone <repository-url>
   cd AI_chat_flutter
   ```
3. **Установите зависимости**:
   ```bash
   flutter pub get
   ```
4. **Создайте файл `.env`**:
   ```env
   OPENROUTER_API_KEY=ваш_api_ключ
   OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
   MAX_TOKENS=1000
   TEMPERATURE=0.7
   ```
5. **Запустите приложение**:
   ```bash
   flutter run -d windows  # или android, ios, linux, macos
   ```

## Основные зависимости

- **http** - HTTP запросы к API
- **sqflite** / **sqflite_common_ffi** - База данных SQLite
- **flutter_dotenv** - Переменные окружения
- **logger** - Логирование
- **shared_preferences** / **flutter_secure_storage** - Хранилище данных
- **path_provider** - Пути к директориям
- **intl** - Форматирование дат
- **crypto** - Криптография

## Основные возможности

- Чат с более чем 339 моделями через OpenRouter API
- Сохранение истории в SQLite
- Экспорт диалогов в JSON
- Аналитика использования моделей
- Безопасное хранение API ключей
- Адаптивный дизайн для всех платформ

## Структура проекта

```
lib/
├── api/              # OpenRouter API клиент
├── auth/             # Аутентификация
├── config/           # Конфигурация
├── models/           # Модели данных
├── screens/          # Экраны приложения
├── ui/               # UI компоненты
├── utils/            # Утилиты (аналитика, кэш, БД, логирование)
├── app.dart          # Основной класс
└── main.dart         # Точка входа
```

## Разработка

```bash
flutter run           # Запуск
flutter test          # Тесты
flutter analyze       # Анализ кода
flutter build windows --release  # Сборка
```

## Поддержка

При проблемах:
1. `flutter pub get` - установка зависимостей
2. `flutter doctor` - проверка окружения
3. Проверьте логи в `logs/`
