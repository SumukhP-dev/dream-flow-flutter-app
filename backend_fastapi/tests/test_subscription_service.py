"""
Unit tests for SubscriptionService.

Tests ensure:
- Subscription tier detection works correctly
- Quota checking and enforcement works
- Usage tracking increments correctly
- Subscription creation/update/cancellation works
"""

import pytest
from unittest.mock import MagicMock, patch
from uuid import uuid4, UUID
from datetime import datetime, timedelta

from app.subscription_service import SubscriptionService


class TestSubscriptionService:
    """Tests for SubscriptionService class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        self.service = SubscriptionService(self.mock_client)

    def test_get_user_subscription_active(self):
        """Test getting active subscription."""
        user_id = uuid4()
        subscription_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "tier": "premium",
            "status": "active",
            "current_period_end": (datetime.utcnow() + timedelta(days=30)).isoformat(),
        }
        
        mock_response = MagicMock()
        mock_response.data = subscription_data
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.gte.return_value = chain
        chain.order.return_value = chain
        chain.limit.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_user_subscription(user_id)
        
        assert result == subscription_data

    def test_get_user_subscription_none(self):
        """Test getting subscription when user has none."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = None
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.gte.return_value = chain
        chain.order.return_value = chain
        chain.limit.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.service.get_user_subscription(user_id)
        
        assert result is None

    def test_get_user_tier_free(self):
        """Test getting free tier for user without subscription."""
        user_id = uuid4()
        
        with patch.object(self.service, 'get_user_subscription', return_value=None):
            tier = self.service.get_user_tier(user_id)
        
        assert tier == "free"

    def test_get_user_tier_premium(self):
        """Test getting premium tier."""
        user_id = uuid4()
        subscription = {"tier": "premium"}
        
        with patch.object(self.service, 'get_user_subscription', return_value=subscription):
            tier = self.service.get_user_tier(user_id)
        
        assert tier == "premium"

    def test_get_user_quota_free(self):
        """Test quota for free tier."""
        user_id = uuid4()
        
        with patch.object(self.service, 'get_user_tier', return_value="free"):
            quota = self.service.get_user_quota(user_id)
        
        assert quota == 3

    def test_get_user_quota_premium(self):
        """Test quota for premium tier."""
        user_id = uuid4()
        
        with patch.object(self.service, 'get_user_tier', return_value="premium"):
            quota = self.service.get_user_quota(user_id)
        
        assert quota == 999999

    def test_get_user_story_count_weekly(self):
        """Test getting weekly story count."""
        user_id = uuid4()
        usage_data = {
            "story_count": 2,
        }
        
        mock_response = MagicMock()
        mock_response.data = usage_data
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        count = self.service.get_user_story_count(user_id, "weekly")
        
        assert count == 2

    def test_get_user_story_count_none(self):
        """Test getting story count when no usage record exists."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = None
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        count = self.service.get_user_story_count(user_id, "weekly")
        
        assert count == 0

    def test_can_generate_story_premium(self):
        """Test premium user can always generate."""
        user_id = uuid4()
        
        with patch.object(self.service, 'get_user_tier', return_value="premium"):
            can_generate, error = self.service.can_generate_story(user_id)
        
        assert can_generate is True
        assert error is None

    def test_can_generate_story_free_within_quota(self):
        """Test free user within quota can generate."""
        user_id = uuid4()
        
        with patch.object(self.service, 'get_user_tier', return_value="free"):
            with patch.object(self.service, 'get_user_quota', return_value=3):
                with patch.object(self.service, 'get_user_story_count', return_value=2):
                    can_generate, error = self.service.can_generate_story(user_id)
        
        assert can_generate is True
        assert error is None

    def test_can_generate_story_free_over_quota(self):
        """Test free user over quota cannot generate."""
        user_id = uuid4()
        
        with patch.object(self.service, 'get_user_tier', return_value="free"):
            with patch.object(self.service, 'get_user_quota', return_value=3):
                with patch.object(self.service, 'get_user_story_count', return_value=3):
                    can_generate, error = self.service.can_generate_story(user_id)
        
        assert can_generate is False
        assert "weekly limit" in error.lower()

    def test_increment_story_count_new_record(self):
        """Test incrementing story count creates new record."""
        user_id = uuid4()
        
        # No existing record
        mock_response = MagicMock()
        mock_response.data = None
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        # Mock insert
        insert_response = MagicMock()
        insert_response.data = [{"story_count": 1}]
        self.mock_table.insert.return_value.execute.return_value = insert_response
        
        count = self.service.increment_story_count(user_id, "weekly")
        
        assert count == 1
        assert self.mock_table.insert.called

    def test_increment_story_count_existing_record(self):
        """Test incrementing story count updates existing record."""
        user_id = uuid4()
        
        # Existing record
        existing_data = {
            "id": str(uuid4()),
            "story_count": 2,
        }
        mock_response = MagicMock()
        mock_response.data = existing_data
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = mock_response
        
        # Mock update
        update_response = MagicMock()
        update_response.data = [{"story_count": 3}]
        update_chain = self.mock_table.update.return_value
        update_chain.eq.return_value = update_chain
        update_chain.execute.return_value = update_response
        
        count = self.service.increment_story_count(user_id, "weekly")
        
        assert count == 3
        assert self.mock_table.update.called

    def test_create_or_update_subscription_new(self):
        """Test creating new subscription."""
        user_id = uuid4()
        
        # No existing subscription
        existing_response = MagicMock()
        existing_response.data = None
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = existing_response
        
        # Mock insert
        insert_response = MagicMock()
        insert_response.data = [{"id": str(uuid4()), "tier": "premium"}]
        self.mock_table.insert.return_value.execute.return_value = insert_response
        
        result = self.service.create_or_update_subscription(
            user_id=user_id,
            tier="premium",
            stripe_subscription_id="sub_123",
        )
        
        assert result["tier"] == "premium"
        assert self.mock_table.insert.called

    def test_create_or_update_subscription_existing(self):
        """Test updating existing subscription."""
        user_id = uuid4()
        
        # Existing subscription
        existing_data = {"id": str(uuid4()), "tier": "free"}
        existing_response = MagicMock()
        existing_response.data = existing_data
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.maybe_single.return_value = chain
        chain.execute.return_value = existing_response
        
        # Mock update
        update_response = MagicMock()
        update_response.data = [{"id": existing_data["id"], "tier": "premium"}]
        update_chain = self.mock_table.update.return_value
        update_chain.eq.return_value = update_chain
        update_chain.execute.return_value = update_response
        
        result = self.service.create_or_update_subscription(
            user_id=user_id,
            tier="premium",
        )
        
        assert result["tier"] == "premium"
        assert self.mock_table.update.called

    def test_cancel_subscription(self):
        """Test canceling subscription."""
        user_id = uuid4()
        
        update_response = MagicMock()
        update_response.data = [{"id": str(uuid4()), "status": "cancelled"}]
        update_chain = self.mock_table.update.return_value
        update_chain.eq.return_value = update_chain
        update_chain.execute.return_value = update_response
        
        result = self.service.cancel_subscription(user_id, cancel_at_period_end=False)
        
        assert result["status"] == "cancelled"
        assert self.mock_table.update.called

