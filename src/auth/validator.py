"""
Authentication validator module.

This module provides validation logic for API keys and PIN codes,
including API key verification through balance check and PIN generation.
"""
import hashlib
import random

import requests


class AuthValidator:
    """
    Validator for authentication credentials.

    Provides methods for validating API keys, generating PINs,
    and hashing/verifying PIN codes.

    Attributes:
        base_url (str): Base URL for OpenRouter API.
    """

    def __init__(self, base_url: str = None):
        """
        Initialize authentication validator.

        Args:
            base_url (str, optional): Base URL for API. 
                Defaults to "https://openrouter.ai/api/v1".
        """
        self.base_url = base_url or "https://openrouter.ai/api/v1"

    def validate_api_key(self, api_key: str) -> tuple[bool, str, float]:
        """
        Validate OpenRouter API key by checking account balance.

        Makes a request to OpenRouter API to verify the key is valid
        and retrieves the account balance.

        Args:
            api_key (str): OpenRouter API key to validate.

        Returns:
            tuple[bool, str, float]: Tuple containing:
                - bool: True if key is valid and has balance, False otherwise
                - str: Balance as formatted string or error message
                - float: Balance as float value or 0.0
        """
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

        try:
            response = requests.get(
                f"{self.base_url}/credits",
                headers=headers,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                if data and 'data' in data:
                    data = data['data']
                    balance = data.get('total_credits', 0) - data.get('total_usage', 0)
                    balance_str = f"${balance:.2f}"
                    return (True, balance_str, balance)

            return (False, "Invalid API key or insufficient permissions", 0.0)

        except Exception as e:
            return (False, f"Error validating key: {str(e)}", 0.0)

    def generate_pin(self) -> str:
        """
        Generate a random 4-digit PIN code.

        Returns:
            str: 4-digit PIN code as string (1000-9999).
        """
        return f"{random.randint(1000, 9999)}"

    def hash_pin(self, pin: str) -> str:
        """
        Hash PIN code using SHA-256.

        Args:
            pin (str): PIN code to hash.

        Returns:
            str: Hexadecimal hash of the PIN.
        """
        return hashlib.sha256(pin.encode()).hexdigest()

    def verify_pin(self, input_pin: str, stored_hash: str) -> bool:
        """
        Verify PIN against stored hash.

        Args:
            input_pin (str): PIN code to verify.
            stored_hash (str): Stored hash to compare against.

        Returns:
            bool: True if PIN matches hash, False otherwise.
        """
        input_hash = self.hash_pin(input_pin)
        return input_hash == stored_hash
