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
```bash
flutter create --platforms=windows .
flutter build windows --release
```
Результат: `build\windows\x64\runner\Release\ai_chat.exe`

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

- **Windows**: Проверьте Visual Studio и Windows SDK через `flutter doctor`
- **Linux**: Установите все зависимости, проверьте CMake версию (3.10+)
- **macOS**: Примите лицензию Xcode, обновите CocoaPods
- **База данных**: Убедитесь, что `sqflite_common_ffi` установлен и инициализирован в `main.dart`

## Дополнительные ресурсы

- [Flutter Desktop Documentation](https://docs.flutter.dev/development/platform-integration/desktop)
