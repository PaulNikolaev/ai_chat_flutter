# Инструкция по установке

## Системные требования

- **Flutter SDK** 3.0.0+
- **Git**
- Минимум 2 ГБ свободного места

### Дополнительно для разработки:
- **Windows**: Visual Studio 2022 с "Desktop development with C++"
- **Linux**: Clang, CMake, GTK+ libraries
- **macOS**: Xcode 12+
- **Android**: Android Studio, Android SDK, JDK 11+
- **iOS** (только macOS): Xcode, CocoaPods

## Установка Flutter SDK

### Windows/Linux/macOS

1. Скачайте Flutter: https://docs.flutter.dev/get-started/install
2. Распакуйте и добавьте в PATH:
   - **Windows**: `<flutter_dir>\flutter\bin` в системный PATH
   - **Linux/macOS**: `export PATH="$PATH:$HOME/development/flutter/bin"` в `~/.bashrc` или `~/.zshrc`
3. Проверьте:
   ```bash
   flutter --version
   flutter doctor
   ```

## Установка проекта

1. **Клонируйте репозиторий**:
   ```bash
   git clone <repository-url>
   cd AI_chat_flutter
   ```

2. **Установите зависимости**:
   ```bash
   flutter pub get
   ```

3. **Создайте `.env` файл**:
   ```env
   OPENROUTER_API_KEY=ваш_api_ключ
   OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
   MAX_TOKENS=1000
   TEMPERATURE=0.7
   ```

4. **Запустите приложение**:
   ```bash
   flutter run -d windows  # или android, ios, linux, macos
   ```

## Решение проблем

- **Flutter не найден**: Добавьте в PATH и перезапустите терминал
- **Ошибки зависимостей**: `flutter pub cache repair`
- **Android SDK**: Установите Android Studio, настройте `ANDROID_HOME` и `JAVA_HOME`
- **.env не загружается**: Проверьте, что файл в корне проекта и добавлен в `pubspec.yaml` assets
- **База данных на Windows**: Убедитесь, что `sqflite_common_ffi` установлен

## Дополнительные ресурсы

- [Flutter Documentation](https://docs.flutter.dev/)
- [DESKTOP_BUILD.md](DESKTOP_BUILD.md)
- [MOBILE_BUILD.md](MOBILE_BUILD.md)
