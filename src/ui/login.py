"""
Login window UI component module.

This module provides a login window component for authentication,
supporting both first-time login with API key and PIN-based login.
Adapted for cross-platform compatibility with responsive sizing for mobile platforms.
"""
import flet as ft

from src.utils.platform import is_mobile


class LoginWindow:
    """
    Login window component for authentication.

    Provides UI for entering API key (first-time login) or both PIN code
    and API key (subsequent logins) with buttons for login and reset functionality.
    On subsequent logins, user can authenticate using either PIN or API key.

    Attributes:
        api_key_input (ft.TextField): Input field for API key (always visible).
        pin_input (ft.TextField): Input field for PIN code (visible on subsequent logins).
        status_text (ft.Text): Status/error message display.
        login_button (ft.ElevatedButton): Button to submit login.
        reset_button (ft.TextButton): Button to reset authentication.
    """

    def __init__(self, is_first_login: bool = True):
        """
        Initialize login window component.

        Args:
            is_first_login (bool): If True, shows only API key input.
                If False, shows both PIN and API key inputs. Defaults to True.
        """
        self.is_first_login = is_first_login

        # Create API key input field (always visible)
        # Use responsive width: fixed on desktop, expand on mobile
        api_key_width = None if is_mobile() else 400
        self.api_key_input = ft.TextField(
            label="API Key",
            hint_text="Введите ключ OpenRouter API",
            password=True,
            width=api_key_width,
            expand=is_mobile(),  # Expand on mobile, fixed width on desktop
            visible=True,  # Always visible
        )

        # Create PIN input field (visible when auth data exists)
        # Use responsive width: fixed on desktop, expand on mobile
        pin_width = None if is_mobile() else 200
        self.pin_input = ft.TextField(
            label="PIN",
            hint_text="Введите 4-значный PIN",
            password=True,
            width=pin_width,
            expand=is_mobile(),  # Expand on mobile, fixed width on desktop
            max_length=4,
            visible=not is_first_login,  # Visible when not first login
        )

        # Status/error message display
        self.status_text = ft.Text(
            value="",
            color=ft.Colors.RED_400,
            size=14,
            visible=False,
        )

        # Login button - use responsive width
        # In Flet 0.80+, buttons use content=ft.Text() instead of text=
        login_button_width = None if is_mobile() else 150
        self.login_button = ft.ElevatedButton(
            content=ft.Text("Войти"),
            icon=ft.Icons.LOGIN,
            width=login_button_width,
        )

        # Reset button (only visible on PIN login)
        self.reset_button = ft.TextButton(
            content=ft.Text("Сбросить ключ"),
            icon=ft.Icons.RESTART_ALT,
            visible=not is_first_login,
        )

        # Create main container
        self.container = self._create_container()

    def _create_container(self) -> ft.Container:
        """
        Create main container for login window.

        Returns:
            ft.Container: Container with login form.
        """
        # Determine title and which fields to show
        if self.is_first_login:
            title_text = "Первичная авторизация"
            # Only API key on first login
            input_fields = [self.api_key_input]
            divider_text = None
        else:
            title_text = "Вход в приложение"
            # Both PIN and API key on subsequent logins
            input_fields = [self.pin_input, self.api_key_input]
            divider_text = ft.Text(
                value="Или",
                size=14,
                color=ft.Colors.GREY_500,
                text_align=ft.TextAlign.CENTER,
            )

        controls_list = [
            ft.Text(
                value=title_text,
                size=24,
                weight=ft.FontWeight.BOLD,
                text_align=ft.TextAlign.CENTER,
            ),
            ft.Divider(height=20, color=ft.Colors.TRANSPARENT),
        ]

        # Add input fields
        for i, field in enumerate(input_fields):
            controls_list.append(field)
            # Add "Или" divider between PIN and API key
            if not self.is_first_login and i == 0 and divider_text:
                controls_list.extend([
                    ft.Divider(height=10, color=ft.Colors.TRANSPARENT),
                    divider_text,
                ])
            controls_list.append(ft.Divider(height=10, color=ft.Colors.TRANSPARENT))

        controls_list.extend([
            self.status_text,
            ft.Divider(height=20, color=ft.Colors.TRANSPARENT),
            ft.Row(
                controls=[
                    self.login_button,
                    self.reset_button,
                ],
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=20,
            ),
        ])

        content = ft.Column(
            controls=controls_list,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            spacing=0,
        )

        # Use responsive container width: fixed on desktop, expand on mobile
        container_width = None if is_mobile() else 500
        container_padding = 20 if is_mobile() else 30  # Reduce padding on mobile
        
        return ft.Container(
            content=content,
            padding=container_padding,
            width=container_width,
            expand=is_mobile(),  # Expand on mobile for full-width layout
            bgcolor=ft.Colors.GREY_900,
            border_radius=10,
            border=ft.border.all(1, ft.Colors.GREY_700),
        )

    def show_status(self, message: str, is_error: bool = True):
        """
        Display status or error message.

        Args:
            message (str): Message to display.
            is_error (bool): If True, shows as error (red).
                If False, shows as success (green). Defaults to True.
        """
        self.status_text.value = message
        self.status_text.color = ft.Colors.RED_400 if is_error else ft.Colors.GREEN_400
        self.status_text.visible = True

    def clear_status(self):
        """Clear status message."""
        self.status_text.value = ""
        self.status_text.visible = False

    def get_api_key(self) -> str:
        """
        Get entered API key value.

        Returns:
            str: API key value or empty string.
        """
        return self.api_key_input.value or ""

    def get_pin(self) -> str:
        """
        Get entered PIN value.

        Returns:
            str: PIN value or empty string.
        """
        return self.pin_input.value or ""

    def clear_inputs(self):
        """Clear all input fields."""
        self.api_key_input.value = ""
        self.pin_input.value = ""
        self.clear_status()
