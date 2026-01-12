"""
Tests for Klaviyo service integration.

These tests verify event tracking, profile synchronization, and error handling.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from uuid import uuid4, UUID

from app.dreamflow.klaviyo_service import KlaviyoService


@pytest.fixture
def mock_klaviyo_client():
    """Create a mock Klaviyo API client."""
    client = MagicMock()
    client.Events = MagicMock()
    client.Profiles = MagicMock()
    return client


@pytest.fixture
def mock_supabase_client():
    """Create a mock Supabase client."""
    client = MagicMock()
    client.table = MagicMock(return_value=client)
    client.select = MagicMock(return_value=client)
    client.eq = MagicMock(return_value=client)
    client.maybe_single = MagicMock(return_value=client)
    client.execute = MagicMock(return_value=MagicMock(data=None))
    return client


@pytest.fixture
def klaviyo_service(mock_supabase_client):
    """Create a KlaviyoService instance with mocked dependencies."""
    with patch("app.dreamflow.klaviyo_service.KlaviyoAPI") as mock_api:
        mock_api.return_value = MagicMock()
        service = KlaviyoService(
            api_key="test_api_key",
            supabase_client=mock_supabase_client,
            enabled=True,
        )
        return service


class TestKlaviyoService:
    """Test suite for KlaviyoService."""

    def test_service_initialization_with_api_key(self, mock_supabase_client):
        """Test service initializes correctly with API key."""
        with patch("app.dreamflow.klaviyo_service.KlaviyoAPI") as mock_api:
            mock_api.return_value = MagicMock()
            service = KlaviyoService(
                api_key="test_key",
                supabase_client=mock_supabase_client,
                enabled=True,
            )
            assert service.enabled is True
            assert service.api_key == "test_key"

    def test_service_disabled_without_api_key(self, mock_supabase_client):
        """Test service is disabled when API key is missing."""
        service = KlaviyoService(
            api_key=None,
            supabase_client=mock_supabase_client,
            enabled=True,
        )
        assert service.enabled is False

    def test_service_disabled_when_explicitly_disabled(self, mock_supabase_client):
        """Test service respects enabled flag."""
        with patch("app.dreamflow.klaviyo_service.KlaviyoAPI") as mock_api:
            mock_api.return_value = MagicMock()
            service = KlaviyoService(
                api_key="test_key",
                supabase_client=mock_supabase_client,
                enabled=False,
            )
            assert service.enabled is False

    def test_track_event_success(self, klaviyo_service):
        """Test successful event tracking."""
        user_id = uuid4()
        klaviyo_service.client.Events.create_event = MagicMock()

        # Mock email retrieval
        with patch.object(klaviyo_service, "_get_user_email", return_value="test@example.com"):
            result = klaviyo_service.track_event(
                event_name="Test Event",
                user_id=user_id,
                properties={"test": "value"},
            )

        assert result is True
        klaviyo_service.client.Events.create_event.assert_called_once()

    def test_track_event_without_email(self, klaviyo_service):
        """Test event tracking fails gracefully when email is unavailable."""
        user_id = uuid4()
        
        # Mock email retrieval to return None
        with patch.object(klaviyo_service, "_get_user_email", return_value=None):
            result = klaviyo_service.track_event(
                event_name="Test Event",
                user_id=user_id,
            )

        assert result is False
        klaviyo_service.client.Events.create_event.assert_not_called()

    def test_track_event_with_provided_email(self, klaviyo_service):
        """Test event tracking with explicitly provided email."""
        user_id = uuid4()
        klaviyo_service.client.Events.create_event = MagicMock()

        result = klaviyo_service.track_event(
            event_name="Test Event",
            user_id=user_id,
            email="provided@example.com",
            properties={"test": "value"},
        )

        assert result is True
        klaviyo_service.client.Events.create_event.assert_called_once()

    def test_track_story_generated(self, klaviyo_service):
        """Test story generation event tracking."""
        user_id = uuid4()
        klaviyo_service.track_event = MagicMock(return_value=True)

        result = klaviyo_service.track_story_generated(
            user_id=user_id,
            theme="Calm Focus",
            story_length=450,
            generation_time_seconds=18.5,
            num_scenes=4,
            user_mood="Sleepy",
        )

        assert result is True
        klaviyo_service.track_event.assert_called_once()
        call_args = klaviyo_service.track_event.call_args
        assert call_args[1]["event_name"] == "Story Generated"
        assert call_args[1]["user_id"] == user_id
        assert call_args[1]["properties"]["theme"] == "Calm Focus"
        assert call_args[1]["properties"]["story_length"] == 450

    def test_track_subscription_created(self, klaviyo_service):
        """Test subscription creation event tracking."""
        user_id = uuid4()
        klaviyo_service.track_event = MagicMock(return_value=True)

        result = klaviyo_service.track_subscription_created(
            user_id=user_id,
            tier="premium",
            previous_tier="free",
            stripe_subscription_id="sub_123",
        )

        assert result is True
        klaviyo_service.track_event.assert_called_once()
        call_args = klaviyo_service.track_event.call_args
        assert call_args[1]["event_name"] == "Subscription Created"
        assert call_args[1]["properties"]["subscription_tier"] == "premium"
        assert call_args[1]["properties"]["previous_tier"] == "free"

    def test_create_or_update_profile_success(self, klaviyo_service):
        """Test successful profile creation/update."""
        user_id = uuid4()
        klaviyo_service.client.Profiles.create_profile = MagicMock()
        
        with patch.object(klaviyo_service, "_get_user_email", return_value="test@example.com"):
            result = klaviyo_service.create_or_update_profile(
                user_id=user_id,
                subscription_tier="premium",
                story_preferences=["animals", "nature"],
                total_stories=42,
                current_streak=7,
            )

        assert result is True
        klaviyo_service.client.Profiles.create_profile.assert_called_once()

    def test_create_or_update_profile_without_email(self, klaviyo_service):
        """Test profile sync fails gracefully when email is unavailable."""
        user_id = uuid4()
        
        with patch.object(klaviyo_service, "_get_user_email", return_value=None):
            result = klaviyo_service.create_or_update_profile(
                user_id=user_id,
                subscription_tier="premium",
            )

        assert result is False
        klaviyo_service.client.Profiles.create_profile.assert_not_called()

    def test_retry_with_backoff_on_failure(self, klaviyo_service):
        """Test retry logic with exponential backoff."""
        user_id = uuid4()
        
        # Mock API to fail twice then succeed
        call_count = 0
        def mock_create_event(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise Exception("API Error")
            return True

        klaviyo_service.client.Events.create_event = MagicMock(side_effect=mock_create_event)
        
        with patch.object(klaviyo_service, "_get_user_email", return_value="test@example.com"):
            with patch("time.sleep"):  # Mock sleep to speed up test
                result = klaviyo_service.track_event(
                    event_name="Test Event",
                    user_id=user_id,
                )

        assert result is True
        assert call_count == 3  # Should have retried 3 times

    def test_retry_exhausted_returns_false(self, klaviyo_service):
        """Test that exhausted retries return False."""
        user_id = uuid4()
        
        # Mock API to always fail
        klaviyo_service.client.Events.create_event = MagicMock(side_effect=Exception("API Error"))
        
        with patch.object(klaviyo_service, "_get_user_email", return_value="test@example.com"):
            with patch("time.sleep"):  # Mock sleep to speed up test
                result = klaviyo_service.track_event(
                    event_name="Test Event",
                    user_id=user_id,
                )

        assert result is False
        assert klaviyo_service.client.Events.create_event.call_count == 3  # Max retries

    def test_sync_subscription_data(self, klaviyo_service):
        """Test subscription data sync."""
        user_id = uuid4()
        klaviyo_service.create_or_update_profile = MagicMock(return_value=True)

        result = klaviyo_service.sync_subscription_data(
            user_id=user_id,
            subscription_tier="premium",
        )

        assert result is True
        klaviyo_service.create_or_update_profile.assert_called_once_with(
            user_id=user_id,
            subscription_tier="premium",
        )

    def test_sync_preferences(self, klaviyo_service):
        """Test preferences sync."""
        user_id = uuid4()
        klaviyo_service.create_or_update_profile = MagicMock(return_value=True)

        result = klaviyo_service.sync_preferences(
            user_id=user_id,
            story_preferences=["animals", "nature"],
        )

        assert result is True
        klaviyo_service.create_or_update_profile.assert_called_once_with(
            user_id=user_id,
            story_preferences=["animals", "nature"],
        )

    def test_service_disabled_does_not_track(self, mock_supabase_client):
        """Test that disabled service does not make API calls."""
        service = KlaviyoService(
            api_key="test_key",
            supabase_client=mock_supabase_client,
            enabled=False,
        )

        result = service.track_event(
            event_name="Test Event",
            user_id=uuid4(),
        )

        assert result is False
        assert service.client is None

    def test_create_list(self, klaviyo_service):
        """Test list creation."""
        klaviyo_service.client.Lists = MagicMock()
        klaviyo_service.client.Lists.create_list = MagicMock(return_value={"data": {"id": "list_123"}})

        result = klaviyo_service.create_list("Test List", "Public Test List")

        assert result == "list_123"
        klaviyo_service.client.Lists.create_list.assert_called_once()

    def test_add_profile_to_list(self, klaviyo_service):
        """Test adding profile to list."""
        user_id = uuid4()
        klaviyo_service.client.Lists.create_list_relationships = MagicMock()
        
        with patch.object(klaviyo_service, "_get_user_email", return_value="test@example.com"):
            result = klaviyo_service.add_profile_to_list("list_123", user_id)

        assert result is True
        klaviyo_service.client.Lists.create_list_relationships.assert_called_once()

    def test_create_segment(self, klaviyo_service):
        """Test segment creation."""
        klaviyo_service.client.Segments = MagicMock()
        klaviyo_service.client.Segments.create_segment = MagicMock(return_value={"data": {"id": "seg_123"}})

        result = klaviyo_service.create_segment(
            "Premium Users",
            {"subscription_tier": "premium"}
        )

        assert result == "seg_123"
        klaviyo_service.client.Segments.create_segment.assert_called_once()

    def test_update_segment(self, klaviyo_service):
        """Test segment update."""
        klaviyo_service.client.Segments.update_segment = MagicMock()

        result = klaviyo_service.update_segment(
            "seg_123",
            {"subscription_tier": "premium"},
            name="Updated Premium Users"
        )

        assert result is True
        klaviyo_service.client.Segments.update_segment.assert_called_once()

    def test_create_campaign(self, klaviyo_service):
        """Test campaign creation."""
        klaviyo_service.client.Campaigns = MagicMock()
        klaviyo_service.client.Campaigns.create_campaign = MagicMock(return_value={"data": {"id": "camp_123"}})

        result = klaviyo_service.create_campaign(
            campaign_name="Test Campaign",
            subject="Test Subject",
            from_email="test@example.com",
            from_name="Test Sender",
            list_ids=["list_123"]
        )

        assert result == "camp_123"
        klaviyo_service.client.Campaigns.create_campaign.assert_called_once()

    def test_send_campaign(self, klaviyo_service):
        """Test campaign sending."""
        klaviyo_service.client.Campaigns.create_campaign_send = MagicMock()

        result = klaviyo_service.send_campaign("camp_123")

        assert result is True
        klaviyo_service.client.Campaigns.create_campaign_send.assert_called_once()

    def test_get_event_metrics(self, klaviyo_service):
        """Test event metrics retrieval."""
        klaviyo_service.client.Metrics = MagicMock()
        klaviyo_service.client.Metrics.get_metrics = MagicMock(return_value={"data": [{"id": "metric_123"}]})
        klaviyo_service.client.Metrics.get_metric_aggregates = MagicMock(return_value={"count": 10})

        result = klaviyo_service.get_event_metrics("Story Generated")

        assert result is not None
        assert result.get("count") == 10

    def test_get_profile_metrics(self, klaviyo_service):
        """Test profile metrics retrieval."""
        user_id = uuid4()
        klaviyo_service.client.Profiles.get_profiles = MagicMock(
            return_value={"data": [{"id": "profile_123"}]}
        )

        with patch.object(klaviyo_service, "_get_user_email", return_value="test@example.com"):
            result = klaviyo_service.get_profile_metrics(user_id)

        assert result is not None
        assert result.get("profile_id") == "profile_123"

    def test_ensure_list_exists_creates_new(self, klaviyo_service):
        """Test ensure_list_exists creates list if it doesn't exist."""
        klaviyo_service.client.Lists.get_lists = MagicMock(return_value={"data": []})
        klaviyo_service.create_list = MagicMock(return_value="list_123")

        result = klaviyo_service.ensure_list_exists("New List")

        assert result == "list_123"
        klaviyo_service.create_list.assert_called_once()

    def test_ensure_list_exists_returns_existing(self, klaviyo_service):
        """Test ensure_list_exists returns existing list."""
        klaviyo_service.client.Lists.get_lists = MagicMock(
            return_value={"data": [{"id": "list_123"}]}
        )

        result = klaviyo_service.ensure_list_exists("Existing List")

        assert result == "list_123"
        klaviyo_service.create_list.assert_not_called()

    def test_auto_manage_user_lists(self, klaviyo_service):
        """Test automatic list management."""
        user_id = uuid4()
        klaviyo_service.ensure_list_exists = MagicMock(return_value="list_123")
        klaviyo_service.add_profile_to_list = MagicMock(return_value=True)
        klaviyo_service.remove_profile_from_list = MagicMock(return_value=True)

        with patch.object(klaviyo_service, "_get_user_email", return_value="test@example.com"):
            result = klaviyo_service.auto_manage_user_lists(
                user_id=user_id,
                subscription_tier="premium",
                family_mode_enabled=False,
            )

        assert result is True
        assert klaviyo_service.ensure_list_exists.call_count >= 2  # At least active and premium lists

