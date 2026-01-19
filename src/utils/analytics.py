"""
Analytics utility module.

This module provides analytics tracking and statistics collection for the chat
application. It tracks metrics such as model usage, response times, token consumption,
message lengths, and session duration.
"""
import time
from datetime import datetime


class Analytics:
    """
    Application usage analytics tracker.

    Collects and analyzes metrics about chat usage including model statistics,
    response times, token usage, message lengths, and session duration.
    Integrates with ChatCache for persistent storage of analytics data.

    Attributes:
        cache (ChatCache): Cache instance for database operations.
        start_time (float): Session start timestamp.
        model_usage (dict): Statistics per model (count, tokens).
        session_data (list): Detailed message tracking data.
    """

    def __init__(self, cache):
        """
        Initialize analytics system.

        Sets up data structures for tracking metrics and loads historical
        data from the cache.

        Args:
            cache (ChatCache): ChatCache instance for database operations.
        """
        self.cache = cache
        self.start_time = time.time()
        self.model_usage = {}
        self.session_data = []

        # Load historical data from database
        self._load_historical_data()

    def _load_historical_data(self):
        """
        Load historical analytics data from database.

        Updates model usage statistics and session data from cached
        analytics records.
        """
        history = self.cache.get_analytics_history()

        for record in history:
            timestamp, model, message_length, response_time, tokens_used = record

            # Update model statistics
            if model not in self.model_usage:
                self.model_usage[model] = {
                    'count': 0,
                    'tokens': 0
                }
            self.model_usage[model]['count'] += 1
            self.model_usage[model]['tokens'] += tokens_used

            # Add to session data
            self.session_data.append({
                'timestamp': datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S.%f'),
                'model': model,
                'message_length': message_length,
                'response_time': response_time,
                'tokens_used': tokens_used
            })

    def track_message(self, model: str, message_length: int, response_time: float, tokens_used: int):
        """
        Track metrics for a single message.

        Saves detailed message information to database and updates
        overall model usage statistics.

        Args:
            model (str): Model identifier used for the message.
            message_length (int): Message length in characters.
            response_time (float): Response time in seconds.
            tokens_used (int): Number of tokens consumed.
        """
        timestamp = datetime.now()

        # Save to database
        self.cache.save_analytics(timestamp, model, message_length, response_time, tokens_used)

        # Initialize statistics for new model on first use
        if model not in self.model_usage:
            self.model_usage[model] = {
                'count': 0,
                'tokens': 0
            }

        # Update model usage statistics
        self.model_usage[model]['count'] += 1
        self.model_usage[model]['tokens'] += tokens_used

        # Save detailed message information
        self.session_data.append({
            'timestamp': timestamp,
            'model': model,
            'message_length': message_length,
            'response_time': response_time,
            'tokens_used': tokens_used
        })

    def get_statistics(self) -> dict:
        """
        Get aggregated usage statistics.

        Calculates and returns aggregated metrics based on collected
        message data and model usage.

        Returns:
            dict: Dictionary containing various metrics:
                - total_messages (int): Total number of messages
                - total_tokens (int): Total tokens consumed
                - session_duration (float): Session duration in seconds
                - messages_per_minute (float): Average messages per minute
                - tokens_per_message (float): Average tokens per message
                - model_usage (dict): Statistics per model
        """
        total_time = time.time() - self.start_time

        # Calculate total tokens across all models
        total_tokens = sum(model['tokens'] for model in self.model_usage.values())

        # Calculate total messages across all models
        total_messages = sum(model['count'] for model in self.model_usage.values())

        return {
            'total_messages': total_messages,
            'total_tokens': total_tokens,
            'session_duration': total_time,
            # Avoid division by zero for new sessions
            'messages_per_minute': (total_messages * 60) / total_time if total_time > 0 else 0,
            # Avoid division by zero when no messages
            'tokens_per_message': total_tokens / total_messages if total_messages > 0 else 0,
            'model_usage': self.model_usage
        }

    def export_data(self) -> list:
        """
        Export all collected session data.

        Returns:
            list: List of dictionaries containing detailed information about
                each message including timestamps, models used, and metrics.
        """
        return self.session_data

    def clear_data(self):
        """
        Clear all accumulated analytics data.

        Resets all counters and metrics, starting a new session:
        - Clears model usage statistics
        - Clears message history
        - Resets session start time
        """
        self.model_usage.clear()
        self.session_data.clear()
        self.start_time = time.time()
