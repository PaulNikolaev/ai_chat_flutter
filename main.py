"""
Application entry point module.

This module provides the entry point for the desktop chat application.
It creates the ChatApp instance and launches the Flet application.
"""
import os
import sys
import traceback

import flet as ft

from src.app import ChatApp


def main():
    """
    Application entry point.

    Creates ChatApp instance and launches the Flet application.
    Includes error handling to prevent silent failures in PyInstaller builds.
    """
    # Prevent infinite restart loops by checking restart counter
    restart_counter = os.environ.get('FLET_RESTART_COUNT', '0')
    try:
        restart_count = int(restart_counter)
        if restart_count > 3:
            sys.exit(1)
        os.environ['FLET_RESTART_COUNT'] = str(restart_count + 1)
    except (ValueError, TypeError):
        os.environ['FLET_RESTART_COUNT'] = '1'
    
    try:
        app = ChatApp()
        
        # Use ft.run() instead of deprecated ft.app() (since Flet 0.70.0)
        # In Flet 0.80.2+, ft.run() takes the function as a positional argument
        # Explicitly set view to app for desktop window
        ft.run(app.main, view=ft.AppView.FLET_APP)
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        # Log error to file if possible, otherwise print to stderr
        error_msg = f"Fatal error in application startup: {e}\n"
        error_msg += "".join(traceback.format_exception(type(e), e, e.__traceback__))
        
        # Try to write to error log file
        try:
            error_log = os.path.join(os.path.dirname(sys.executable), "error.log")
            with open(error_log, "w", encoding="utf-8") as f:
                f.write(error_msg)
        except:
            pass
        sys.exit(1)


if __name__ == "__main__":
    main()
