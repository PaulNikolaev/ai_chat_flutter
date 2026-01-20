# Сборка десктопного приложения

## Системные требования

- **Windows**: Visual Studio 2022 с "Desktop development with C++"
- **Linux**: Clang, CMake, GTK+ libraries
- **macOS**: Xcode 12+, CocoaPods

## Подготовка

```bash
flutter doctor              # Проверка окружения
cd AI_chat_flutter
flutter pub get            # Установка зависимостей
```

## Сборка

### Windows

#### Первоначальная настройка

Если проект еще не настроен для Windows:

```bash
# Создание/обновление Windows конфигурации
flutter create --platforms=windows .

# Очистка кэша перед сборкой (рекомендуется при проблемах)
flutter clean
```

#### Сборка Release

```bash
flutter build windows --release
```
Результат: `build\windows\x64\runner\Release\ai_chat.exe`

**Примечание:** Исполняемый файл можно запускать напрямую. Для распространения может потребоваться упаковка в установщик (WiX Toolset, Inno Setup и т.д.).

### Linux
```bash
# Установка зависимостей (Ubuntu/Debian)
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

flutter create --platforms=linux .
flutter build linux --release
```
Результат: `build/linux/x64/release/bundle/ai_chat`

### macOS
```bash
sudo gem install cocoapods
flutter create --platforms=macos .
cd macos && pod install && cd ..
flutter build macos --release
```
Результат: `build/macos/Build/Products/Release/ai_chat.app`

## Оптимизация

- Используйте режим Release: `flutter build windows --release`
- Проверьте tree-shaking (автоматически включен)
- Оптимизируйте ресурсы (изображения, шрифты)

## Решение проблем

### Windows

- **Visual Studio не найден**: Установите Visual Studio 2022 с компонентом "Desktop development with C++"
- **Windows SDK**: Проверьте установку через `flutter doctor -v`
- **Ошибки сборки**: 
  ```bash
  flutter clean
  flutter build windows --release
  ```
- **Проблемы с зависимостями**: Убедитесь, что все зависимости установлены через `flutter pub get`

### Linux

- **Зависимости**: Установите все зависимости, проверьте CMake версию (3.10+)
- **Права доступа**: Убедитесь, что у вас есть права на запись в директорию сборки

### macOS

- **Xcode**: Примите лицензию Xcode, обновите CocoaPods
- **CocoaPods**: Обновите через `sudo gem install cocoapods`

### Общие проблемы

- **База данных**: Убедитесь, что `sqflite_common_ffi` установлен и инициализирован в `main.dart`
- **Переменные окружения**: Проверьте, что `.env` файл создан на основе `.env.example` (для работы с API)

## Дополнительные ресурсы

- [Flutter Desktop Documentation](https://docs.flutter.dev/development/platform-integration/desktop)
