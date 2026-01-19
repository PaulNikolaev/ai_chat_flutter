"""
Platform detection utility module.

This module provides functions to detect the current platform (desktop/mobile)
and operating system for conditional code execution. It enables platform-specific
behavior in the application, allowing the same codebase to work on both desktop
and mobile platforms.

The module detects:
- Mobile platforms: Android, iOS
- Desktop platforms: Windows, Linux, macOS
"""

import os
import sys


def is_mobile() -> bool:
    """
    Check if the application is running on a mobile platform.

    Detects Android and iOS platforms by checking for platform-specific
    environment variables and system attributes.

    Returns:
        bool: True if running on mobile platform (Android/iOS), False otherwise.
    """
    # Check for Android platform indicators
    android_indicators = [
        'ANDROID_ROOT' in os.environ,
        'ANDROID_DATA' in os.environ,
        hasattr(sys, 'getandroidapilevel'),
    ]
    
    # Check for iOS platform indicators
    ios_indicators = [
        sys.platform == 'ios',
        'IPHONEOS_DEPLOYMENT_TARGET' in os.environ,
    ]
    
    # Return True if any mobile indicator is present
    return any(android_indicators) or any(ios_indicators)


def is_desktop() -> bool:
    """
    Check if the application is running on a desktop platform.

    Detects Windows, Linux, and macOS platforms. Returns True if the
    platform is not mobile.

    Returns:
        bool: True if running on desktop platform (Windows/Linux/macOS), False otherwise.
    """
    return not is_mobile()


def get_platform() -> str:
    """
    Get the platform type as a string.

    Returns a human-readable string indicating whether the application
    is running on a desktop or mobile platform.

    Returns:
        str: Platform type - "mobile" or "desktop".
    """
    return "mobile" if is_mobile() else "desktop"


def get_os_name() -> str:
    """
    Get the operating system name.

    Returns the platform identifier from sys.platform, which can be:
    - 'win32' for Windows
    - 'linux' for Linux
    - 'darwin' for macOS
    - 'android' for Android (if detected)
    - 'ios' for iOS (if detected)

    Returns:
        str: Operating system platform identifier.
    """
    return sys.platform
