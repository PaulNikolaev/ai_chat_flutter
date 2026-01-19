"""
UI styles module.

This module provides centralized style configurations for all UI components
in the application. Contains constants and configurations for visual elements
including page settings, chat components, buttons, input fields, and layout elements.
Adapted for cross-platform compatibility including mobile platforms with responsive
sizing and layout adjustments.
"""
import flet as ft

from src.utils.platform import is_mobile


class AppStyles:
    """
    Centralized application styles configuration.

    Contains style dictionaries and constants for all visual elements of the UI.
    Provides consistent styling across the application and easy theme management.

    Attributes:
        PAGE_SETTINGS (dict): Main page configuration settings.
        CHAT_HISTORY (dict): Chat history area styling.
        MESSAGE_INPUT (dict): Message input field styling.
        SEND_BUTTON (dict): Send button configuration.
        SAVE_BUTTON (dict): Save button configuration.
        CLEAR_BUTTON (dict): Clear history button configuration.
        ANALYTICS_BUTTON (dict): Analytics button configuration.
        INPUT_ROW (dict): Input row layout settings.
        CONTROL_BUTTONS_ROW (dict): Control buttons row layout settings.
        CONTROLS_COLUMN (dict): Controls column layout settings.
        MAIN_COLUMN (dict): Main column layout settings.
        MODEL_SEARCH_FIELD (dict): Model search field styling.
        MODEL_DROPDOWN (dict): Model dropdown styling.
        MODEL_SELECTION_COLUMN (dict): Model selection column layout settings.
        BALANCE_TEXT (dict): Balance text styling.
        BALANCE_CONTAINER (dict): Balance container styling.
    """

    PAGE_SETTINGS = {
        "title": "AI Chat",
        "vertical_alignment": ft.MainAxisAlignment.CENTER,
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,
        "padding": 20,
        "bgcolor": ft.Colors.GREY_900,
        "theme_mode": ft.ThemeMode.DARK,
    }

    @staticmethod
    def get_chat_history_style() -> dict:
        """
        Get responsive chat history style based on platform.
        
        Returns style dictionary with fixed height for desktop or expand=True
        for mobile platforms.
        
        Returns:
            dict: Style dictionary for chat history.
        """
        base_style = {
            "expand": True,
            "spacing": 10,
            "auto_scroll": True,
            "padding": 20,
        }
        # Don't set fixed height on mobile - let it expand
        if not is_mobile():
            base_style["height"] = 400
        return base_style

    CHAT_HISTORY = {
        "expand": True,
        "spacing": 10,
        "height": 400,
        "auto_scroll": True,
        "padding": 20,
    }

    @staticmethod
    def get_message_input_style() -> dict:
        """
        Get responsive message input style based on platform.
        
        Returns style dictionary with fixed width for desktop or expand=True
        for mobile platforms.
        
        Returns:
            dict: Style dictionary for message input field.
        """
        base_style = {
            "height": 50,
            "multiline": False,
            "text_size": 16,
            "color": ft.Colors.WHITE,
            "bgcolor": ft.Colors.GREY_800,
            "border_color": ft.Colors.BLUE_400,
            "cursor_color": ft.Colors.WHITE,
            "content_padding": 10,
            "border_radius": 8,
            "hint_text": "Введите сообщение здесь...",
            "shift_enter": True,
        }
        if not is_mobile():
            base_style["width"] = 400
        else:
            base_style["expand"] = True
        return base_style

    # Keep MESSAGE_INPUT for backward compatibility, but it should use get_message_input_style() instead
    MESSAGE_INPUT = {
        "width": 400,
        "height": 50,
        "multiline": False,
        "text_size": 16,
        "color": ft.Colors.WHITE,
        "bgcolor": ft.Colors.GREY_800,
        "border_color": ft.Colors.BLUE_400,
        "cursor_color": ft.Colors.WHITE,
        "content_padding": 10,
        "border_radius": 8,
        "hint_text": "Введите сообщение здесь...",
        "shift_enter": True,
    }

    @staticmethod
    def get_send_button_style() -> dict:
        """
        Get responsive send button style based on platform.
        
        Returns style dictionary with fixed width for desktop or adaptive
        sizing for mobile platforms.
        
        Returns:
            dict: Style dictionary for send button.
        """
        base_style = {
            "text": "Отправка",
            "icon": ft.Icons.SEND_ROUNDED,
            "style": ft.ButtonStyle(
                color=ft.Colors.WHITE,
                bgcolor=ft.Colors.BLUE_700,
                padding=10,
            ),
            "tooltip": "Отправить сообщение",
            "height": 40,
        }
        if not is_mobile():
            base_style["width"] = 130
        # On mobile, let button size itself based on content
        return base_style

    SEND_BUTTON = {
        "text": "Отправка",
        "icon": ft.Icons.SEND_ROUNDED,
        "style": ft.ButtonStyle(
            color=ft.Colors.WHITE,
            bgcolor=ft.Colors.BLUE_700,
            padding=10,
        ),
        "tooltip": "Отправить сообщение",
        "height": 40,
        "width": 130,
    }

    SAVE_BUTTON = {
        "text": "Сохранить",
        "icon": ft.Icons.SAVE,
        "style": ft.ButtonStyle(
            color=ft.Colors.WHITE,
            bgcolor=ft.Colors.BLUE_700,
            padding=10,
        ),
        "tooltip": "Сохранить диалог в файл",
        "width": 130,
        "height": 40,
    }

    CLEAR_BUTTON = {
        "text": "Очистить",
        "icon": ft.Icons.DELETE,
        "style": ft.ButtonStyle(
            color=ft.Colors.WHITE,
            bgcolor=ft.Colors.RED_700,
            padding=10,
        ),
        "tooltip": "Очистить историю чата",
        "width": 130,
        "height": 40,
    }

    ANALYTICS_BUTTON = {
        "text": "Аналитика",
        "icon": ft.Icons.ANALYTICS,
        "style": ft.ButtonStyle(
            color=ft.Colors.WHITE,
            bgcolor=ft.Colors.GREEN_700,
            padding=10,
        ),
        "tooltip": "Показать аналитику",
        "width": 130,
        "height": 40,
    }

    LOGOUT_BUTTON = {
        "text": "Выйти",
        "icon": ft.Icons.LOGOUT,
        "style": ft.ButtonStyle(
            color=ft.Colors.WHITE,
            bgcolor=ft.Colors.ORANGE_700,
            padding=10,
        ),
        "tooltip": "Выйти из приложения",
        "width": 130,
        "height": 40,
    }

    INPUT_ROW = {
        "spacing": 10,
        "alignment": ft.MainAxisAlignment.SPACE_BETWEEN,
        "width": 920,
    }

    CONTROL_BUTTONS_ROW = {
        "spacing": 20,
        "alignment": ft.MainAxisAlignment.CENTER,
    }

    CONTROLS_COLUMN = {
        "spacing": 20,
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,
    }

    MAIN_COLUMN = {
        "expand": True,
        "spacing": 20,
        "alignment": ft.MainAxisAlignment.CENTER,
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,
    }

    MODEL_SEARCH_FIELD = {
        "width": 400,
        "border_radius": 8,
        "bgcolor": ft.Colors.GREY_900,
        "border_color": ft.Colors.GREY_700,
        "color": ft.Colors.WHITE,
        "content_padding": 10,
        "cursor_color": ft.Colors.WHITE,
        "focused_border_color": ft.Colors.BLUE_400,
        "focused_bgcolor": ft.Colors.GREY_800,
        "hint_style": ft.TextStyle(
            color=ft.Colors.GREY_400,
            size=14,
        ),
        "prefix_icon": ft.Icons.SEARCH,
        "height": 45,
    }

    MODEL_DROPDOWN = {
        "width": 400,
        "height": 45,
        "border_radius": 8,
        "bgcolor": ft.Colors.GREY_900,
        "border_color": ft.Colors.GREY_700,
        "color": ft.Colors.WHITE,
        "content_padding": 10,
        "focused_border_color": ft.Colors.BLUE_400,
        "focused_bgcolor": ft.Colors.GREY_800,
    }

    MODEL_SELECTION_COLUMN = {
        "spacing": 10,
        "horizontal_alignment": ft.CrossAxisAlignment.CENTER,
        "width": 400,
    }

    BALANCE_TEXT = {
        "size": 16,
        "color": ft.Colors.GREEN_400,
        "weight": ft.FontWeight.BOLD,
    }

    BALANCE_CONTAINER = {
        "padding": 10,
        "bgcolor": ft.Colors.GREY_900,
        "border_radius": 8,
        "border": ft.border.all(1, ft.Colors.GREY_700),
    }

    LOGIN_WINDOW = {
        "padding": 30,
        "width": 500,
        "bgcolor": ft.Colors.GREY_900,
        "border_radius": 10,
        "border": ft.border.all(1, ft.Colors.GREY_700),
    }

    API_KEY_INPUT = {
        "label": "API Key",
        "hint_text": "Введите ключ OpenRouter API",
        "password": True,
        "width": 400,
        "bgcolor": ft.Colors.GREY_800,
        "color": ft.Colors.WHITE,
        "border_color": ft.Colors.GREY_700,
        "focused_border_color": ft.Colors.BLUE_400,
        "border_radius": 8,
        "content_padding": 10,
    }

    PIN_INPUT = {
        "label": "PIN",
        "hint_text": "Введите 4-значный PIN",
        "password": True,
        "width": 200,
        "max_length": 4,
        "bgcolor": ft.Colors.GREY_800,
        "color": ft.Colors.WHITE,
        "border_color": ft.Colors.GREY_700,
        "focused_border_color": ft.Colors.BLUE_400,
        "border_radius": 8,
        "content_padding": 10,
    }

    LOGIN_BUTTON = {
        "text": "Войти",
        "icon": ft.Icons.LOGIN,
        "width": 150,
        "style": ft.ButtonStyle(
            color=ft.Colors.WHITE,
            bgcolor=ft.Colors.BLUE_700,
            padding=10,
        ),
    }

    RESET_BUTTON = {
        "text": "Сбросить ключ",
        "icon": ft.Icons.RESTART_ALT,
        "style": ft.ButtonStyle(
            color=ft.Colors.WHITE,
        ),
    }

    @staticmethod
    def set_window_size(page: ft.Page):
        """
        Set window size for the application with platform-specific handling.

        On desktop platforms, configures the application window with fixed dimensions
        and disables resizing. On mobile platforms, window size is managed by the
        operating system and no size constraints are applied.

        Args:
            page (ft.Page): Flet page instance to configure.
        """
        # Only set window size on desktop platforms
        # Mobile platforms manage window size automatically
        if not is_mobile():
            page.window.width = 600
            page.window.height = 800
            page.window.resizable = False

    @staticmethod
    def get_responsive_width(default_width: int) -> int:
        """
        Get responsive width value based on platform.

        Returns the default width for desktop platforms, or None for mobile
        platforms to enable automatic sizing.

        Args:
            default_width (int): Default width value for desktop platforms.

        Returns:
            int or None: Width value for desktop, None for mobile (enables auto-sizing).
        """
        return default_width if not is_mobile() else None

    @staticmethod
    def get_input_row_style() -> dict:
        """
        Get responsive input row style based on platform.

        Returns style dictionary with fixed width for desktop or expand=True
        for mobile platforms.

        Returns:
            dict: Style dictionary for input row.
        """
        base_style = {
            "spacing": 10,
            "alignment": ft.MainAxisAlignment.SPACE_BETWEEN,
        }
        if not is_mobile():
            base_style["width"] = 920
        else:
            base_style["expand"] = True
        return base_style
