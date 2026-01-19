"""
UI components module.

This module provides reusable UI components for the application.
It includes chat message bubbles and model selector dropdown with search functionality.
Adapted for cross-platform compatibility with responsive sizing for mobile platforms.
"""
import asyncio

import flet as ft

from src.ui.styles import AppStyles
from src.utils.platform import is_mobile


class MessageBubble(ft.Container):
    """
    Chat message bubble component.

    A styled container component that displays chat messages with different
    styling and positioning for user and AI messages.

    Attributes:
        padding (int): Internal padding of the bubble.
        border_radius (int): Border radius for rounded corners.
        bgcolor (str): Background color (blue for user, grey for AI).
        alignment (ft.alignment): Text alignment within the bubble.
        margin (ft.margin): External margins for dialog effect.
        content (ft.Column): Column containing the message text.
    """

    def __init__(self, message: str, is_user: bool):
        """
        Initialize message bubble component.

        Args:
            message (str): Message text to display.
            is_user (bool): True if user message, False if AI message.
        """
        super().__init__()

        self.padding = 10
        self.border_radius = 10

        # Blue for user messages, grey for AI messages
        self.bgcolor = ft.Colors.BLUE_700 if is_user else ft.Colors.GREY_700

        # Right alignment for user, left for AI
        # In Flet 0.80+, use ft.Alignment(x, y) where x=-1.0=left, 1.0=right, 0.0=center
        self.alignment = ft.alignment.Alignment(1.0, 0.5) if is_user else ft.alignment.Alignment(-1.0, 0.5)

        # Create dialog effect with asymmetric margins
        self.margin = ft.margin.only(
            left=50 if is_user else 0,
            right=0 if is_user else 50,
            top=5,
            bottom=5
        )

        self.content = ft.Column(
            controls=[
                ft.Text(
                    value=message,
                    color=ft.Colors.WHITE,
                    size=16,
                    selectable=True,
                    weight=ft.FontWeight.W_400
                )
            ],
            tight=True
        )


class ModelSelector(ft.Dropdown):
    """
    Dropdown component for selecting AI models with search functionality.

    Extends ft.Dropdown to provide a custom dropdown with an additional
    search field for filtering available models.

    Attributes:
        options (list): List of dropdown options (filtered).
        all_options (list): Complete list of all available options.
        value (str): Currently selected model ID.
        search_field (ft.TextField): Search field for filtering models.
    """

    def __init__(self, models: list):
        """
        Initialize model selector dropdown.

        Args:
            models (list): List of available models. Each model should be a dict
                with 'id' and 'name' keys.
        """
        super().__init__()

        # Apply styles from configuration with mobile adaptation
        dropdown_style = dict(AppStyles.MODEL_DROPDOWN)
        if is_mobile():
            # Remove fixed width on mobile, let it expand
            dropdown_style.pop('width', None)
        
        for key, value in dropdown_style.items():
            setattr(self, key, value)

        self.label = None
        self.hint_text = "Выбор модели"

        # Create dropdown options from provided models
        self.options = [
            ft.dropdown.Option(
                key=model['id'],
                text=model['name']
            ) for model in models
        ]

        # Store all options for filtering
        self.all_options = self.options.copy()

        # Set initial value to first model
        self.value = models[0]['id'] if models else None

        # Create search field for model filtering with responsive width
        search_field_style = dict(AppStyles.MODEL_SEARCH_FIELD)
        if is_mobile():
            # Remove fixed width on mobile, let it expand
            search_field_style.pop('width', None)
        
        self.search_field = ft.TextField(
            on_change=self.filter_options,
            hint_text="Поиск модели",
            **search_field_style
        )

    def filter_options(self, e):
        """
        Filter model list based on search field input.

        Filters options by matching search text against model name or ID.
        Updates the dropdown options list and refreshes the UI.

        Args:
            e: Change event from the search field.
        """
        search_text = self.search_field.value.lower() if self.search_field.value else ""

        if not search_text:
            # Show all models if search is empty
            self.options = self.all_options
        else:
            # Filter by name or ID
            self.options = [
                opt for opt in self.all_options
                if search_text in opt.text.lower() or search_text in opt.key.lower()
            ]

        # Update UI to reflect filtered list
        e.page.update()
