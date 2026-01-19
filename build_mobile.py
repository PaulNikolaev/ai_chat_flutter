"""
Mobile build script module.

This module provides build functionality for creating mobile applications
(Android APK files) from the Python application using Flet build tools.
Supports Android APK building with dependency management and environment checks.
"""
import os
import sys
import subprocess
import shutil
from pathlib import Path


def check_android_sdk() -> bool:
    """
    Check if Android SDK is properly configured.

    Verifies that ANDROID_HOME environment variable is set and points
    to a valid Android SDK installation directory.

    Returns:
        bool: True if Android SDK is configured, False otherwise.
    """
    android_home = os.environ.get('ANDROID_HOME')
    
    if not android_home:
        print("Ошибка: переменная окружения ANDROID_HOME не установлена.")
        print("Пожалуйста, установите ANDROID_HOME на путь к установке Android SDK.")
        return False
    
    if not os.path.exists(android_home):
        print(f"Ошибка: путь ANDROID_HOME не существует: {android_home}")
        return False
    
    print(f"Android SDK найден: {android_home}")
    return True


def check_java_home() -> bool:
    """
    Check if Java Development Kit (JDK) is properly configured.

    Verifies that JAVA_HOME environment variable is set and points
    to a valid JDK installation directory.

    Returns:
        bool: True if JDK is configured, False otherwise.
    """
    java_home = os.environ.get('JAVA_HOME')
    
    if not java_home:
        print("Ошибка: переменная окружения JAVA_HOME не установлена.")
        print("Пожалуйста, установите JAVA_HOME на путь к установке JDK.")
        return False
    
    if not os.path.exists(java_home):
        print(f"Ошибка: путь JAVA_HOME не существует: {java_home}")
        return False
    
    # Check if java executable exists
    java_exe = os.path.join(java_home, "bin", "java.exe" if sys.platform == "win32" else "java")
    if not os.path.exists(java_exe):
        print(f"Предупреждение: исполняемый файл Java не найден по ожидаемому пути: {java_exe}")
    
    print(f"JDK найден: {java_home}")
    return True


def check_flutter_sdk() -> bool:
    """
    Check if Flutter SDK is available.

    Verifies that 'flutter' command is available in PATH.
    Flutter SDK is required for building Android APK with Flet.

    Returns:
        bool: True if Flutter SDK is available, False otherwise.
    """
    # Check common Flutter installation paths on Windows
    # Try both .exe and .bat extensions
    base_paths = [
        os.path.join(os.environ.get('LOCALAPPDATA', ''), 'flutter', 'bin'),
        os.path.join(os.environ.get('USERPROFILE', ''), 'flutter', 'bin'),
        os.path.join(os.environ.get('USERPROFILE', ''), 'develop', 'flutter', 'bin'),
        'C:\\flutter\\bin',
        'C:\\src\\flutter\\bin',
    ]
    
    flutter_paths = []
    for base_path in base_paths:
        if base_path:
            flutter_paths.extend([
                os.path.join(base_path, 'flutter.exe'),
                os.path.join(base_path, 'flutter.bat'),
                os.path.join(base_path, 'flutter'),  # Linux/macOS style
            ])
    
    # Try to find flutter in PATH first
    try:
        result = subprocess.run(
            ["flutter", "--version"],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            # Extract version from output
            version_line = result.stdout.split('\n')[0]
            print(f"Flutter SDK найден: {version_line}")
            return True
    except FileNotFoundError:
        # If not in PATH, check common installation paths
        for flutter_path in flutter_paths:
            if flutter_path and os.path.exists(flutter_path):
                # Found Flutter in a common path, add it to PATH for this process
                flutter_bin = os.path.dirname(flutter_path)
                current_path = os.environ.get('PATH', '')
                if flutter_bin not in current_path:
                    os.environ['PATH'] = current_path + os.pathsep + flutter_bin
                
                # Try using just 'flutter' command now that PATH is updated
                # Or use the full path if needed
                try:
                    # First try with updated PATH
                    result = subprocess.run(
                        ["flutter", "--version"],
                        capture_output=True,
                        text=True,
                        timeout=10,
                        env=os.environ.copy()
                    )
                    if result.returncode == 0:
                        version_line = result.stdout.split('\n')[0]
                        print(f"Flutter SDK найден: {version_line}")
                        print(f"Путь: {flutter_bin}")
                        return True
                except Exception:
                    # Fallback: try with full path
                    try:
                        result = subprocess.run(
                            [flutter_path, "--version"],
                            capture_output=True,
                            text=True,
                            timeout=10
                        )
                        if result.returncode == 0:
                            version_line = result.stdout.split('\n')[0]
                            print(f"Flutter SDK найден: {version_line}")
                            print(f"Путь: {flutter_bin}")
                            return True
                    except Exception:
                        continue
        
        print("Ошибка: команда 'flutter' не найдена в PATH.")
        print("Проверенные пути:")
        for path in flutter_paths:
            if path:
                exists = "найден" if os.path.exists(path) else "не найден"
                print(f"  - {path}: {exists}")
        return False
    except subprocess.TimeoutExpired:
        print("Предупреждение: команда 'flutter --version' превысила время ожидания.")
        return False
    except Exception as e:
        print(f"Предупреждение: не удалось проверить установку Flutter SDK: {e}")
        return False


def check_build_tools() -> bool:
    """
    Check if required build tools are available.

    Verifies that 'flet' command is available
    and properly installed in the system.

    Returns:
        bool: True if all build tools are available, False otherwise.
    """
    print("Проверка инструментов сборки...")
    
    # Check if flet command is available
    try:
        result = subprocess.run(
            ["flet", "--version"],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            print(f"Flet найден: {result.stdout.strip()}")
        else:
            print("Предупреждение: команда 'flet' вернула ненулевой код возврата.")
    except FileNotFoundError:
        print("Ошибка: команда 'flet' не найдена.")
        print("  Решение: Установите Flet командой: pip install flet")
        return False
    except subprocess.TimeoutExpired:
        print("Предупреждение: команда 'flet --version' превысила время ожидания.")
    except Exception as e:
        print(f"Предупреждение: не удалось проверить установку 'flet': {e}")
    
    # Note: flet-builder is not a separate package - build tools are included in flet package
    
    return True


def install_mobile_dependencies() -> bool:
    """
    Install mobile-specific dependencies from requirements-mobile.txt.

    Runs pip install command to install all dependencies required for
    mobile application building.

    Returns:
        bool: True if installation succeeded, False otherwise.
    """
    requirements_file = Path("requirements-mobile.txt")
    
    if not requirements_file.exists():
        print(f"Ошибка: файл {requirements_file} не найден.")
        return False
    
    print("Установка зависимостей для мобильной сборки...")
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "-r", str(requirements_file)],
            check=True,
            capture_output=True,
            text=True
        )
        print("Зависимости для мобильной сборки успешно установлены.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Ошибка установки зависимостей (код возврата: {e.returncode})")
        if e.stdout:
            print(f"Вывод: {e.stdout}")
        if e.stderr:
            print(f"Детали ошибки: {e.stderr}")
        print("\nРешение проблем:")
        print("  1. Проверьте подключение к интернету")
        print("  2. Убедитесь, что файл requirements-mobile.txt корректен")
        print("  3. Попробуйте установить вручную: pip install -r requirements-mobile.txt")
        print("  4. Проверьте совместимость версии Python")
        return False
    except Exception as e:
        print(f"Неожиданная ошибка при установке зависимостей: {e}")
        print("\nРешение проблем:")
        print("  1. Проверьте работу pip: pip --version")
        print("  2. Попробуйте обновить pip: python -m pip install --upgrade pip")
        return False


def build_android_apk(
    project_name: str = "AIChat",
    package_name: str = "com.example.aichat",
    org: str = None,
    version: str = "1.0.0",
    build_number: int = 1,
    android_min_sdk: int = 21,
    icon_path: str = None,
    android_permissions: list = None
) -> bool:
    """
    Build Android APK file using Flet build tools.

    Performs environment checks, installs dependencies, and executes
    flet build apk command with specified parameters. The resulting
    APK file will be located at:
    build/android/app/build/outputs/apk/release/app-release.apk

    Args:
        project_name (str): Name of the project/application. Defaults to "AIChat".
        package_name (str): Android package name (e.g., com.example.app).
            Defaults to "com.example.aichat".
        org (str, optional): Organization identifier (e.g., com.example).
            If None, derived from package_name. Defaults to None.
        version (str): Application version string. Defaults to "1.0.0".
        build_number (int): Build number. Defaults to 1.
        android_min_sdk (int): Minimum Android SDK version. Defaults to 21 (Android 5.0).
        icon_path (str, optional): Path to application icon (PNG format).
            If None, uses default icon. Defaults to None.
        android_permissions (list, optional): List of Android permissions to request.
            Defaults to ["INTERNET", "ACCESS_NETWORK_STATE", "WRITE_EXTERNAL_STORAGE"].

    Returns:
        bool: True if build succeeded, False otherwise.
    """
    print("=" * 60)
    print("Сборка Android APK")
    print("=" * 60)
    print()
    
    # Check environment prerequisites
    print("Проверка предварительных требований...")
    if not check_android_sdk():
        print("\nРешение проблем:")
        print("  1. Установите Android SDK (через Android Studio или отдельно)")
        print("  2. Установите переменную окружения ANDROID_HOME на путь к SDK")
        print("     Пример: set ANDROID_HOME=C:\\Users\\YourName\\AppData\\Local\\Android\\Sdk")
        return False
    
    if not check_java_home():
        print("\nРешение проблем:")
        print("  1. Установите JDK (Java Development Kit) версии 11 или выше")
        print("  2. Установите переменную окружения JAVA_HOME на путь к установке JDK")
        print("     Пример: set JAVA_HOME=C:\\Program Files\\Java\\jdk-17")
        return False
    
    if not check_flutter_sdk():
        print("\nРешение проблем:")
        print("  1. Установите Flutter SDK: https://docs.flutter.dev/get-started/install")
        print("  2. Добавьте Flutter в PATH:")
        print("     - Windows: Добавьте <flutter_install_dir>\\flutter\\bin в PATH")
        print("     - Linux/macOS: Добавьте <flutter_install_dir>/flutter/bin в PATH")
        print("  3. Перезапустите терминал/IDE после установки")
        print("  4. Проверьте установку: flutter --version")
        return False
    
    if not check_build_tools():
        print("\nРешение проблем:")
        print("  1. Установите Flet: pip install flet")
        print("  2. Убедитесь, что директория скриптов Python в PATH")
        return False
    
    print()
    
    # Install mobile dependencies
    if not install_mobile_dependencies():
        return False
    
    print()
    
    # Set default Android permissions if not provided
    if android_permissions is None:
        android_permissions = [
            "INTERNET",
            "ACCESS_NETWORK_STATE",
            "WRITE_EXTERNAL_STORAGE"
        ]
    
    # Derive organization from package_name if not provided
    if org is None:
        # Extract org from package_name (e.g., "com.example" from "com.example.aichat")
        parts = package_name.split('.')
        if len(parts) >= 2:
            org = '.'.join(parts[:-1])
        else:
            org = "com.example"
    
    # Prepare flet build command
    print("Подготовка команды сборки Flet...")
    # Get current working directory (project root)
    # For Flet mobile builds, we need to pass project root because
    # main.py (now in project root) uses "from src.app import ChatApp" which requires src to be a package
    # Use absolute path to avoid issues with relative path resolution
    project_root = os.path.abspath(os.getcwd())
    
    build_command = [
        "flet",
        "build",
        "apk",
        project_root,  # Absolute path to project root
        "--project", project_name,
        "--org", org,
        "--build-version", version,
        "--build-number", str(build_number),
        # main.py is now in project root, so Flet will find it automatically
        # If needed, can specify: "--module-name", "main"
    ]
    
    # Add icon if provided and exists
    # Note: Flet uses icon from assets/ directory automatically if named correctly
    # Icon should be at: assets/icon.png for Android
    if icon_path:
        icon_file = Path(icon_path)
        if icon_file.exists():
            print(f"Иконка найдена: {icon_path} (будет использована автоматически)")
        else:
            print(f"Предупреждение: файл иконки не найден: {icon_path}")
    
    # Add Android permissions
    # Format: --android-permissions "PERMISSION1=True PERMISSION2=True"
    if android_permissions:
        # Convert to format: "PERMISSION1=True PERMISSION2=True"
        permissions_list = [f"{p}=True" for p in android_permissions]
        build_command.extend(["--android-permissions"] + permissions_list)
        print(f"Разрешения Android: {', '.join(android_permissions)}")
    
    print()
    print("Запуск процесса сборки APK...")
    print(f"Проект: {project_name}")
    print(f"Организация: {org}")
    print(f"Package ID: {org}.{project_name.lower()}")
    print(f"Версия: {version} (сборка {build_number})")
    if android_permissions:
        print(f"Разрешения: {', '.join(android_permissions)}")
    print()
    
    # Temporarily replace requirements.txt with requirements-mobile.txt for build
    # Flet uses requirements.txt during APK build, but it contains desktop-only packages
    requirements_backup = None
    requirements_mobile = Path("requirements-mobile.txt")
    requirements_txt = Path("requirements.txt")
    
    try:
        if requirements_mobile.exists() and requirements_txt.exists():
            # Backup original requirements.txt
            requirements_backup = Path("requirements.txt.backup")
            shutil.copy2(requirements_txt, requirements_backup)
            # Replace with mobile requirements
            shutil.copy2(requirements_mobile, requirements_txt)
            print("Временно заменен requirements.txt на requirements-mobile.txt для сборки")
    except Exception as e:
        print(f"Предупреждение: не удалось заменить requirements.txt: {e}")
        print("Продолжаем сборку с оригинальным requirements.txt")
    
    # Execute build command
    try:
        print("Выполнение команды сборки...")
        # Capture output for error handling but also allow real-time display
        result = subprocess.run(
            build_command,
            check=True,
            text=True
        )
        
        print()
        print("=" * 60)
        print("Сборка APK успешно завершена!")
        print("=" * 60)
        # Check both possible APK locations
        apk_paths = [
            Path("build/apk"),  # New location in Flet 0.80.2+
            Path("build/android/app/build/outputs/apk/release/app-release.apk"),  # Old location
        ]
        
        apk_found = False
        for apk_dir_or_file in apk_paths:
            if apk_dir_or_file.is_dir():
                # If it's a directory, look for .apk files inside
                apk_files = list(apk_dir_or_file.glob("*.apk"))
                if apk_files:
                    apk_path = apk_files[0]  # Use first APK found
                    print(f"Расположение APK: {apk_path.absolute()}")
                    print(f"Размер APK: {apk_path.stat().st_size / (1024 * 1024):.2f} MB")
                    apk_found = True
                    break
            elif apk_dir_or_file.exists():
                # If it's a file and exists
                print(f"Расположение APK: {apk_dir_or_file.absolute()}")
                print(f"Размер APK: {apk_dir_or_file.stat().st_size / (1024 * 1024):.2f} MB")
                apk_found = True
                break
        
        if not apk_found:
            print("Расположение APK: build/apk/ или build/android/app/build/outputs/apk/release/")
            print("Информация: APK файл должен находиться в одной из указанных директорий.")
        print("=" * 60)
        return True
        
    except subprocess.CalledProcessError as e:
        print()
        print("=" * 60)
        print("Ошибка сборки APK!")
        print("=" * 60)
        print(f"Код возврата: {e.returncode}")
        
        # Provide more detailed error information
        if e.stderr:
            print("\nВывод ошибки:")
            print("-" * 60)
            print(e.stderr)
        
        if e.stdout:
            print("\nВывод сборки:")
            print("-" * 60)
            print(e.stdout)
        
        print("\nРешение проблем:")
        print("  1. Проверьте, что все предварительные требования установлены:")
        print("     - Android SDK (ANDROID_HOME установлен правильно)")
        print("     - JDK (JAVA_HOME установлен правильно)")
        print("     - Пакет Flet установлен")
        print("  2. Убедитесь, что параметры сборки корректны:")
        print(f"     - Имя пакета: {package_name}")
        print(f"     - Организация: {org}")
        print(f"     - Путь к иконке: {icon_path or 'по умолчанию'}")
        print("  3. Проверьте логи сборки выше на наличие конкретных сообщений об ошибках")
        print("  4. Убедитесь, что у вас достаточно места на диске")
        print("  5. Попробуйте очистить артефакты предыдущей сборки:")
        print("     - Удалите директорию 'build/' если она существует")
        
        return False
        
    except FileNotFoundError:
        print()
        print("=" * 60)
        print("Ошибка: команда 'flet' не найдена.")
        print("=" * 60)
        print("Команда 'flet' недоступна в вашем PATH.")
        print("\nРешение проблем:")
        print("  1. Установите Flet: pip install flet")
        print("  2. Перезапустите терминал/IDE после установки")
        print("  4. Проверьте установку: flet --version")
        print("  5. Убедитесь, что директория Python Scripts в PATH:")
        print("     - Windows: C:\\PythonXX\\Scripts или %APPDATA%\\Python\\PythonXX\\Scripts")
        print("     - Linux/macOS: ~/.local/bin или /usr/local/bin")
        return False
    except Exception as e:
        print()
        print("=" * 60)
        print("Неожиданная ошибка во время сборки APK!")
        print("=" * 60)
        print(f"Тип ошибки: {type(e).__name__}")
        print(f"Сообщение об ошибке: {str(e)}")
        print("\nРешение проблем:")
        print("  1. Проверьте версию Python (требуется Python 3.8+)")
        print("  2. Убедитесь, что все зависимости установлены правильно")
        print("  3. Проверьте права доступа к директории сборки")
        print("  4. Изучите сообщение об ошибке выше для деталей")
        return False
        
    finally:
        # Restore original requirements.txt if it was backed up
        if requirements_backup and requirements_backup.exists():
            try:
                shutil.copy2(requirements_backup, requirements_txt)
                requirements_backup.unlink()  # Remove backup file
                print("Восстановлен оригинальный requirements.txt")
            except Exception as e:
                print(f"Предупреждение: не удалось восстановить requirements.txt: {e}")
                print(f"Вручную восстановите из {requirements_backup}")


def main():
    """
    Main build function entry point.

    Executes Android APK build with default parameters.
    Automatically checks for icon.png in assets directory.
    Can be customized by modifying function parameters.
    """
    # Check for PNG icon in assets directory
    icon_path = None
    icon_png = Path("assets/icon.png")
    icon_ico = Path("assets/icon.ico")
    
    if icon_png.exists():
        icon_path = str(icon_png)
        print(f"Найдена иконка: {icon_path}")
    elif icon_ico.exists():
        print("Примечание: Найден icon.ico, но для Android требуется формат PNG.")
        print("            APK будет использовать иконку Flet по умолчанию. Для использования собственной иконки:")
        print("            Конвертируйте icon.ico в PNG (рекомендуется 1024x1024) и сохраните как assets/icon.png")
    else:
        print("Примечание: Иконка не найдена. APK будет использовать иконку Flet по умолчанию.")
    
    # Default build parameters
    success = build_android_apk(
        project_name="AIChat",
        package_name="com.example.aichat",
        version="1.0.0",
        build_number=1,
        android_min_sdk=21,
        icon_path=icon_path  # Will be None if PNG not found, uses default Flet icon
    )
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
