"""
OpenRouter API client module.

This module provides a client for interacting with the OpenRouter API.
OpenRouter is a service that provides unified access to various language models
(GPT, Claude, etc.) through a single API interface. Adapted for cross-platform
compatibility including mobile platforms with proper .env file handling.
"""
import os

import requests
from dotenv import load_dotenv

from src.utils.logger import AppLogger
from src.utils.platform import is_mobile


def _load_env_file():
    """
    Load environment variables from .env file with cross-platform support.

    Attempts to load .env file from multiple locations:
    - Current working directory (desktop)
    - App data directory (mobile)
    - Project root directory

    Logs warnings if .env file is not found but continues execution.
    """
    logger = AppLogger()
    
    # Determine .env file path based on platform
    env_paths = []
    
    if is_mobile():
        # On mobile, try app data directory first
        try:
            # Try Android app data directory
            android_data = os.environ.get('ANDROID_DATA', '')
            if android_data:
                app_data_dir = os.path.join(
                    android_data,
                    'user',
                    '0',
                    'com.example.aichat',  # Package name placeholder
                    'files'
                )
                env_paths.append(os.path.join(app_data_dir, '.env'))
            
            # Fallback: current directory
            env_paths.append(os.path.join(os.getcwd(), '.env'))
        except Exception:
            # Ultimate fallback: current directory
            env_paths.append(os.path.join(os.getcwd(), '.env'))
    else:
        # Desktop: try current directory and project root
        current_dir = os.getcwd()
        env_paths.append(os.path.join(current_dir, '.env'))
        
        # Try project root (parent of src directory if running from src)
        project_root = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        env_paths.append(os.path.join(project_root, '.env'))
    
    # Try to load .env from determined paths
    env_loaded = False
    for env_path in env_paths:
        if os.path.exists(env_path) and os.path.isfile(env_path):
            try:
                load_dotenv(env_path, override=False)
                env_loaded = True
                break
            except Exception as e:
                logger.warning(f"Failed to load .env from {env_path}: {e}")
    
    # If no .env found, try default load_dotenv() behavior
    if not env_loaded:
        try:
            # This will search in current directory and parent directories
            result = load_dotenv(override=False)
            if result:
                env_loaded = True
        except Exception as e:
            logger.warning(f"Failed to load .env using default search: {e}")
    
    # Log warning if .env file was not found
    if not env_loaded:
        logger.warning(
            ".env file not found. Environment variables should be set manually "
            "or through system environment. Searched paths: " + ", ".join(env_paths)
        )


# Load environment variables from .env file on module import
_load_env_file()


class OpenRouterClient:
    """
    Client for interacting with OpenRouter API.

    OpenRouter provides unified access to various language models (GPT, Claude, etc.)
    through a single API interface. This client handles authentication, model discovery,
    message sending, and account balance retrieval.

    Attributes:
        logger (AppLogger): Logger instance for tracking client operations.
        api_key (str): API key for authentication.
        base_url (str): Base URL for API requests.
        headers (dict): HTTP headers for API requests.
        available_models (list): List of available language models.

    Raises:
        ValueError: If API key is not found in environment variables.
    """

    def __init__(self):
        """
        Initialize OpenRouter client.

        Sets up logging, loads API credentials from environment variables,
        configures HTTP headers, and fetches available models.

        Raises:
            ValueError: If OPENROUTER_API_KEY is not found in environment variables.
        """
        self.logger = AppLogger()

        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.base_url = os.getenv("BASE_URL")

        if not self.api_key:
            self.logger.error("OpenRouter API key not found in .env")
            raise ValueError("OpenRouter API key not found in .env")

        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        # Fetch available models during initialization for immediate availability
        self.available_models = self.get_models()

    def get_models(self):
        """
        Retrieve list of available language models from OpenRouter API.

        Returns:
            list[dict]: List of dictionaries containing model information.
                Each dictionary has keys:
                - id (str): Model identifier for API requests
                - name (str): Human-readable model name

        Note:
            If API request fails, returns a default list of popular models
            to ensure application functionality.
        """
        try:
            response = requests.get(
                f"{self.base_url}/models",
                headers=self.headers
            )
            models_data = response.json()

            return [
                {
                    "id": model["id"],
                    "name": model["name"]
                }
                for model in models_data["data"]
            ]
        except Exception as e:
            # Fallback to default models if API request fails
            models_default = [
                {"id": "deepseek-coder", "name": "DeepSeek"},
                {"id": "claude-3-sonnet", "name": "Claude 3.5 Sonnet"},
                {"id": "gpt-3.5-turbo", "name": "GPT-3.5 Turbo"}
            ]
            return models_default

    def send_message(self, message: str, model: str):
        """
        Send a message to the specified language model.

        Args:
            message (str): Text message to send to the model.
            model (str): Model identifier (e.g., "gpt-3.5-turbo", "claude-3-sonnet").

        Returns:
            dict: API response containing either:
                - Model response with generated content
                - Error information if request failed

        Note:
            The response format follows OpenRouter API specification.
            Errors are caught and returned in a consistent format.
        """
        data = {
            "model": model,
            "messages": [{"role": "user", "content": message}]
        }

        try:
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=self.headers,
                json=data
            )

            response.raise_for_status()

            return response.json()

        except Exception as e:
            error_msg = f"API request failed: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            return {"error": str(e)}

    def get_balance(self):
        """
        Retrieve current account balance from OpenRouter.

        Returns:
            str: Account balance formatted as '$X.XX' or 'Error' if request fails.

        Note:
            Balance is calculated as total credits minus total usage.
            Returns 'Error' string if API request fails or data is invalid.
        """
        try:
            response = requests.get(
                f"{self.base_url}/credits",
                headers=self.headers
            )
            data = response.json()
            if data:
                data = data.get('data')
                # Calculate available balance: total credits minus usage
                return f"${(data.get('total_credits', 0) - data.get('total_usage', 0)):.2f}"
            return "Error"
        except Exception as e:
            error_msg = f"API request failed: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            return "Error"
