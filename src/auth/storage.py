"""
Authentication storage module.

This module provides a high-level interface for managing authentication data
by wrapping ChatCache methods for storing and retrieving API keys and PIN hashes.
"""
from src.utils.cache import ChatCache


class AuthStorage:
    """
    High-level interface for authentication data storage.

    Wraps ChatCache methods to provide a clean API for authentication data
    management including saving, retrieving, verifying, and clearing auth data.

    Attributes:
        cache (ChatCache): Cache instance for database operations.
    """

    def __init__(self, cache: ChatCache):
        """
        Initialize authentication storage.

        Args:
            cache (ChatCache): ChatCache instance for database access.
        """
        self.cache = cache

    def save_auth(self, api_key: str, pin_hash: str) -> bool:
        """
        Save authentication data to database.

        Args:
            api_key (str): OpenRouter API key to store.
            pin_hash (str): Hashed PIN code to store.

        Returns:
            bool: True if saved successfully, False otherwise.
        """
        return self.cache.save_auth_data(api_key, pin_hash)

    def get_auth(self) -> dict:
        """
        Retrieve authentication data from database.

        Returns:
            dict: Dictionary containing 'api_key' and 'pin_hash',
                or None if no auth data exists.
        """
        return self.cache.get_auth_data()

    def check_pin(self, pin: str) -> bool:
        """
        Verify PIN code against stored hash.

        Args:
            pin (str): PIN code to verify.

        Returns:
            bool: True if PIN is valid, False otherwise.
        """
        return self.cache.verify_pin(pin)

    def clear_auth(self) -> bool:
        """
        Clear authentication data from database.

        Returns:
            bool: True if cleared successfully, False otherwise.
        """
        return self.cache.clear_auth_data()

    def has_auth(self) -> bool:
        """
        Check if authentication data exists in database.

        Returns:
            bool: True if auth data exists, False otherwise.
        """
        return self.cache.has_auth_data()
