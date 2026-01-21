plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ai_chat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ai_chat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Копируем артефакты в путь, где их ожидает flutter-cli,
// чтобы избежать сообщения "Gradle build failed to produce an .apk file".
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        // rootDir points to the Android root; один уровень вверх — корень Flutter-проекта
        val projectRoot = rootDir.parentFile
        if (projectRoot != null) {
            // APK
            val apkSrc = file("$buildDir/outputs/flutter-apk/app-release.apk")
            val apkDestDir = projectRoot.resolve("build/app/outputs/flutter-apk")
            if (apkSrc.exists()) {
                apkDestDir.mkdirs()
                copy {
                    from(apkSrc)
                    into(apkDestDir)
                }
            }

            // AAB
            val aabSrc = file("$buildDir/outputs/bundle/release/app-release.aab")
            val aabDestDir = projectRoot.resolve("build/app/outputs/bundle/release")
            if (aabSrc.exists()) {
                aabDestDir.mkdirs()
                copy {
                    from(aabSrc)
                    into(aabDestDir)
                }
            }
        }
    }
}