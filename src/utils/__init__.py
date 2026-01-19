"""
Utils package initialization.

Contains utility modules for the application including analytics, caching,
logging, performance monitoring, and platform detection utilities.
"""
from .analytics import Analytics
from .cache import ChatCache
from .logger import AppLogger
from .monitor import PerformanceMonitor
from .platform import (
    is_mobile,
    is_desktop,
    get_platform,
    get_os_name
)

__all__ = [
    'Analytics',
    'ChatCache',
    'AppLogger',
    'PerformanceMonitor',
    'is_mobile',
    'is_desktop',
    'get_platform',
    'get_os_name',
]
