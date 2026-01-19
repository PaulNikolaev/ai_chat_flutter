# Сборка мобильного приложения

## Системные требования

### Android
- Flutter SDK 3.0.0+
- Android Studio
- Android SDK (API 21+)
- JDK 11+

### iOS (только macOS)
- macOS 10.14+
- Xcode 12+
- CocoaPods

## Установка инструментов

### Flutter SDK
1. Скачайте: https://docs.flutter.dev/get-started/install
2. Добавьте в PATH
3. Проверьте: `flutter doctor`

### Android SDK
1. Установите Android Studio
2. Настройте переменные:
   - `ANDROID_HOME` → путь к Android SDK
   - `JAVA_HOME` → путь к JDK
   - Добавьте в PATH: `%ANDROID_HOME%\platform-tools` и `%JAVA_HOME%\bin`

### iOS (macOS)
```bash
sudo gem install cocoapods
```

## Сборка Android APK

```bash
flutter create --platforms=android .
flutter build apk --release
```
Результат: `build/app/outputs/flutter-apk/app-release.apk`

### Для конкретной архитектуры
```bash
flutter build apk --release --target-platform android-arm64
```

### App Bundle (для Google Play)
```bash
flutter build appbundle --release
```
Результат: `build/app/outputs/bundle/release/app-release.aab`

## Сборка iOS

```bash
flutter create --platforms=ios .
cd ios && pod install && cd ..
flutter build ios --release
```
Результат: `build/ios/iphoneos/Runner.app`

### Создание IPA
1. Откройте `ios/Runner.xcworkspace` в Xcode
2. Product → Archive
3. Distribute App

## Установка на устройство

### Android
```bash
flutter devices          # Проверка подключения
flutter install         # Установка
# или
adb install build/app/outputs/flutter-apk/app-release.apk
```

### iOS
```bash
flutter devices
flutter run -d <device-id>
```

## Оптимизация размера

```bash
flutter build apk --release --split-per-abi  # Разделение по архитектурам
flutter build apk --release --analyze-size    # Анализ размера
```

## Решение проблем

- **Flutter не найден**: Добавьте в PATH
- **ANDROID_HOME/JAVA_HOME**: Проверьте переменные окружения
- **Ошибки сборки**: `flutter clean && flutter pub get`
- **iOS ошибки**: Обновите CocoaPods, очистите кэш: `pod cache clean --all`
- **Недостаточно места**: Минимум 5 ГБ свободного места

## Дополнительные ресурсы

- [Flutter Mobile Documentation](https://docs.flutter.dev/development/platform-integration/mobile)
