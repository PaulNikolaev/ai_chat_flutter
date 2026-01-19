"""
Application logging utility module.

This module provides a logging system for the application with file and console
output. Logs are saved to dated files and formatted with timestamps for easy
tracking and debugging. Adapted for cross-platform compatibility including
mobile platforms (Android/iOS) with fallback mechanisms for file system access.
"""
import logging
import os
from datetime import datetime

from src.utils.platform import is_mobile


class AppLogger:
    """
    Application logger with file and console output.

    Provides centralized logging functionality with:
    - Daily log files with date-based naming
    - Console output for real-time monitoring
    - Multiple log levels (debug, info, warning, error)
    - Formatted messages with timestamps

    Attributes:
        logs_dir (str): Directory path for log files.
        logger (logging.Logger): Configured logger instance.
        file_handler_enabled (bool): Flag indicating if file logging is enabled.
    """

    def __init__(self):
        """
        Initialize logging system.

        Sets up log directory with platform-specific path handling, file handler
        with date-based naming, console handler, and message formatting.
        Includes fallback mechanisms for mobile platforms and file system
        accessibility issues.

        On Android, logs are stored in the app's internal storage directory.
        On desktop, logs are stored in a 'logs' directory relative to the app.
        """
        # Determine logs directory based on platform
        self.logs_dir = self._get_logs_directory()
        self.file_handler_enabled = False

        # Configure log message format: YYYY-MM-DD HH:MM:SS - LEVEL - Message
        formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )

        # Setup console handler (always available)
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)

        # Configure main logger
        self.logger = logging.getLogger('ChatApp')
        self.logger.setLevel(logging.DEBUG)
        self.logger.addHandler(console_handler)

        # Setup file handler with fallback for file system issues
        try:
            if self._ensure_logs_directory():
                # Create log file with current date: chat_app_YYYY-MM-DD.log
                current_date = datetime.now().strftime("%Y-%m-%d")
                log_file = os.path.join(self.logs_dir, f"chat_app_{current_date}.log")

                # Setup file handler with UTF-8 encoding
                file_handler = logging.FileHandler(
                    log_file,
                    encoding='utf-8'
                )
                file_handler.setFormatter(formatter)
                self.logger.addHandler(file_handler)
                self.file_handler_enabled = True
            else:
                # Log to console only if directory creation fails
                self.logger.warning(
                    f"Failed to create logs directory: {self.logs_dir}. "
                    "Logging to console only."
                )
        except (OSError, PermissionError, IOError) as e:
            # Fallback: continue with console logging only
            self.logger.warning(
                f"File logging unavailable ({e}). Logging to console only."
            )

    def _get_logs_directory(self) -> str:
        """
        Get platform-specific logs directory path.

        On mobile platforms (Android/iOS), uses app's internal storage.
        On desktop platforms, uses 'logs' directory relative to the application.

        Returns:
            str: Path to logs directory.
        """
        if is_mobile():
            # On Android, use app's internal storage
            # For Flet apps, try to use cache directory or app data directory
            try:
                # Try to use Android app data directory
                android_data = os.environ.get('ANDROID_DATA', '')
                if android_data:
                    # Use Android app-specific directory
                    app_logs_dir = os.path.join(
                        android_data,
                        'user',
                        '0',
                        'com.example.aichat',  # Package name placeholder
                        'files',
                        'logs'
                    )
                    return app_logs_dir
                else:
                    # Fallback: use current directory with 'logs' subdirectory
                    return os.path.join(os.getcwd(), 'logs')
            except Exception:
                # Ultimate fallback: current directory
                return os.path.join(os.getcwd(), 'logs')
        else:
            # Desktop: use 'logs' directory relative to application
            return os.path.join(os.getcwd(), 'logs')

    def _ensure_logs_directory(self) -> bool:
        """
        Ensure logs directory exists and is writable.

        Creates the directory if it doesn't exist and verifies write permissions.
        Handles potential file system access issues gracefully.

        Returns:
            bool: True if directory is accessible and writable, False otherwise.
        """
        try:
            # Check if directory exists
            if not os.path.exists(self.logs_dir):
                # Create directory with parent directories if needed
                os.makedirs(self.logs_dir, exist_ok=True)

            # Verify directory is writable by attempting to create a test file
            test_file = os.path.join(self.logs_dir, '.test_write')
            try:
                with open(test_file, 'w') as f:
                    f.write('test')
                os.remove(test_file)
                return True
            except (OSError, PermissionError, IOError):
                return False

        except (OSError, PermissionError, IOError):
            return False

    def info(self, message: str):
        """
        Log informational message.

        Used for recording important application information:
        successful operations, execution status, and state information.

        Args:
            message (str): Informational message text.
        """
        self.logger.info(message)

    def error(self, message: str, exc_info=None):
        """
        Log error message.

        Used for recording error information: exceptions, failures,
        and critical errors. Can include exception traceback.

        Args:
            message (str): Error message text.
            exc_info (bool, optional): If True, automatically includes
                exception traceback. Defaults to None.
        """
        self.logger.error(message, exc_info=exc_info)

    def debug(self, message: str):
        """
        Log debug message.

        Used for recording detailed debugging information:
        variable values, intermediate results, and execution details.

        Args:
            message (str): Debug message text.
        """
        self.logger.debug(message)

    def warning(self, message: str):
        """
        Log warning message.

        Used for recording warnings: potential issues, undesirable
        situations, and state warnings.

        Args:
            message (str): Warning message text.
        """
        self.logger.warning(message)
