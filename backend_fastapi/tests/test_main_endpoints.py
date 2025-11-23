"""
Integration tests for additional main.py endpoints.

Tests ensure:
- /api/v1/history endpoint works correctly
- /api/v1/feedback endpoint works correctly
- Admin moderation endpoints work correctly
- Admin purge assets endpoint works correctly
"""

import pytest
from unittest.mock import MagicMock, patch, AsyncMock
from uuid import uuid4, UUID
from datetime import datetime
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.schemas import FeedbackRequest


@pytest.fixture
def mock_settings():
    """Create mock settings for testing."""
    settings = MagicMock(spec=Settings)
    settings.app_name = "Dream Flow API"
    settings.hf_token = "test_token"
    settings.story_model = "test/story-model"
    settings.tts_model = "test/tts-model"
    settings.image_model = "test/image-model"
    settings.max_new_tokens = 500
    settings.supabase_url = "https://test.supabase.co"
    settings.supabase_service_role_key = "test_key"
    settings.supabase_anon_key = "test_anon_key"
    settings.admin_user_ids = []
    settings.sentry_dsn = None
    settings.sentry_environment = "test"
    settings.sentry_traces_sample_rate = 0.0
    settings.asset_retention_days = 7
    return settings


@pytest.fixture
def mock_supabase_client():
    """Create mock Supabase client."""
    client = MagicMock()
    return client


@pytest.fixture
def test_client(mock_settings, mock_supabase_client):
    """Create test client with mocked dependencies."""
    # Mock subscription service to avoid quota checks
    mock_subscription_service = MagicMock()
    mock_subscription_service.can_generate_story.return_value = (True, None)
    mock_subscription_service.get_user_tier.return_value = "free"
    mock_subscription_service.get_user_quota.return_value = 3
    mock_subscription_service.get_user_story_count.return_value = 0
    
    # Mock client attribute for subscription service
    mock_supabase_client.client = MagicMock()
    
    with patch('app.main.get_settings', new=lambda: mock_settings):
        with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
            with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                with patch('app.main.NotificationService', return_value=MagicMock()):
                    with patch('app.main.RecommendationEngine', return_value=MagicMock()):
                        app = create_app(mock_settings)
                        return TestClient(app)


def create_mock_jwt_token(user_id: UUID) -> str:
    """Create a mock JWT token for testing."""
    import base64
    import json
    import time
    
    payload = {
        "sub": str(user_id),
        "exp": int(time.time()) + 3600,
    }
    
    payload_json = json.dumps(payload)
    payload_b64 = base64.urlsafe_b64encode(payload_json.encode()).decode().rstrip('=')
    
    return f"header.{payload_b64}.signature"


class TestHistoryEndpoint:
    """Tests for GET /api/v1/history endpoint."""

    def test_get_history_success(self, test_client, mock_supabase_client):
        """Test successful retrieval of session history."""
        user_id = uuid4()
        session_id = uuid4()
        
        mock_sessions = [
            {
                "id": str(session_id),
                "theme": "ocean",
                "prompt": "A peaceful journey",
                "created_at": "2024-01-01T10:00:00Z",
            }
        ]
        
        mock_assets = [
            {
                "id": str(uuid4()),
                "asset_type": "frame",
                "asset_url": "https://supabase.co/storage/frames/thumb.png",
                "display_order": 0,
            }
        ]
        
        mock_supabase_client.get_user_sessions.return_value = mock_sessions
        mock_supabase_client.get_session_assets.return_value = mock_assets
        
        response = test_client.get(f"/api/v1/history?user_id={user_id}&limit=10")
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["sessions"]) == 1
        assert data["sessions"][0]["session_id"] == str(session_id)
        assert data["sessions"][0]["thumbnail_url"] == "https://supabase.co/storage/frames/thumb.png"

    def test_get_history_no_supabase(self, mock_settings):
        """Test history endpoint when Supabase is not configured."""
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', side_effect=ValueError("Not configured")):
                app = create_app(mock_settings)
                client = TestClient(app)
                
                response = client.get(f"/api/v1/history?user_id={uuid4()}&limit=10")
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["sessions"]) == 0

    def test_get_history_no_thumbnail(self, test_client, mock_supabase_client):
        """Test history endpoint when session has no frames."""
        user_id = uuid4()
        session_id = uuid4()
        
        mock_sessions = [
            {
                "id": str(session_id),
                "theme": "ocean",
                "prompt": "A peaceful journey",
                "created_at": "2024-01-01T10:00:00Z",
            }
        ]
        
        mock_supabase_client.get_user_sessions.return_value = mock_sessions
        mock_supabase_client.get_session_assets.return_value = []
        
        response = test_client.get(f"/api/v1/history?user_id={user_id}&limit=10")
        
        assert response.status_code == 200
        data = response.json()
        assert data["sessions"][0]["thumbnail_url"] is None


class TestFeedbackEndpoint:
    """Tests for POST /api/v1/feedback endpoint."""

    def test_submit_feedback_success(self, test_client, mock_supabase_client):
        """Test successful feedback submission."""
        user_id = uuid4()
        session_id = uuid4()
        
        # Mock session exists and belongs to user
        mock_session = {
            "id": str(session_id),
            "user_id": str(user_id),
            "theme": "ocean",
        }
        mock_supabase_client.get_session.return_value = mock_session
        
        # Mock feedback creation
        feedback_data = {
            "id": str(uuid4()),
            "session_id": str(session_id),
            "user_id": str(user_id),
            "rating": 5,
            "mood_delta": 2,
            "created_at": "2024-01-01T10:00:00Z",
        }
        mock_supabase_client.create_feedback.return_value = feedback_data
        
        token = create_mock_jwt_token(user_id)
        payload = FeedbackRequest(
            session_id=session_id,
            rating=5,
            mood_delta=2,
        )
        
        response = test_client.post(
            "/api/v1/feedback",
            json=payload.model_dump(mode='json'),
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["rating"] == 5
        assert data["mood_delta"] == 2

    def test_submit_feedback_no_auth(self, test_client):
        """Test feedback submission without auth returns 401."""
        payload = FeedbackRequest(
            session_id=uuid4(),
            rating=5,
            mood_delta=2,
        )
        
        response = test_client.post(
            "/api/v1/feedback",
            json=payload.model_dump(mode='json')
        )
        
        assert response.status_code == 401

    def test_submit_feedback_session_not_found(self, test_client, mock_supabase_client):
        """Test feedback submission for non-existent session."""
        user_id = uuid4()
        session_id = uuid4()
        
        mock_supabase_client.get_session.return_value = None
        
        token = create_mock_jwt_token(user_id)
        payload = FeedbackRequest(
            session_id=session_id,
            rating=5,
            mood_delta=2,
        )
        
        response = test_client.post(
            "/api/v1/feedback",
            json=payload.model_dump(mode='json'),
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 404

    def test_submit_feedback_wrong_user(self, test_client, mock_supabase_client):
        """Test feedback submission for another user's session."""
        user_id = uuid4()
        other_user_id = uuid4()
        session_id = uuid4()
        
        # Session belongs to other user
        mock_session = {
            "id": str(session_id),
            "user_id": str(other_user_id),
        }
        mock_supabase_client.get_session.return_value = mock_session
        
        token = create_mock_jwt_token(user_id)
        payload = FeedbackRequest(
            session_id=session_id,
            rating=5,
            mood_delta=2,
        )
        
        response = test_client.post(
            "/api/v1/feedback",
            json=payload.model_dump(mode='json'),
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 403

    def test_submit_feedback_no_supabase(self, mock_settings):
        """Test feedback endpoint when Supabase is not configured."""
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', side_effect=ValueError("Not configured")):
                app = create_app(mock_settings)
                client = TestClient(app)
                
                user_id = uuid4()
                token = create_mock_jwt_token(user_id)
                payload = FeedbackRequest(
                    session_id=uuid4(),
                    rating=5,
                    mood_delta=2,
                )
                
                response = client.post(
                    "/api/v1/feedback",
                    json=payload.model_dump(mode='json'),
                    headers={"Authorization": f"Bearer {token}"}
                )
        
        assert response.status_code == 503


class TestAdminModerationEndpoints:
    """Tests for admin moderation queue endpoints."""

    def test_list_moderation_queue(self, mock_supabase_client, mock_settings):
        """Test listing moderation queue items."""
        admin_user_id = uuid4()
        mock_settings.admin_user_ids = [str(admin_user_id)]
        
        items = [
            {
                "id": str(uuid4()),
                "status": "pending",
                "violations": [{"category": "safety", "detail": "Test"}],
                "content": "Test content",
                "content_type": "story",
                "created_at": "2024-01-01T10:00:00Z",
                "updated_at": "2024-01-01T10:00:00Z",
            }
        ]
        
        mock_supabase_client.get_moderation_items.return_value = items
        
        # Clear cache and patch get_settings
        from app.config import get_settings
        from app.auth import get_admin_user_id
        get_settings.cache_clear()
        
        # Create test client with admin settings
        with patch('app.config.get_settings', return_value=mock_settings):
            with patch('app.main.get_settings', return_value=mock_settings):
                with patch('app.auth.get_settings', return_value=mock_settings):
                    with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                        from app.main import create_app
                        app = create_app(mock_settings)
                        # Override dependencies
                        app.dependency_overrides[get_settings] = lambda: mock_settings
                        app.dependency_overrides[get_admin_user_id] = lambda: admin_user_id
                        client = TestClient(app)
                        
                        token = create_mock_jwt_token(admin_user_id)
                        
                        response = client.get(
                            "/api/v1/admin/moderation?limit=20&offset=0",
                            headers={"Authorization": f"Bearer {token}"}
                        )
                        
                        # Clean up
                        app.dependency_overrides.clear()
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 1

    def test_get_moderation_item(self, mock_supabase_client, mock_settings):
        """Test getting a single moderation item."""
        admin_user_id = uuid4()
        item_id = uuid4()
        mock_settings.admin_user_ids = [str(admin_user_id)]
        
        item = {
            "id": str(item_id),
            "status": "pending",
            "violations": [{"category": "safety", "detail": "Test"}],
            "content": "Test content",
            "content_type": "story",
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-01T10:00:00Z",
        }
        
        mock_supabase_client.get_moderation_item.return_value = item
        
        from app.config import get_settings
        from app.auth import get_admin_user_id
        get_settings.cache_clear()
        
        with patch('app.config.get_settings', return_value=mock_settings):
            with patch('app.main.get_settings', return_value=mock_settings):
                with patch('app.auth.get_settings', return_value=mock_settings):
                    with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                        from app.main import create_app
                        app = create_app(mock_settings)
                        app.dependency_overrides[get_settings] = lambda: mock_settings
                        app.dependency_overrides[get_admin_user_id] = lambda: admin_user_id
                        client = TestClient(app)
                        
                        token = create_mock_jwt_token(admin_user_id)
                        
                        response = client.get(
                            f"/api/v1/admin/moderation/{item_id}",
                            headers={"Authorization": f"Bearer {token}"}
                        )
                        
                        app.dependency_overrides.clear()
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(item_id)

    def test_resolve_moderation_item(self, mock_supabase_client, mock_settings):
        """Test resolving a moderation item."""
        admin_user_id = uuid4()
        item_id = uuid4()
        mock_settings.admin_user_ids = [str(admin_user_id)]
        
        existing_item = {
            "id": str(item_id),
            "status": "pending",
            "audit_log": [],
        }
        
        updated_item = {
            "id": str(item_id),
            "status": "resolved",
            "resolved_by": str(admin_user_id),
            "violations": [{"category": "safety", "detail": "Test"}],
            "content": "Test content",
            "content_type": "story",
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-01T10:00:00Z",
        }
        
        mock_supabase_client.get_moderation_item.return_value = existing_item
        mock_supabase_client.resolve_moderation_item.return_value = updated_item
        
        from app.config import get_settings
        from app.auth import get_admin_user_id
        get_settings.cache_clear()
        
        with patch('app.config.get_settings', return_value=mock_settings):
            with patch('app.main.get_settings', return_value=mock_settings):
                with patch('app.auth.get_settings', return_value=mock_settings):
                    with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                        from app.main import create_app
                        app = create_app(mock_settings)
                        app.dependency_overrides[get_settings] = lambda: mock_settings
                        app.dependency_overrides[get_admin_user_id] = lambda: admin_user_id
                        client = TestClient(app)
                        
                        token = create_mock_jwt_token(admin_user_id)
                        
                        payload = {
                            "resolution": "resolved",
                            "notes": "Approved",
                        }
                        
                        response = client.post(
                            f"/api/v1/admin/moderation/{item_id}/resolve",
                            json=payload,
                            headers={"Authorization": f"Bearer {token}"}
                        )
                        
                        app.dependency_overrides.clear()
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "resolved"

    def test_moderation_endpoint_non_admin(self, test_client, mock_settings):
        """Test that non-admin users cannot access moderation endpoints."""
        user_id = uuid4()
        mock_settings.admin_user_ids = [str(uuid4())]  # Different user
        
        token = create_mock_jwt_token(user_id)
        
        response = test_client.get(
            "/api/v1/admin/moderation",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 403


class TestAdminPurgeAssetsEndpoint:
    """Tests for POST /api/v1/admin/purge-assets endpoint."""

    def test_manual_purge_assets(self, mock_supabase_client, mock_settings):
        """Test manual asset purge endpoint."""
        admin_user_id = uuid4()
        mock_settings.admin_user_ids = [str(admin_user_id)]
        
        stats = {
            "assets_found": 10,
            "assets_deleted": 10,
            "storage_deleted": 10,
            "storage_errors": 0,
            "errors": [],
        }
        
        mock_supabase_client.purge_expired_assets.return_value = stats
        
        from app.config import get_settings
        from app.auth import get_admin_user_id
        get_settings.cache_clear()
        
        with patch('app.config.get_settings', return_value=mock_settings):
            with patch('app.main.get_settings', return_value=mock_settings):
                with patch('app.auth.get_settings', return_value=mock_settings):
                    with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                        from app.main import create_app
                        app = create_app(mock_settings)
                        app.dependency_overrides[get_settings] = lambda: mock_settings
                        app.dependency_overrides[get_admin_user_id] = lambda: admin_user_id
                        client = TestClient(app)
                        
                        token = create_mock_jwt_token(admin_user_id)
                        
                        response = client.post(
                            "/api/v1/admin/purge-assets?days_old=7",
                            headers={"Authorization": f"Bearer {token}"}
                        )
                        
                        app.dependency_overrides.clear()
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["stats"]["assets_found"] == 10

    def test_purge_assets_non_admin(self, test_client, mock_settings):
        """Test that non-admin users cannot purge assets."""
        user_id = uuid4()
        mock_settings.admin_user_ids = [str(uuid4())]  # Different user
        
        token = create_mock_jwt_token(user_id)
        
        response = test_client.post(
            "/api/v1/admin/purge-assets?days_old=7",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 403


class TestSubscriptionEndpoints:
    """Tests for subscription endpoints."""

    def test_get_subscription_success(self, mock_supabase_client, mock_settings):
        """Test getting user subscription."""
        user_id = uuid4()
        subscription_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "tier": "premium",
            "status": "active",
            "current_period_start": "2024-01-01T10:00:00Z",
            "current_period_end": "2024-02-01T10:00:00Z",
            "cancel_at_period_end": False,
            "cancelled_at": None,
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-01T10:00:00Z",
        }
        
        # Mock subscription service
        mock_subscription_service = MagicMock()
        mock_subscription_service.get_user_subscription.return_value = subscription_data
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    
                    response = client.get(
                        "/api/v1/subscription",
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "premium"

    def test_get_subscription_free_tier(self, mock_supabase_client, mock_settings):
        """Test getting subscription returns free tier when none exists."""
        user_id = uuid4()
        
        mock_subscription_service = MagicMock()
        mock_subscription_service.get_user_subscription.return_value = None
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    
                    response = client.get(
                        "/api/v1/subscription",
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "free"

    def test_get_usage_quota(self, mock_supabase_client, mock_settings):
        """Test getting usage quota."""
        user_id = uuid4()
        
        mock_subscription_service = MagicMock()
        mock_subscription_service.get_user_tier.return_value = "free"
        mock_subscription_service.get_user_quota.return_value = 3
        mock_subscription_service.get_user_story_count.return_value = 2
        mock_subscription_service.can_generate_story.return_value = (True, None)
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    
                    response = client.get(
                        "/api/v1/subscription/quota",
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "free"
        assert data["quota"] == 3
        assert data["current_count"] == 2
        assert data["can_generate"] is True

    def test_create_subscription(self, mock_supabase_client, mock_settings):
        """Test creating a subscription."""
        user_id = uuid4()
        subscription_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "tier": "premium",
            "status": "active",
            "current_period_start": "2024-01-01T10:00:00Z",
            "current_period_end": "2024-02-01T10:00:00Z",
            "cancel_at_period_end": False,
            "cancelled_at": None,
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-01T10:00:00Z",
        }
        
        mock_subscription_service = MagicMock()
        mock_subscription_service.create_or_update_subscription.return_value = subscription_data
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    payload = {
                        "tier": "premium",
                        "stripe_subscription_id": "sub_123",
                    }
                    
                    response = client.post(
                        "/api/v1/subscription",
                        json=payload,
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "premium"

    def test_cancel_subscription(self, mock_supabase_client, mock_settings):
        """Test canceling a subscription."""
        user_id = uuid4()
        subscription_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "tier": "premium",
            "status": "cancelled",
            "current_period_start": "2024-01-01T10:00:00Z",
            "current_period_end": "2024-02-01T10:00:00Z",
            "cancel_at_period_end": False,
            "cancelled_at": "2024-01-15T10:00:00Z",
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z",
        }
        
        mock_subscription_service = MagicMock()
        mock_subscription_service.cancel_subscription.return_value = subscription_data
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    payload = {
                        "cancel_at_period_end": False,
                    }
                    
                    response = client.post(
                        "/api/v1/subscription/cancel",
                        json=payload,
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "cancelled"


class TestNotificationEndpoints:
    """Tests for notification endpoints."""

    def test_register_notification_token(self, mock_supabase_client, mock_settings):
        """Test registering a notification token."""
        user_id = uuid4()
        
        mock_notification_service = MagicMock()
        mock_notification_service.register_token.return_value = {"id": str(uuid4())}
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.NotificationService', return_value=mock_notification_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    payload = {
                        "token": "fcm_token_123",
                        "platform": "android",
                        "device_id": "device_123",
                    }
                    
                    response = client.post(
                        "/api/v1/notifications/register",
                        json=payload,
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"

    def test_get_notification_preferences(self, mock_supabase_client, mock_settings):
        """Test getting notification preferences."""
        user_id = uuid4()
        preferences_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "bedtime_reminders_enabled": True,
            "bedtime_reminder_time": "21:00:00",
            "streak_notifications_enabled": True,
            "story_recommendations_enabled": True,
            "weekly_summary_enabled": True,
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-01T10:00:00Z",
        }
        
        mock_notification_service = MagicMock()
        mock_notification_service.get_notification_preferences.return_value = preferences_data
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.NotificationService', return_value=mock_notification_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    
                    response = client.get(
                        "/api/v1/notifications/preferences",
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["bedtime_reminders_enabled"] is True

    def test_get_notification_preferences_defaults(self, mock_supabase_client, mock_settings):
        """Test getting notification preferences returns defaults when none exist."""
        user_id = uuid4()
        
        mock_notification_service = MagicMock()
        mock_notification_service.get_notification_preferences.return_value = None
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.NotificationService', return_value=mock_notification_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    
                    response = client.get(
                        "/api/v1/notifications/preferences",
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["bedtime_reminders_enabled"] is True

    def test_update_notification_preferences(self, mock_supabase_client, mock_settings):
        """Test updating notification preferences."""
        user_id = uuid4()
        preferences_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "bedtime_reminders_enabled": False,
            "bedtime_reminder_time": None,
            "streak_notifications_enabled": True,
            "story_recommendations_enabled": True,
            "weekly_summary_enabled": False,
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z",
        }
        
        mock_notification_service = MagicMock()
        mock_notification_service.update_notification_preferences.return_value = preferences_data
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.NotificationService', return_value=mock_notification_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    payload = {
                        "bedtime_reminders_enabled": False,
                        "weekly_summary_enabled": False,
                    }
                    
                    response = client.put(
                        "/api/v1/notifications/preferences",
                        json=payload,
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 200
        data = response.json()
        assert data["bedtime_reminders_enabled"] is False
        assert data["weekly_summary_enabled"] is False

    def test_update_notification_preferences_invalid_time(self, mock_supabase_client, mock_settings):
        """Test updating preferences with invalid time format."""
        user_id = uuid4()
        
        mock_notification_service = MagicMock()
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
                with patch('app.main.NotificationService', return_value=mock_notification_service):
                    from app.main import create_app
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    
                    token = create_mock_jwt_token(user_id)
                    payload = {
                        "bedtime_reminder_time": "invalid_time",
                    }
                    
                    response = client.put(
                        "/api/v1/notifications/preferences",
                        json=payload,
                        headers={"Authorization": f"Bearer {token}"}
                    )
        
        assert response.status_code == 400
        assert "HH:MM format" in response.json()["detail"]

