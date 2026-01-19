"""
Main application class module.

This module provides the main chat application class with full-featured
UI, API integration, caching, logging, analytics, and performance monitoring.
It combines all components into a complete desktop chat application.
"""
import asyncio
import json
import os
import sys
import time
import traceback
from datetime import datetime

import flet as ft

from src.api.openrouter import OpenRouterClient
from src.auth import AuthManager, AuthStorage
from src.ui.components import MessageBubble, ModelSelector
from src.ui.login import LoginWindow
from src.ui.styles import AppStyles
from src.utils.analytics import Analytics
from src.utils.cache import ChatCache
from src.utils.logger import AppLogger
from src.utils.monitor import PerformanceMonitor
from src.utils.platform import is_mobile


class ChatApp:
    """
    Main chat application class.

    Manages all application logic including UI, API interactions, caching,
    logging, analytics, and performance monitoring. Provides a complete
    desktop chat interface with AI model integration.

    Attributes:
        api_client (OpenRouterClient): Client for OpenRouter API.
        cache (ChatCache): Chat history cache instance.
        logger (AppLogger): Application logger instance.
        analytics (Analytics): Analytics tracking instance.
        monitor (PerformanceMonitor or None): Performance monitoring instance.
            None if initialization failed or on platforms without psutil support.
        auth_manager (AuthManager): Authentication manager instance.
        balance_text (ft.Text): Balance display text component.
        exports_dir (str): Directory path for exported chat history.
        is_authenticated (bool): Authentication state flag.
    """

    def __init__(self):
        """
        Initialize main application components.

        Sets up cache, logger, analytics, monitor, authentication manager,
        and exports directory. OpenRouterClient is initialized only after
        successful authentication.
        """
        # Initialize core components (no API client yet)
        self.cache = ChatCache()
        self.logger = AppLogger()
        self.analytics = Analytics(self.cache)
        
        # Initialize performance monitor with error handling
        try:
            self.monitor = PerformanceMonitor()
        except Exception as e:
            # Fallback if PerformanceMonitor initialization fails
            self.logger.warning(f"Failed to initialize PerformanceMonitor: {e}")
            self.monitor = None

        # Initialize authentication
        auth_storage = AuthStorage(self.cache)
        self.auth_manager = AuthManager(auth_storage)
        self.is_authenticated = self.auth_manager.is_authenticated()

        # API client will be initialized after authentication
        self.api_client = None

        # Create balance display component
        self.balance_text = ft.Text(
            "Баланс: Загрузка...",
            **AppStyles.BALANCE_TEXT
        )

        # Create exports directory with platform-specific path handling
        self.exports_dir = self._get_exports_directory()
        self._ensure_exports_directory()

    def _get_exports_directory(self) -> str:
        """
        Get platform-specific exports directory path.

        On mobile platforms (Android/iOS), uses app's internal storage.
        On desktop platforms, uses 'exports' directory relative to the application.

        Returns:
            str: Path to exports directory.
        """
        if is_mobile():
            # On Android, use app's internal storage
            try:
                # Try to use Android app data directory
                android_data = os.environ.get('ANDROID_DATA', '')
                if android_data:
                    # Use Android app-specific directory
                    app_exports_dir = os.path.join(
                        android_data,
                        'user',
                        '0',
                        'com.example.aichat',  # Package name placeholder
                        'files',
                        'exports'
                    )
                    return app_exports_dir
                else:
                    # Fallback: use current directory with 'exports' subdirectory
                    return os.path.join(os.getcwd(), 'exports')
            except Exception:
                # Ultimate fallback: current directory
                return os.path.join(os.getcwd(), 'exports')
        else:
            # Desktop: use 'exports' directory relative to application
            return os.path.join(os.getcwd(), 'exports')

    def _ensure_exports_directory(self) -> bool:
        """
        Ensure exports directory exists and is writable.

        Creates the directory if it doesn't exist and verifies write permissions.
        Handles potential file system access issues gracefully.

        Returns:
            bool: True if directory is accessible and writable, False otherwise.
        """
        try:
            # Check if directory exists
            if not os.path.exists(self.exports_dir):
                # Create directory with parent directories if needed
                os.makedirs(self.exports_dir, exist_ok=True)

            # Verify directory is writable by attempting to create a test file
            test_file = os.path.join(self.exports_dir, '.test_write')
            try:
                with open(test_file, 'w') as f:
                    f.write('test')
                os.remove(test_file)
                return True
            except (OSError, PermissionError, IOError) as e:
                self.logger.warning(
                    f"Exports directory is not writable: {self.exports_dir}. Error: {e}"
                )
                return False

        except (OSError, PermissionError, IOError) as e:
            self.logger.warning(
                f"Failed to create exports directory: {self.exports_dir}. Error: {e}"
            )
            return False

    def load_chat_history(self):
        """
        Load chat history from cache and display in interface.

        Retrieves cached messages and adds them to the chat interface
        in reverse order to maintain proper chronology.
        """
        try:
            history = self.cache.get_chat_history()
            for msg in reversed(history):
                _, model, user_message, ai_response, timestamp, tokens = msg
                self.chat_history.controls.extend([
                    MessageBubble(
                        message=user_message,
                        is_user=True
                    ),
                    MessageBubble(
                        message=ai_response,
                        is_user=False
                    )
                ])
        except Exception as e:
            self.logger.error(f"Ошибка загрузки истории чата: {e}")

    def update_balance(self):
        """
        Update API balance display in interface.

        Fetches balance from API and updates display. Shows balance in green
        on success, or 'н/д' (not available) in red on error.
        """
        if not self.api_client:
            return
        try:
            balance = self.api_client.get_balance()
            self.balance_text.value = f"Баланс: {balance}"
            self.balance_text.color = ft.Colors.GREEN_400
        except Exception as e:
            self.balance_text.value = "Баланс: н/д"
            self.balance_text.color = ft.Colors.RED_400
            self.logger.error(f"Ошибка обновления баланса: {e}")

    def main(self, page: ft.Page):
        """
        Main application entry point and UI initialization.

        Creates all UI components, sets up event handlers, and configures
        the application interface.

        Args:
            page (ft.Page): Flet page instance to configure.
        """
        try:
            # Apply page settings from style configuration
            for key, value in AppStyles.PAGE_SETTINGS.items():
                setattr(page, key, value)

            AppStyles.set_window_size(page)

            # Check authentication and show login if needed
            if not self.is_authenticated:
                self._show_login_window(page)
                return

            # Initialize API client with stored key if not already initialized
            if not self.api_client:
                self._initialize_api_client()

            # Continue with main application setup
            self._setup_main_ui(page)
        except Exception as e:
            # Log error and show error message to prevent silent failures
            error_msg = f"Критическая ошибка при запуске приложения: {e}\n"
            error_msg += "".join(traceback.format_exception(type(e), e, e.__traceback__))
            self.logger.error(error_msg)
            
            # Show error dialog to user
            try:
                page.add(
                    ft.AlertDialog(
                        title=ft.Text("Ошибка запуска"),
                        content=ft.Text(f"Приложение не может запуститься:\n{str(e)}"),
                        actions=[
                            ft.TextButton(content=ft.Text("Закрыть"), on_click=lambda _: page.window_close())
                        ],
                        open=True
                    )
                )
                page.update()
            except:
                # If dialog fails, exit immediately to prevent restart loop
                os._exit(1)  # Use os._exit to prevent any cleanup or restart

    def _setup_main_ui(self, page: ft.Page):
        """
        Set up main application UI.

        Creates and displays all main application components including
        model selector, chat history, input fields, and control buttons.

        Args:
            page (ft.Page): Flet page instance.
        """
        # Initialize model selector dropdown
        if self.api_client:
            models = self.api_client.available_models
            self.model_dropdown = ModelSelector(models)
            self.model_dropdown.value = models[0]['id'] if models else None

        async def send_message_click(e):
            """
            Handle message sending to AI model.

            Processes user input, sends to API, displays response, and
            updates cache, analytics, and monitoring.
            """
            if not self.message_input.value:
                return

            try:
                # Visual feedback
                self.message_input.border_color = ft.Colors.BLUE_400
                page.update()

                # Save message data
                start_time = time.time()
                user_message = self.message_input.value
                self.message_input.value = ""
                page.update()

                # Add user message
                self.chat_history.controls.append(
                    MessageBubble(message=user_message, is_user=True)
                )

                # Show loading indicator
                loading = ft.ProgressRing()
                self.chat_history.controls.append(loading)
                page.update()

                # Send request asynchronously
                loop = asyncio.get_event_loop()
                response = await loop.run_in_executor(
                    None,
                    lambda: self.api_client.send_message(
                        user_message,
                        self.model_dropdown.value
                    )
                )

                # Remove loading indicator
                self.chat_history.controls.remove(loading)

                # Process response
                if "error" in response:
                    response_text = f"Error: {response['error']}"
                    tokens_used = 0
                    self.logger.error(f"Ошибка API: {response['error']}")
                else:
                    response_text = response["choices"][0]["message"]["content"]
                    tokens_used = response.get("usage", {}).get("total_tokens", 0)

                # Save to cache
                self.cache.save_message(
                    model=self.model_dropdown.value,
                    user_message=user_message,
                    ai_response=response_text,
                    tokens_used=tokens_used
                )

                # Add AI response
                self.chat_history.controls.append(
                    MessageBubble(message=response_text, is_user=False)
                )

                # Update analytics
                response_time = time.time() - start_time
                self.analytics.track_message(
                    model=self.model_dropdown.value,
                    message_length=len(user_message),
                    response_time=response_time,
                    tokens_used=tokens_used
                )

                # Log performance metrics (if monitor is available)
                if self.monitor is not None:
                    try:
                        self.monitor.log_metrics(self.logger)
                    except Exception as e:
                        self.logger.warning(f"Failed to log performance metrics: {e}")
                
                page.update()

            except Exception as e:
                self.logger.error(f"Ошибка отправки сообщения: {e}")
                self.message_input.border_color = ft.Colors.RED_500

                # Show error notification
                snack = ft.SnackBar(
                    content=ft.Text(
                        str(e),
                        color=ft.Colors.RED_500,
                        weight=ft.FontWeight.BOLD
                    ),
                    bgcolor=ft.Colors.GREY_900,
                    duration=5000,
                )
                page.overlay.append(snack)
                snack.open = True
                page.update()

        def show_error_snack(page, message: str):
            """
            Display error notification snackbar.

            Args:
                page (ft.Page): Page instance.
                message (str): Error message to display.
            """
            snack = ft.SnackBar(
                content=ft.Text(
                    message,
                    color=ft.Colors.RED_500
                ),
                bgcolor=ft.Colors.GREY_900,
                duration=5000,
            )
            page.overlay.append(snack)
            snack.open = True
            page.update()

        async def show_analytics(e):
            """
            Display analytics statistics dialog.

            Shows aggregated usage statistics including total messages,
            tokens, averages, and model usage.
            """
            stats = self.analytics.get_statistics()

            def close_analytics_dialog(e):
                close_dialog(dialog)
            
            dialog = ft.AlertDialog(
                title=ft.Text("Аналитика"),
                content=ft.Column([
                    ft.Text(f"Всего сообщений: {stats['total_messages']}"),
                    ft.Text(f"Всего токенов: {stats['total_tokens']}"),
                    ft.Text(f"Среднее токенов/сообщение: {stats['tokens_per_message']:.2f}"),
                    ft.Text(f"Сообщений в минуту: {stats['messages_per_minute']:.2f}")
                ]),
                actions=[
                    ft.TextButton(content=ft.Text("Закрыть"), on_click=close_analytics_dialog),
                ],
            )

            page.show_dialog(dialog)

        def clear_history(e):
            """
            Clear chat history from cache and interface.

            Removes all messages from cache, analytics, and UI display.
            """
            try:
                self.cache.clear_history()
                self.analytics.clear_data()
                self.chat_history.controls.clear()
                page.update()  # Update UI after clearing

            except Exception as e:
                self.logger.error(f"Ошибка очистки истории: {e}")
                show_error_snack(page, f"Ошибка очистки истории: {str(e)}")

        def close_dialog(dialog):
            """
            Close dialog window.

            Args:
                dialog: Dialog instance to close.
            """
            dialog.open = False
            page.update()

        async def confirm_clear_history(e):
            """
            Show confirmation dialog before clearing history.

            Displays a modal dialog asking for confirmation before
            executing the clear history operation.
            """
            def close_dlg(e):
                close_dialog(dialog)

            def clear_confirmed(e):
                # Close dialog first
                close_dialog(dialog)
                # Then clear history (now synchronous)
                clear_history(e)

            dialog = ft.AlertDialog(
                modal=True,
                title=ft.Text("Подтверждение удаления"),
                content=ft.Text("Вы уверены? Это действие нельзя отменить!"),
                actions=[
                    ft.TextButton(
                        content=ft.Text("Отмена"),
                        on_click=close_dlg
                    ),
                    ft.TextButton(
                        content=ft.Text("Очистить"),
                        on_click=clear_confirmed
                    ),
                ],
                actions_alignment=ft.MainAxisAlignment.END,
            )

            page.show_dialog(dialog)

        async def save_dialog(e):
            """
            Save chat history to JSON file.

            Exports chat history from cache to a timestamped JSON file
            in the exports directory.
            """
            try:
                history = self.cache.get_chat_history()

                # Format data for export
                dialog_data = []
                for msg in history:
                    dialog_data.append({
                        "timestamp": msg[4],
                        "model": msg[1],
                        "user_message": msg[2],
                        "ai_response": msg[3],
                        "tokens_used": msg[5]
                    })

                # Verify exports directory is accessible before saving
                if not self._ensure_exports_directory():
                    raise IOError(
                        f"Exports directory is not accessible or writable: {self.exports_dir}"
                    )

                # Verify exports directory is accessible before saving
                if not self._ensure_exports_directory():
                    raise IOError(
                        f"Exports directory is not accessible or writable: {self.exports_dir}"
                    )

                # Create filename with timestamp
                filename = f"chat_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                filepath = os.path.join(self.exports_dir, filename)

                # Save to JSON with error handling
                try:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        json.dump(dialog_data, f, ensure_ascii=False, indent=2, default=str)
                except (OSError, PermissionError, IOError) as e:
                    raise IOError(f"Failed to write file: {filepath}. Error: {e}")

                # Show success dialog
                dialog = ft.AlertDialog(
                    modal=True,
                    title=ft.Text("Диалог сохранен"),
                    content=ft.Column([
                        ft.Text("Путь сохранения:"),
                        ft.Text(filepath, selectable=True, weight=ft.FontWeight.BOLD),
                    ]),
                )
                
                def close_save_dialog(e):
                    close_dialog(dialog)
                
                def open_folder(e):
                    os.startfile(self.exports_dir)
                    close_dialog(dialog)
                
                dialog.actions = [
                    ft.TextButton(content=ft.Text("OK"), on_click=close_save_dialog),
                ]
                
                # Only add "Open folder" button on desktop platforms
                # os.startfile() is Windows-specific and not available on mobile
                if not is_mobile() and os.name == 'nt':
                    dialog.actions.append(
                        ft.TextButton(
                            content=ft.Text("Открыть папку"),
                            on_click=open_folder
                        )
                    )

                page.show_dialog(dialog)

            except Exception as e:
                self.logger.error(f"Ошибка сохранения: {e}")
                show_error_snack(page, f"Ошибка сохранения: {str(e)}")

        # Create UI components with responsive styles
        self.message_input = ft.TextField(**AppStyles.get_message_input_style())
        self.chat_history = ft.ListView(**AppStyles.get_chat_history_style())

        # Load existing history
        self.load_chat_history()

        # Create control buttons
        # In Flet 0.80+, buttons use content=ft.Text() instead of text=
        save_button_style = AppStyles.SAVE_BUTTON.copy()
        save_text = save_button_style.pop("text", "Сохранить")
        save_button = ft.ElevatedButton(
            content=ft.Text(save_text),
            on_click=save_dialog,
            **save_button_style
        )

        clear_button_style = AppStyles.CLEAR_BUTTON.copy()
        clear_text = clear_button_style.pop("text", "Очистить")
        clear_button = ft.ElevatedButton(
            content=ft.Text(clear_text),
            on_click=confirm_clear_history,
            **clear_button_style
        )

        send_button_style = AppStyles.get_send_button_style()
        send_text = send_button_style.pop("text", "Отправка")
        send_button = ft.ElevatedButton(
            content=ft.Text(send_text),
            on_click=send_message_click,
            **send_button_style
        )

        analytics_button_style = AppStyles.ANALYTICS_BUTTON.copy()
        analytics_text = analytics_button_style.pop("text", "Аналитика")
        analytics_button = ft.ElevatedButton(
            content=ft.Text(analytics_text),
            on_click=show_analytics,
            **analytics_button_style
        )

        async def handle_logout(e):
            """
            Handle logout button click.

            Resets authentication state and returns to PIN login window.
            Does not clear stored authentication data.
            """
            self.is_authenticated = False
            self.api_client = None
            page.controls.clear()
            self._show_login_window(page)

        logout_button_style = AppStyles.LOGOUT_BUTTON.copy()
        logout_text = logout_button_style.pop("text", "Выйти")
        logout_button = ft.ElevatedButton(
            content=ft.Text(logout_text),
            on_click=handle_logout,
            **logout_button_style
        )

        # Create layout components - buttons in 2 rows, 2 buttons each
        control_buttons = ft.Column(
            controls=[
                ft.Row(
                    controls=[
                        save_button,
                        analytics_button,
                    ],
                    **AppStyles.CONTROL_BUTTONS_ROW
                ),
                ft.Row(
                    controls=[
                        clear_button,
                        logout_button,
                    ],
                    **AppStyles.CONTROL_BUTTONS_ROW
                ),
            ],
            spacing=10,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        )

        # Create input layout: vertical on mobile, horizontal on desktop
        if is_mobile():
            # On mobile: field and button stacked vertically
            input_container = ft.Column(
                controls=[
                    self.message_input,
                    send_button
                ],
                spacing=10,
                horizontal_alignment=ft.CrossAxisAlignment.STRETCH,
            )
        else:
            # On desktop: field and button side by side
            input_container = ft.Row(
                controls=[
                    self.message_input,
                    send_button
                ],
                **AppStyles.get_input_row_style()
            )

        controls_column = ft.Column(
            controls=[
                input_container,
                control_buttons
            ],
            **AppStyles.CONTROLS_COLUMN
        )

        balance_container = ft.Container(
            content=self.balance_text,
            **AppStyles.BALANCE_CONTAINER
        )

        model_selection = ft.Column(
            controls=[
                self.model_dropdown.search_field,
                self.model_dropdown,
                balance_container
            ],
            **AppStyles.MODEL_SELECTION_COLUMN
        )

        self.main_column = ft.Column(
            controls=[
                model_selection,
                self.chat_history,
                controls_column
            ],
            **AppStyles.MAIN_COLUMN
        )

        # Add main column to page
        page.add(self.main_column)

        # Initialize monitor (if available)
        if self.monitor is not None:
            try:
                self.monitor.get_metrics()
            except Exception as e:
                self.logger.warning(f"Failed to initialize monitor metrics: {e}")

    def _initialize_api_client(self):
        """
        Initialize OpenRouterClient with stored API key.

        Retrieves API key from authentication storage and initializes
        the API client. Updates balance display.
        """
        api_key = self.auth_manager.get_stored_api_key()
        if api_key:
            # Set API key in environment for OpenRouterClient
            os.environ["OPENROUTER_API_KEY"] = api_key
            os.environ["BASE_URL"] = "https://openrouter.ai/api/v1"

            self.api_client = OpenRouterClient()
            self.update_balance()

    def _show_login_window(self, page: ft.Page):
        """
        Display login window for authentication.

        Shows appropriate login form (API key or PIN) based on
        authentication state and handles login flow.

        Args:
            page (ft.Page): Flet page instance.
        """
        is_first_login = not self.auth_manager.is_authenticated()
        login_window = LoginWindow(is_first_login=is_first_login)

        async def handle_login(e):
            """Handle login button click."""
            login_window.clear_status()

            pin = login_window.get_pin()
            api_key = login_window.get_api_key()

            # Determine which authentication method to use
            if is_first_login:
                # First-time login: only API key is available
                if not api_key:
                    login_window.show_status("Введите API ключ", is_error=True)
                    page.update()
                    return

                success, message, balance = self.auth_manager.handle_first_login(api_key)
                if success:
                    # Show generated PIN
                    login_window.show_status(
                        f"PIN сгенерирован: {message}. Баланс: {balance}",
                        is_error=False
                    )
                    page.update()

                    # Wait a bit, then initialize and show main UI
                    await asyncio.sleep(2)
                    self.is_authenticated = True
                    self._initialize_api_client()
                    page.controls.clear()
                    self._setup_main_ui(page)
                else:
                    login_window.show_status(message, is_error=True)
                    page.update()
            else:
                # Subsequent login: can use either PIN or API key
                if pin and len(pin) == 4:
                    # Try PIN login first
                    success, api_key_result, _ = self.auth_manager.handle_pin_login(pin)
                    if success:
                        self.is_authenticated = True
                        self._initialize_api_client()
                        page.controls.clear()
                        self._setup_main_ui(page)
                        return
                    else:
                        login_window.show_status("Неверный PIN", is_error=True)
                        page.update()
                        return
                elif api_key:
                    # Try API key login
                    success, message, balance = self.auth_manager.handle_api_key_login(api_key)
                    if success:
                        login_window.show_status(
                            f"Вход выполнен. {message}. Баланс: {balance}",
                            is_error=False
                        )
                        page.update()

                        # Wait a bit, then initialize and show main UI
                        await asyncio.sleep(1.5)
                        self.is_authenticated = True
                        self._initialize_api_client()
                        page.controls.clear()
                        self._setup_main_ui(page)
                    else:
                        login_window.show_status(message, is_error=True)
                        page.update()
                else:
                    # Neither field is filled
                    login_window.show_status(
                        "Введите PIN (4 цифры) или API ключ",
                        is_error=True
                    )
                    page.update()

        async def handle_reset(e):
            """Handle reset button click."""
            if self.auth_manager.handle_reset():
                self.is_authenticated = False
                page.controls.clear()
                # Show first-time login window
                self._show_login_window(page)
            else:
                login_window.show_status("Ошибка сброса ключа", is_error=True)
                page.update()

        # Set up button handlers
        login_window.login_button.on_click = handle_login
        login_window.reset_button.on_click = handle_reset

        # Center login window on page
        page.add(
            ft.Row(
                controls=[login_window.container],
                alignment=ft.MainAxisAlignment.CENTER,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                expand=True,
            )
        )
