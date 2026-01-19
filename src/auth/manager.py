"""
Authentication manager module.

This module coordinates authentication flow including first-time login,
PIN-based login, and authentication reset functionality.
"""
from src.auth.storage import AuthStorage
from src.auth.validator import AuthValidator


class AuthManager:
    """
    Authentication flow manager.

    Coordinates authentication processes including API key validation,
    PIN generation, login verification, and authentication state management.

    Attributes:
        storage (AuthStorage): Storage handler for auth data.
        validator (AuthValidator): Validator for credentials.
    """

    def __init__(self, storage: AuthStorage, base_url: str = None):
        """
        Initialize authentication manager.

        Args:
            storage (AuthStorage): AuthStorage instance for data persistence.
            base_url (str, optional): Base URL for API validation.
                Defaults to None (uses AuthValidator default).
        """
        self.storage = storage
        self.validator = AuthValidator(base_url=base_url)

    def handle_first_login(self, api_key: str) -> tuple[bool, str, str]:
        """
        Handle first-time login with API key validation.

        Validates API key, checks balance, generates PIN, and saves
        authentication data to database.

        Args:
            api_key (str): OpenRouter API key to validate and store.

        Returns:
            tuple[bool, str, str]: Tuple containing:
                - bool: True if login successful, False otherwise
                - str: Generated PIN code (if successful) or error message
                - str: Balance string or empty string
        """
        # Validate API key
        is_valid, balance_msg, balance_value = self.validator.validate_api_key(api_key)

        if not is_valid:
            return (False, balance_msg, "")

        # Check if balance is positive
        if balance_value <= 0:
            return (False, "API key has no available balance", "")

        # Generate PIN
        pin = self.validator.generate_pin()
        pin_hash = self.validator.hash_pin(pin)

        # Save authentication data
        if self.storage.save_auth(api_key, pin_hash):
            return (True, pin, balance_msg)

        return (False, "Failed to save authentication data", "")

    def handle_pin_login(self, pin: str) -> tuple[bool, str, str]:
        """
        Handle login using PIN code.

        Verifies PIN and retrieves stored API key.

        Args:
            pin (str): PIN code to verify.

        Returns:
            tuple[bool, str, str]: Tuple containing:
                - bool: True if PIN is valid, False otherwise
                - str: API key (if valid) or error message
                - str: Empty string (placeholder for consistency)
        """
        if not pin or len(pin) != 4 or not pin.isdigit():
            return (False, "PIN must be 4 digits", "")

        # Check PIN
        if not self.storage.check_pin(pin):
            return (False, "Invalid PIN", "")

        # Get API key
        auth_data = self.storage.get_auth()
        if auth_data and 'api_key' in auth_data:
            return (True, auth_data['api_key'], "")

        return (False, "Authentication data not found", "")

    def handle_api_key_login(self, api_key: str) -> tuple[bool, str, str]:
        """
        Handle login using API key (can be used even if auth data exists).

        Validates API key, checks balance, and updates stored credentials
        if authentication data already exists.

        Args:
            api_key (str): OpenRouter API key to validate.

        Returns:
            tuple[bool, str, str]: Tuple containing:
                - bool: True if login successful, False otherwise
                - str: Success message or error message
                - str: Balance string or empty string
        """
        # Validate API key
        is_valid, balance_msg, balance_value = self.validator.validate_api_key(api_key)

        if not is_valid:
            return (False, balance_msg, "")

        # Check if balance is positive
        if balance_value <= 0:
            return (False, "API key has no available balance", "")

        # Check if auth data already exists
        has_existing = self.storage.has_auth()

        if has_existing:
            # Update existing auth data with new API key
            # Keep existing PIN hash or generate new PIN
            auth_data = self.storage.get_auth()
            if auth_data and 'pin_hash' in auth_data:
                # Keep existing PIN
                pin_hash = auth_data['pin_hash']
            else:
                # Generate new PIN if somehow missing
                pin = self.validator.generate_pin()
                pin_hash = self.validator.hash_pin(pin)
        else:
            # Generate new PIN for first-time setup
            pin = self.validator.generate_pin()
            pin_hash = self.validator.hash_pin(pin)

        # Save or update authentication data
        if self.storage.save_auth(api_key, pin_hash):
            if has_existing:
                return (True, "API key updated successfully", balance_msg)
            else:
                # Return generated PIN for first-time setup
                return (True, pin, balance_msg)

        return (False, "Failed to save authentication data", "")

    def handle_reset(self) -> bool:
        """
        Reset authentication by clearing stored data.

        Returns:
            bool: True if reset successful, False otherwise.
        """
        return self.storage.clear_auth()

    def is_authenticated(self) -> bool:
        """
        Check if user is currently authenticated.

        Returns:
            bool: True if authentication data exists, False otherwise.
        """
        return self.storage.has_auth()

    def get_stored_api_key(self) -> str:
        """
        Get stored API key without PIN verification.

        This method is useful for cases where API key is needed
        but PIN verification has already been done.

        Returns:
            str: Stored API key or empty string if not found.
        """
        auth_data = self.storage.get_auth()
        if auth_data and 'api_key' in auth_data:
            return auth_data['api_key']
        return ""
