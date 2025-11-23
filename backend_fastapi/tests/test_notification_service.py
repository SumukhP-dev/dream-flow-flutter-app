"""
Unit tests for NotificationService.

Tests ensure:
- Token registration works correctly
- Token retrieval works
- Notification preferences management works
- User queries for notifications work
"""

import pytest
from unittest.mock import MagicMock
from uuid import uuid4, UUID
from datetime import time

from app.notification_service import NotificationService


class TestNotificationService:
    """Tests for NotificationService class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        self.service = NotificationService(self.mock_client)

    def test_register_token(self):
        """Test registering a notification token."""
        user_id = uuid4()
        token_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "token": "fcm_token_123",
            "platform": "android",
        }
        
        mock_response = MagicMock()
        mock_response.data = [token_data]
        self.mock_table.upsert.return_value.execute.return_value = mock_response
        
        result = self.service.register_token(
            user_id=user_id,
            token="fcm_token_123",
            platform="android",
        )
        
        assert result == token_data
        assert self.mock_table.upsert.called

    def test_get_user_tokens(self):
        """Test getting user tokens."""
        user_id = uuid4()
        tokens = [
            {"id": str(uuid4()), "token": "token1", "platform": "android"},
            {"id": str(uuid4()), "token": "token2", "platform": "ios"},
        ]
        
        mock_response = MagicMock()
        mock_response.data = tokens
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_user_tokens(user_id)
        
        assert len(result) == 2

    def test_get_user_tokens_filtered_by_platform(self):
        """Test getting user tokens filtered by platform."""
        user_id = uuid4()
        tokens = [
            {"id": str(uuid4()), "token": "token1", "platform": "android"},
        ]
        
        mock_response = MagicMock()
        mock_response.data = tokens
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_user_tokens(user_id, platform="android")
        
        assert len(result) == 1
        assert result[0]["platform"] == "android"

    def test_delete_token(self):
        """Test deleting a token."""
        user_id = uuid4()
        
        chain = self.mock_table.delete.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.execute.return_value = MagicMock()
        
        self.service.delete_token(user_id, "token_to_delete")
        
        assert self.mock_table.delete.called

    def test_get_notification_preferences(self):
        """Test getting notification preferences."""
        user_id = uuid4()
        preferences = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "bedtime_reminders_enabled": True,
            "streak_notifications_enabled": True,
        }
        
        mock_response = MagicMock()
        mock_response.data = preferences
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_notification_preferences(user_id)
        
        assert result == preferences

    def test_get_notification_preferences_none(self):
        """Test getting preferences when none exist."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = None
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_notification_preferences(user_id)
        
        assert result is None

    def test_update_notification_preferences_new(self):
        """Test updating preferences creates new record."""
        user_id = uuid4()
        
        # No existing preferences
        existing_response = MagicMock()
        existing_response.data = None
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = existing_response
        
        # Mock insert
        insert_response = MagicMock()
        insert_response.data = [{"id": str(uuid4()), "bedtime_reminders_enabled": True}]
        self.mock_table.insert.return_value.execute.return_value = insert_response
        
        result = self.service.update_notification_preferences(
            user_id=user_id,
            bedtime_reminders_enabled=True,
        )
        
        assert result["bedtime_reminders_enabled"] is True
        assert self.mock_table.insert.called

    def test_update_notification_preferences_existing(self):
        """Test updating existing preferences."""
        user_id = uuid4()
        
        # Existing preferences
        existing_data = {"id": str(uuid4()), "bedtime_reminders_enabled": False}
        existing_response = MagicMock()
        existing_response.data = existing_data
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = existing_response
        
        # Mock update
        update_response = MagicMock()
        update_response.data = [{"id": existing_data["id"], "bedtime_reminders_enabled": True}]
        update_chain = self.mock_table.update.return_value
        update_chain.eq.return_value = update_chain
        update_chain.execute.return_value = update_response
        
        result = self.service.update_notification_preferences(
            user_id=user_id,
            bedtime_reminders_enabled=True,
        )
        
        assert result["bedtime_reminders_enabled"] is True
        assert self.mock_table.update.called

    def test_get_users_for_bedtime_reminder(self):
        """Test getting users for bedtime reminder."""
        reminder_time = time(21, 0)  # 9:00 PM
        users = [
            {"id": str(uuid4()), "bedtime_reminder_time": "21:00:00"},
        ]
        
        mock_response = MagicMock()
        mock_response.data = users
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_users_for_bedtime_reminder(reminder_time)
        
        assert len(result) == 1

    def test_get_users_with_active_streaks(self):
        """Test getting users with active streaks."""
        users = [
            {"id": str(uuid4()), "current_streak": 5},
        ]
        
        mock_response = MagicMock()
        mock_response.data = users
        chain = self.mock_table.select.return_value
        chain.select.return_value = chain
        chain.gt.return_value = chain
        chain.eq.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_users_with_active_streaks()
        
        assert len(result) == 1

