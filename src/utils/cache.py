"""
Chat cache utility module.

This module provides SQLite-based caching for chat history and analytics data.
It ensures thread-safe database operations and provides methods for storing,
retrieving, and managing chat messages and analytics records. Adapted for
cross-platform compatibility including mobile platforms with proper database
file path handling.
"""
import hashlib
import os
import sqlite3
import threading
from datetime import datetime

from src.utils.platform import is_mobile


class ChatCache:
    """
    Thread-safe chat history cache using SQLite database.

    Provides persistent storage for chat messages with metadata including
    model information, timestamps, and token usage. Supports analytics
    data storage, formatted history retrieval, and authentication data management.

    Attributes:
        db_path (str): SQLite database file path (platform-specific).
        local (threading.local): Thread-local storage for database connections.
    """

    def __init__(self):
        """
        Initialize chat cache system.

        Creates SQLite database file with platform-specific path handling,
        sets up thread-local connection storage, and creates necessary
        database tables.

        On Android, database is stored in app's internal storage directory.
        On desktop, database is stored in current working directory.
        """
        # Get platform-specific database path
        self.db_path = self._get_database_path()

        # Thread-local storage ensures each thread has its own connection
        self.local = threading.local()

        self.create_tables()

    def _get_database_path(self) -> str:
        """
        Get platform-specific database file path.

        On mobile platforms (Android/iOS), uses app's internal storage.
        On desktop platforms, uses current working directory.

        Returns:
            str: Full path to SQLite database file.
        """
        db_filename = 'chat_cache.db'
        
        if is_mobile():
            # On Android, use app's internal storage
            try:
                # Try to use Android app data directory
                android_data = os.environ.get('ANDROID_DATA', '')
                if android_data:
                    # Use Android app-specific directory
                    app_data_dir = os.path.join(
                        android_data,
                        'user',
                        '0',
                        'com.example.aichat',  # Package name placeholder
                        'files'
                    )
                    # Ensure directory exists
                    os.makedirs(app_data_dir, exist_ok=True)
                    return os.path.join(app_data_dir, db_filename)
                else:
                    # Fallback: use current directory
                    return os.path.join(os.getcwd(), db_filename)
            except Exception:
                # Ultimate fallback: current directory
                return os.path.join(os.getcwd(), db_filename)
        else:
            # Desktop: use current directory
            return os.path.join(os.getcwd(), db_filename)

    def get_connection(self):
        """
        Get database connection for current thread.

        Returns a thread-local database connection, creating one if it doesn't
        exist. This ensures thread-safe database operations.

        Returns:
            sqlite3.Connection: Database connection object for current thread.
        """
        if not hasattr(self.local, 'connection'):
            self.local.connection = sqlite3.connect(self.db_path)
        return self.local.connection

    def create_tables(self):
        """
        Create necessary database tables.

        Creates three tables:
        - messages: stores chat messages with metadata
        - analytics_messages: stores analytics data for performance tracking
        - auth: stores authentication data (API key and PIN hash)
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                model TEXT,
                user_message TEXT,
                ai_response TEXT,
                timestamp DATETIME,
                tokens_used INTEGER
            )
        ''')

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS analytics_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                model TEXT,
                message_length INTEGER,
                response_time FLOAT,
                tokens_used INTEGER
            )
        ''')

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS auth (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                api_key TEXT NOT NULL,
                pin_hash TEXT NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_used DATETIME
            )
        ''')

        conn.commit()
        conn.close()

    def save_message(self, model, user_message, ai_response, tokens_used):
        """
        Save new chat message to database.

        Args:
            model (str): Model identifier used for the message.
            user_message (str): User's message text.
            ai_response (str): AI model's response text.
            tokens_used (int): Number of tokens consumed.
        """
        conn = self.get_connection()
        cursor = conn.cursor()

        cursor.execute('''
            INSERT INTO messages (model, user_message, ai_response, timestamp, tokens_used)
            VALUES (?, ?, ?, ?, ?)
        ''', (model, user_message, ai_response, datetime.now(), tokens_used))
        conn.commit()

    def get_chat_history(self, limit=50):
        """
        Retrieve recent chat messages from database.

        Args:
            limit (int, optional): Maximum number of messages to return.
                Defaults to 50.

        Returns:
            list: List of tuples containing message data, sorted by timestamp
                in descending order (newest first).
        """
        conn = self.get_connection()
        cursor = conn.cursor()

        cursor.execute('''
            SELECT * FROM messages
            ORDER BY timestamp DESC
            LIMIT ?
        ''', (limit,))
        return cursor.fetchall()

    def save_analytics(self, timestamp, model, message_length, response_time, tokens_used):
        """
        Save analytics data to database.

        Args:
            timestamp (datetime): Timestamp of the record.
            model (str): Model identifier used.
            message_length (int): Length of the message.
            response_time (float): Response time in seconds.
            tokens_used (int): Number of tokens consumed.
        """
        conn = self.get_connection()
        cursor = conn.cursor()

        cursor.execute('''
            INSERT INTO analytics_messages
            (timestamp, model, message_length, response_time, tokens_used)
            VALUES (?, ?, ?, ?, ?)
        ''', (timestamp, model, message_length, response_time, tokens_used))
        conn.commit()

    def get_analytics_history(self):
        """
        Retrieve all analytics history from database.

        Returns:
            list: List of tuples containing analytics records, sorted by
                timestamp in ascending order.
        """
        conn = self.get_connection()
        cursor = conn.cursor()

        cursor.execute('''
            SELECT timestamp, model, message_length, response_time, tokens_used
            FROM analytics_messages
            ORDER BY timestamp ASC
        ''')
        return cursor.fetchall()

    def __del__(self):
        """
        Cleanup database connections on object destruction.

        Closes thread-local database connection to prevent resource leaks.
        """
        if hasattr(self.local, 'connection'):
            self.local.connection.close()

    def clear_history(self):
        """
        Clear all chat history from database.

        Deletes all records from the messages table, effectively
        clearing the entire chat history.
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM messages')
        conn.commit()

    def get_formatted_history(self):
        """
        Retrieve formatted chat history as list of dictionaries.

        Returns:
            list[dict]: List of dictionaries containing message data with keys:
                - id (int): Message identifier
                - model (str): Model identifier used
                - user_message (str): User's message text
                - ai_response (str): AI model's response text
                - timestamp (datetime): Message timestamp
                - tokens_used (int): Number of tokens consumed

        Messages are sorted by timestamp in ascending order (oldest first).
        """
        conn = self.get_connection()
        cursor = conn.cursor()

        cursor.execute('''
            SELECT
                id,
                model,
                user_message,
                ai_response,
                timestamp,
                tokens_used
            FROM messages
            ORDER BY timestamp ASC
        ''')

        history = []
        for row in cursor.fetchall():
            history.append({
                "id": row[0],
                "model": row[1],
                "user_message": row[2],
                "ai_response": row[3],
                "timestamp": row[4],
                "tokens_used": row[5]
            })
        return history

    def save_auth_data(self, api_key: str, pin_hash: str) -> bool:
        """
        Save authentication data to database.

        If auth data already exists, it will be updated (replaced).
        Otherwise, a new record will be created.

        Args:
            api_key (str): OpenRouter API key to store.
            pin_hash (str): Hashed PIN code to store.

        Returns:
            bool: True if saved successfully, False otherwise.
        """
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            # Check if auth data already exists
            cursor.execute('SELECT id FROM auth LIMIT 1')
            existing = cursor.fetchone()

            if existing:
                # Update existing record
                cursor.execute('''
                    UPDATE auth 
                    SET api_key = ?, pin_hash = ?, last_used = ?
                    WHERE id = ?
                ''', (api_key, pin_hash, datetime.now(), existing[0]))
            else:
                # Insert new record
                cursor.execute('''
                    INSERT INTO auth (api_key, pin_hash, created_at, last_used)
                    VALUES (?, ?, ?, ?)
                ''', (api_key, pin_hash, datetime.now(), datetime.now()))

            conn.commit()
            return True
        except Exception:
            return False

    def get_auth_data(self) -> dict:
        """
        Retrieve authentication data from database.

        Returns:
            dict: Dictionary containing 'api_key' and 'pin_hash',
                or None if no auth data exists.
        """
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            cursor.execute('''
                SELECT api_key, pin_hash, created_at, last_used
                FROM auth
                LIMIT 1
            ''')

            row = cursor.fetchone()
            if row:
                # Update last_used timestamp
                cursor.execute('UPDATE auth SET last_used = ?', (datetime.now(),))
                conn.commit()

                return {
                    'api_key': row[0],
                    'pin_hash': row[1],
                    'created_at': row[2],
                    'last_used': row[3]
                }
            return None
        except Exception:
            return None

    def verify_pin(self, pin: str) -> bool:
        """
        Verify PIN code against stored hash.

        Args:
            pin (str): PIN code to verify.

        Returns:
            bool: True if PIN is valid, False otherwise.
        """
        try:
            auth_data = self.get_auth_data()
            if not auth_data or 'pin_hash' not in auth_data:
                return False

            stored_hash = auth_data['pin_hash']
            input_hash = hashlib.sha256(pin.encode()).hexdigest()

            return input_hash == stored_hash
        except Exception:
            return False

    def clear_auth_data(self) -> bool:
        """
        Clear authentication data from database.

        Deletes all records from the auth table.

        Returns:
            bool: True if cleared successfully, False otherwise.
        """
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            cursor.execute('DELETE FROM auth')
            conn.commit()
            return True
        except Exception:
            return False

    def has_auth_data(self) -> bool:
        """
        Check if authentication data exists in database.

        Returns:
            bool: True if auth data exists, False otherwise.
        """
        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            cursor.execute('SELECT COUNT(*) FROM auth')
            count = cursor.fetchone()[0]

            return count > 0
        except Exception:
            return False
