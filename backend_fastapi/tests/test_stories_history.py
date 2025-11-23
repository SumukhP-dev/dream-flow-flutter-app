"""
Tests for GET /api/v1/stories/history endpoint.

Tests ensure:
- Authenticated users can retrieve their story history
- Pagination works correctly (limit, offset, has_more)
- Assets are properly included with each story
- Error handling for missing auth, Supabase errors, etc.
"""

import pytest
from unittest.mock import MagicMock, patch
from uuid import uuid4, UUID
from fastapi.testclient import TestClient
from fastapi import HTTPException

from app.config import Settings
from app.main import create_app
from app.schemas import StoryHistoryResponse


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
    # Mock subscription service
    mock_subscription_service = MagicMock()
    mock_subscription_service.can_generate_story.return_value = (True, None)
    
    # Mock client attribute for subscription service
    mock_supabase_client.client = MagicMock()
    
    with patch('app.main.get_settings', return_value=mock_settings):
        with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
            with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                with patch('app.main.NotificationService', return_value=MagicMock()):
                    try:
                        with patch('app.main.RecommendationEngine', return_value=MagicMock()):
                            app = create_app(mock_settings)
                            return TestClient(app)
                    except (ImportError, AttributeError):
                        app = create_app(mock_settings)
                        return TestClient(app)


def create_mock_jwt_token(user_id: UUID) -> str:
    """Create a mock JWT token for testing."""
    import base64
    import json
    import time
    
    # Create a simple mock JWT payload
    payload = {
        "sub": str(user_id),
        "exp": int(time.time()) + 3600,  # Expires in 1 hour
    }
    
    # Encode payload as base64
    payload_json = json.dumps(payload)
    payload_b64 = base64.urlsafe_b64encode(payload_json.encode()).decode().rstrip('=')
    
    # Return a mock JWT token (header.payload.signature)
    return f"header.{payload_b64}.signature"


class TestStoriesHistoryEndpoint:
    """Tests for GET /api/v1/stories/history endpoint."""

    def test_get_stories_history_success(self, test_client, mock_supabase_client):
        """Test successful retrieval of story history."""
        user_id = uuid4()
        session_id_1 = uuid4()
        session_id_2 = uuid4()
        asset_id_1 = uuid4()
        asset_id_2 = uuid4()
        
        # Mock sessions data
        mock_sessions = [
            {
                "id": str(session_id_1),
                "prompt": "A peaceful ocean journey",
                "theme": "Oceanic Serenity",
                "story_text": "Once upon a time...",
                "target_length": 400,
                "num_scenes": 4,
                "voice": "gentle",
                "created_at": "2024-01-01T10:00:00Z",
                "updated_at": "2024-01-01T10:00:00Z",
            },
            {
                "id": str(session_id_2),
                "prompt": "A forest adventure",
                "theme": "Whispering Woods",
                "story_text": "In a magical forest...",
                "target_length": 500,
                "num_scenes": 5,
                "voice": None,
                "created_at": "2024-01-02T10:00:00Z",
                "updated_at": "2024-01-02T10:00:00Z",
            },
        ]
        
        # Mock assets data
        mock_assets_1 = [
            {
                "id": str(asset_id_1),
                "asset_type": "audio",
                "asset_url": "https://supabase.co/storage/audio/test1.wav",
                "display_order": 0,
            },
            {
                "id": str(asset_id_2),
                "asset_type": "video",
                "asset_url": "https://supabase.co/storage/video/test1.mp4",
                "display_order": 1,
            },
        ]
        
        mock_assets_2 = [
            {
                "id": str(uuid4()),
                "asset_type": "frame",
                "asset_url": "https://supabase.co/storage/frames/frame1.png",
                "display_order": 0,
            },
        ]
        
        # Configure mocks
        mock_supabase_client.get_user_sessions.return_value = mock_sessions
        mock_supabase_client.get_session_assets.side_effect = [
            mock_assets_1,
            mock_assets_2,
        ]
        
        # Create auth token
        token = create_mock_jwt_token(user_id)
        
        # Make request
        response = test_client.get(
            "/api/v1/stories/history?limit=10&offset=0",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify response structure
        assert "stories" in data
        assert "total" in data
        assert "limit" in data
        assert "offset" in data
        assert "has_more" in data
        
        # Verify values
        assert len(data["stories"]) == 2
        assert data["limit"] == 10
        assert data["offset"] == 0
        
        # Verify first story
        story_1 = data["stories"][0]
        assert story_1["id"] == str(session_id_1)
        assert story_1["prompt"] == "A peaceful ocean journey"
        assert story_1["theme"] == "Oceanic Serenity"
        assert len(story_1["assets"]) == 2
        assert story_1["assets"][0]["asset_type"] == "audio"
        assert story_1["assets"][1]["asset_type"] == "video"
        
        # Verify second story
        story_2 = data["stories"][1]
        assert story_2["id"] == str(session_id_2)
        assert story_2["theme"] == "Whispering Woods"
        assert len(story_2["assets"]) == 1
        
        # Verify Supabase was called correctly
        mock_supabase_client.get_user_sessions.assert_called_once_with(
            user_id=user_id,
            limit=11,  # limit + 1 to check for more
            offset=0,
            order_by="created_at",
            ascending=False,
        )
        assert mock_supabase_client.get_session_assets.call_count == 2

    def test_get_stories_history_with_pagination(self, test_client, mock_supabase_client):
        """Test pagination parameters work correctly."""
        user_id = uuid4()
        
        # Mock 11 sessions (to test has_more)
        mock_sessions = [
            {
                "id": str(uuid4()),
                "prompt": f"Story {i}",
                "theme": "Test Theme",
                "story_text": f"Story text {i}",
                "target_length": 400,
                "num_scenes": 4,
                "created_at": f"2024-01-{i:02d}T10:00:00Z",
                "updated_at": f"2024-01-{i:02d}T10:00:00Z",
            }
            for i in range(1, 12)  # 11 sessions
        ]
        
        mock_supabase_client.get_user_sessions.return_value = mock_sessions
        mock_supabase_client.get_session_assets.return_value = []
        
        token = create_mock_jwt_token(user_id)
        
        # Request with limit=10
        response = test_client.get(
            "/api/v1/stories/history?limit=10&offset=0",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should return 10 items and indicate has_more
        assert len(data["stories"]) == 10
        assert data["has_more"] is True
        assert data["limit"] == 10
        
        # Test offset
        response = test_client.get(
            "/api/v1/stories/history?limit=10&offset=10",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["offset"] == 10

    def test_get_stories_history_no_auth(self, test_client):
        """Test that missing auth header returns 401."""
        response = test_client.get("/api/v1/stories/history")
        
        assert response.status_code == 401
        assert "Authorization" in response.json()["detail"]

    def test_get_stories_history_invalid_token(self, test_client):
        """Test that invalid token returns 401."""
        response = test_client.get(
            "/api/v1/stories/history",
            headers={"Authorization": "Bearer invalid_token"}
        )
        
        assert response.status_code == 401

    def test_get_stories_history_supabase_not_configured(self, mock_settings):
        """Test error when Supabase is not configured."""
        # Create app without Supabase client
        with patch('app.main.get_settings', return_value=mock_settings):
            with patch('app.main.SupabaseClient', side_effect=ValueError("Not configured")):
                app = create_app(mock_settings)
                client = TestClient(app)
                
                user_id = uuid4()
                token = create_mock_jwt_token(user_id)
                
                response = client.get(
                    "/api/v1/stories/history",
                    headers={"Authorization": f"Bearer {token}"}
                )
        
        assert response.status_code == 503
        assert "Supabase not configured" in response.json()["detail"]

    def test_get_stories_history_empty_result(self, test_client, mock_supabase_client):
        """Test handling of empty history."""
        user_id = uuid4()
        
        mock_supabase_client.get_user_sessions.return_value = []
        
        token = create_mock_jwt_token(user_id)
        
        response = test_client.get(
            "/api/v1/stories/history",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["stories"]) == 0
        assert data["has_more"] is False
        assert data["total"] >= 0

    def test_get_stories_history_with_assets(self, test_client, mock_supabase_client):
        """Test that assets are properly included with stories."""
        user_id = uuid4()
        session_id = uuid4()
        
        mock_sessions = [
            {
                "id": str(session_id),
                "prompt": "Test story",
                "theme": "Test Theme",
                "story_text": "Story text",
                "target_length": 400,
                "num_scenes": 4,
                "created_at": "2024-01-01T10:00:00Z",
                "updated_at": "2024-01-01T10:00:00Z",
            },
        ]
        
        mock_assets = [
            {
                "id": str(uuid4()),
                "asset_type": "audio",
                "asset_url": "https://supabase.co/storage/audio/test.wav",
                "display_order": 0,
            },
            {
                "id": str(uuid4()),
                "asset_type": "video",
                "asset_url": "https://supabase.co/storage/video/test.mp4",
                "display_order": 1,
            },
            {
                "id": str(uuid4()),
                "asset_type": "frame",
                "asset_url": "https://supabase.co/storage/frames/frame1.png",
                "display_order": 2,
            },
            {
                "id": str(uuid4()),
                "asset_type": "frame",
                "asset_url": "https://supabase.co/storage/frames/frame2.png",
                "display_order": 3,
            },
        ]
        
        mock_supabase_client.get_user_sessions.return_value = mock_sessions
        mock_supabase_client.get_session_assets.return_value = mock_assets
        
        token = create_mock_jwt_token(user_id)
        
        response = test_client.get(
            "/api/v1/stories/history",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        
        story = data["stories"][0]
        assert len(story["assets"]) == 4
        
        # Verify asset types
        asset_types = [asset["asset_type"] for asset in story["assets"]]
        assert "audio" in asset_types
        assert "video" in asset_types
        assert "frame" in asset_types

    def test_get_stories_history_limit_validation(self, test_client, mock_supabase_client):
        """Test limit parameter validation."""
        user_id = uuid4()
        token = create_mock_jwt_token(user_id)
        
        # Test limit too high
        response = test_client.get(
            "/api/v1/stories/history?limit=101",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 422
        
        # Test limit too low
        response = test_client.get(
            "/api/v1/stories/history?limit=0",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 422
        
        # Test negative offset
        response = test_client.get(
            "/api/v1/stories/history?offset=-1",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 422

    def test_get_stories_history_supabase_error(self, test_client, mock_supabase_client):
        """Test handling of Supabase errors."""
        user_id = uuid4()
        
        # Make Supabase raise an error
        mock_supabase_client.get_user_sessions.side_effect = Exception("Database error")
        
        token = create_mock_jwt_token(user_id)
        
        response = test_client.get(
            "/api/v1/stories/history",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        assert response.status_code == 500
        assert "Failed to fetch story history" in response.json()["detail"]

