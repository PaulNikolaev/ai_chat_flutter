"""
Build script module.

This module provides build functionality for creating executable files
from the Python application using PyInstaller. Supports both Windows
and Linux platforms with platform-specific build configurations.
"""
import os
import sys
import shutil
import subprocess
from pathlib import Path


def build_windows():
    """
    Build Windows application directory using PyInstaller.

    Installs project dependencies, creates output directory, runs PyInstaller
    with Windows-specific configuration, and moves the resulting application
    directory to the bin folder.

    The build process creates a directory with executable and all dependencies
    with admin privileges request on launch and no console window.
    """
    print("Сборка исполняемого файла для Windows...")

    # Install project dependencies
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])

    # Run PyInstaller with Windows-specific configuration
    subprocess.run([
        "pyinstaller",
        "--onedir",
        "--windowed",
        "--icon=assets/icon.ico",
        "--name=AIChat",
        "--clean",
        "--noupx",
        "--uac-admin",
        "--paths=src",
        "--add-data=src;src",
        "--hidden-import=requests",
        "--hidden-import=flet",
        "--hidden-import=psutil",
        "--hidden-import=dotenv",
        "--hidden-import=python_dotenv",
        "--hidden-import=asyncio",
        "--hidden-import=sqlite3",
        "--hidden-import=hashlib",
        "--hidden-import=datetime",
        "--hidden-import=json",
        "--hidden-import=os",
        "--hidden-import=sys",
        "--hidden-import=threading",
        "--hidden-import=logging",
        "--hidden-import=time",
        "--hidden-import=random",
        "--collect-all=flet",
        "--collect-submodules=dotenv",
        "main.py"
    ])

    # Move built directory to root as AIChat/
    try:
        # Remove old AIChat directory if exists
        output_dir = Path("AIChat")
        if output_dir.exists():
            shutil.rmtree(output_dir)
        # Move new directory from dist to root
        shutil.move("dist/AIChat", "AIChat")
        print("Сборка для Windows завершена! Расположение исполняемого файла: AIChat/AIChat.exe")
    except Exception as e:
        print(f"Сборка для Windows завершена! Расположение исполняемого файла: dist/AIChat/AIChat.exe")
        print(f"Предупреждение: Не удалось переместить в директорию AIChat: {e}")


def build_linux():
    """
    Build Linux application directory using PyInstaller.

    Installs project dependencies, creates output directory, runs PyInstaller
    with Linux-specific configuration including application icon, and moves
    the resulting application directory to the bin folder.

    The build process creates a directory with executable and all dependencies
    without console window.
    """
    print("Сборка исполняемого файла для Linux...")

    # Install project dependencies
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])

    # Run PyInstaller with Linux-specific configuration
    subprocess.run([
        "pyinstaller",
        "--onedir",
        "--windowed",
        "--icon=assets/icon.ico",
        "--name=aichat",
        "--paths=src",
        "--add-data=src:src",
        "--hidden-import=requests",
        "--hidden-import=flet",
        "--hidden-import=psutil",
        "--hidden-import=dotenv",
        "--hidden-import=python_dotenv",
        "--hidden-import=asyncio",
        "--hidden-import=sqlite3",
        "--hidden-import=hashlib",
        "--hidden-import=datetime",
        "--hidden-import=json",
        "--hidden-import=os",
        "--hidden-import=sys",
        "--hidden-import=threading",
        "--hidden-import=logging",
        "--hidden-import=time",
        "--hidden-import=random",
        "--collect-all=flet",
        "--collect-submodules=dotenv",
        "main.py"
    ])

    # Move built directory to root as AIChat/
    try:
        # Remove old AIChat directory if exists
        output_dir = Path("AIChat")
        if output_dir.exists():
            shutil.rmtree(output_dir)
        # Move new directory from dist to root and rename
        shutil.move("dist/aichat", "AIChat")
        print("Сборка для Linux завершена! Расположение исполняемого файла: AIChat/aichat")
    except Exception as e:
        print(f"Сборка для Linux завершена! Расположение исполняемого файла: dist/aichat/aichat")
        print(f"Предупреждение: Не удалось переместить в директорию AIChat: {e}")


def main():
    """
    Main build function entry point.

    Detects the operating system platform and invokes the appropriate
    build function (Windows or Linux). Prints an error message if the
    platform is not supported.
    """
    # Detect platform and run appropriate build function
    if sys.platform.startswith('win'):
        build_windows()
    elif sys.platform.startswith('linux'):
        build_linux()
    else:
        print("Неподдерживаемая платформа")


if __name__ == "__main__":
    main()
