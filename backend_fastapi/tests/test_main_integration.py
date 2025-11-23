"""
Integration tests for the main FastAPI endpoint.

Tests ensure:
- Full story generation flow works end-to-end
- All 5 tasks work together: persistence, timeouts, signed URLs, chunking, prompts
- Error handling works correctly
"""

import pytest
from unittest.mock import MagicMock, patch, AsyncMock
from uuid import uuid4, UUID
from fastapi.testclient import TestClient

from app.config import Settings, get_settings
from app.main import create_app
from app.schemas import StoryRequest, UserProfile
from app.exceptions import HuggingFaceError, HuggingFaceTimeoutError


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
    settings.sentry_dsn = None
    settings.sentry_environment = "test"
    settings.sentry_traces_sample_rate = 0.0
    settings.asset_retention_days = 7
    return settings


@pytest.fixture
def mock_supabase_client():
    """Create mock Supabase client."""
    client = MagicMock()
    
    # Mock session creation
    session_data = {"id": str(uuid4())}
    client.create_session.return_value = session_data
    
    # Mock profile upsert
    client.upsert_profile.return_value = {"id": str(uuid4())}
    
    # Mock asset creation
    client.create_session_assets_batch.return_value = []
    
    # Mock upload methods
    client.upload_audio.return_value = "https://supabase.co/storage/audio/test.wav"
    client.upload_video.return_value = "https://supabase.co/storage/video/test.mp4"
    client.upload_frame.return_value = "https://supabase.co/storage/frames/test.png"
    
    # Mock client attribute for subscription service
    client.client = MagicMock()
    
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
    
    with patch('app.main.get_settings', new=lambda: mock_settings):
        with patch('app.main.SupabaseClient', return_value=mock_supabase_client):
            with patch('app.main.SubscriptionService', return_value=mock_subscription_service):
                with patch('app.main.NotificationService', return_value=MagicMock()):
                    # Try to patch RecommendationEngine if it exists
                    try:
                        with patch('app.main.RecommendationEngine', return_value=MagicMock()):
                            app = create_app(mock_settings)
                            return TestClient(app)
                    except (ImportError, AttributeError):
                        # RecommendationEngine might not exist, skip it
                        app = create_app(mock_settings)
                        return TestClient(app)


class TestStoryGenerationEndpoint:
    """Tests for /api/v1/story endpoint."""

    def test_generate_story_with_persistence(self, test_client, mock_supabase_client):
        """Test full story generation with Supabase persistence."""
        # Mock HuggingFace responses
        mock_story = "Once upon a time, there was a peaceful ocean..."
        mock_audio_response = {"audio": b"fake_audio_data"}
        mock_image_bytes = b"fake_image_data"
        
        with patch('app.services.StoryGenerator.generate', new_callable=AsyncMock, return_value=mock_story):
            with patch('app.services.NarrationGenerator.synthesize', new_callable=AsyncMock, return_value="https://supabase.co/storage/audio/test.wav"):
                with patch('app.services.VisualGenerator.create_frames', new_callable=AsyncMock, return_value=["https://supabase.co/storage/frames/test1.png", "https://supabase.co/storage/frames/test2.png"]):
                    with patch('app.main.stitch_video', new_callable=AsyncMock, return_value="https://supabase.co/storage/video/test.mp4"):
                        with patch('app.guardrails.ContentGuard.check_story', return_value=[]):
                            payload = StoryRequest(
                                prompt="A peaceful ocean journey",
                                theme="ocean",
                                target_length=400,
                                num_scenes=2,
                                user_id=uuid4(),
                                profile=UserProfile(
                                    mood="calm",
                                    routine="reading",
                                    preferences=["nature", "ocean"],
                                ),
                            )
                            
                            response = test_client.post("/api/v1/story", json=payload.model_dump(mode='json'))
        
        assert response.status_code == 200
        data = response.json()
        assert "story_text" in data
        assert "assets" in data
        assert "session_id" in data
        assert data["assets"]["audio"].startswith("https://")
        assert data["assets"]["video"].startswith("https://")
        assert len(data["assets"]["frames"]) == 2
        
        # Verify Supabase persistence was called
        mock_supabase_client.create_session.assert_called_once()
        mock_supabase_client.create_session_assets_batch.assert_called_once()
        mock_supabase_client.upsert_profile.assert_called_once()

    def test_generate_story_without_user_id(self, test_client):
        """Test story generation without user_id (no persistence)."""
        mock_story = "Once upon a time..."
        
        with patch('app.services.StoryGenerator.generate', new_callable=AsyncMock, return_value=mock_story):
            with patch('app.services.NarrationGenerator.synthesize', new_callable=AsyncMock, return_value="/tmp/audio.wav"):
                with patch('app.services.VisualGenerator.create_frames', new_callable=AsyncMock, return_value=["/tmp/frame1.png"]):
                    with patch('app.main.stitch_video', new_callable=AsyncMock, return_value="/tmp/video.mp4"):
                        with patch('app.guardrails.ContentGuard.check_story', return_value=[]):
                            payload = StoryRequest(
                                prompt="A story",
                                theme="ocean",
                                target_length=400,
                                num_scenes=1,
                            )
                            
                            response = test_client.post("/api/v1/story", json=payload.model_dump(mode='json'))
        
        assert response.status_code == 200
        data = response.json()
        assert data["session_id"] is None

    def test_generate_story_with_timeout_error(self, test_client):
        """Test story generation handles timeout errors."""
        with patch('app.services.StoryGenerator.generate', new_callable=AsyncMock, side_effect=HuggingFaceTimeoutError("Request timed out", model_id="test-model")):
            payload = StoryRequest(
                prompt="A story",
                theme="ocean",
                target_length=400,
                num_scenes=1,
            )
            
            response = test_client.post("/api/v1/story", json=payload.model_dump(mode='json'))
        
        assert response.status_code == 503
        data = response.json()
        assert "error" in data["detail"]
        assert "timed out" in data["detail"]["error"].lower()

    def test_generate_story_with_guardrail_violation(self, test_client):
        """Test story generation handles guardrail violations."""
        from app.guardrails import GuardrailViolation
        
        mock_story = "Once upon a time..."
        violations = [
            GuardrailViolation(category="safety", detail="Contains banned term 'violence'")
        ]
        
        with patch('app.services.StoryGenerator.generate', new_callable=AsyncMock, return_value=mock_story):
            with patch('app.guardrails.ContentGuard.check_story', return_value=violations):
                payload = StoryRequest(
                    prompt="A story",
                    theme="ocean",
                    target_length=400,
                    num_scenes=1,
                )
                
                response = test_client.post("/api/v1/story", json=payload.model_dump(mode='json'))
        
        assert response.status_code == 422
        data = response.json()
        assert "detail" in data

    def test_generate_story_persistence_error_does_not_fail(self, test_client, mock_supabase_client):
        """Test that persistence errors don't fail the request."""
        mock_story = "Once upon a time..."
        
        # Make Supabase client raise error
        mock_supabase_client.create_session.side_effect = Exception("Database error")
        
        with patch('app.services.StoryGenerator.generate', new_callable=AsyncMock, return_value=mock_story):
            with patch('app.services.NarrationGenerator.synthesize', new_callable=AsyncMock, return_value="https://supabase.co/storage/audio/test.wav"):
                with patch('app.services.VisualGenerator.create_frames', new_callable=AsyncMock, return_value=["https://supabase.co/storage/frames/test.png"]):
                    with patch('app.main.stitch_video', new_callable=AsyncMock, return_value="https://supabase.co/storage/video/test.mp4"):
                        with patch('app.guardrails.ContentGuard.check_story', return_value=[]):
                            payload = StoryRequest(
                                prompt="A story",
                                theme="ocean",
                                target_length=400,
                                num_scenes=1,
                                user_id=uuid4(),
                            )
                            
                            response = test_client.post("/api/v1/story", json=payload.model_dump(mode='json'))
        
        # Should still succeed even if persistence fails
        assert response.status_code == 200
        data = response.json()
        assert data["session_id"] is None  # Persistence failed, so no session_id

    def test_generate_story_missing_hf_token(self, mock_settings):
        """Test error when HuggingFace token is missing."""
        mock_settings.hf_token = None
        
        with patch('app.main.get_settings', new=lambda: mock_settings):
            with patch('app.main.SupabaseClient', return_value=MagicMock()):
                app = create_app(mock_settings)
                client = TestClient(app)
                
                payload = StoryRequest(
                    prompt="A story",
                    theme="ocean",
                    target_length=400,
                    num_scenes=1,
                )
                
                response = client.post("/api/v1/story", json=payload.model_dump(mode="json"))
        
        assert response.status_code == 500
        assert "HUGGINGFACE_API_TOKEN" in response.json()["detail"]

    def test_health_endpoint(self, test_client):
        """Test health check endpoint."""
        mock_settings = MagicMock()
        mock_settings.story_model = "test/story-model"
        test_client.app.dependency_overrides[get_settings] = lambda: mock_settings
        try:
            response = test_client.get("/health")
        finally:
            test_client.app.dependency_overrides.pop(get_settings, None)
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "story_model" in data


class TestStoryGenerationWithChunking:
    """Tests for story generation with scene chunking."""

    def test_generate_story_with_multiple_scenes(self, test_client, mock_supabase_client):
        """Test story generation with multiple scenes (chunking)."""
        mock_story = "Paragraph 1\n\nParagraph 2\n\nParagraph 3\n\nParagraph 4\n\nParagraph 5"
        frame_urls = [
            "https://supabase.co/storage/frames/frame1.png",
            "https://supabase.co/storage/frames/frame2.png",
            "https://supabase.co/storage/frames/frame3.png",
        ]
        
        with patch('app.services.StoryGenerator.generate', new_callable=AsyncMock, return_value=mock_story):
            with patch('app.services.NarrationGenerator.synthesize', new_callable=AsyncMock, return_value="https://supabase.co/storage/audio/test.wav"):
                with patch('app.services.VisualGenerator.create_frames', new_callable=AsyncMock, return_value=frame_urls):
                    with patch('app.main.stitch_video', new_callable=AsyncMock, return_value="https://supabase.co/storage/video/test.mp4"):
                        with patch('app.guardrails.ContentGuard.check_story', return_value=[]):
                            payload = StoryRequest(
                                prompt="A story",
                                theme="ocean",
                                target_length=400,
                                num_scenes=3,
                                user_id=uuid4(),
                            )
                            
                            response = test_client.post("/api/v1/story", json=payload.model_dump(mode='json'))
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["assets"]["frames"]) == 3
        
        # Verify session assets include all frames
        call_args = mock_supabase_client.create_session_assets_batch.call_args
        assets = call_args[1]["assets"]
        frame_assets = [a for a in assets if a["asset_type"] == "frame"]
        assert len(frame_assets) == 3


class TestRequestContextMiddleware:
    """Tests for request-scoped logging metadata."""

    def test_request_id_generated_when_missing(self, test_client):
        """Middleware should inject an X-Request-ID if none provided."""
        mock_settings = MagicMock()
        mock_settings.story_model = "test/story-model"
        test_client.app.dependency_overrides[get_settings] = lambda: mock_settings
        try:
            response = test_client.get("/health")
        finally:
            test_client.app.dependency_overrides.pop(get_settings, None)

        assert response.status_code == 200
        assert response.headers.get("X-Request-ID")

    def test_request_and_prompt_ids_preserved(self, test_client):
        """Middleware should propagate caller-supplied IDs."""
        mock_settings = MagicMock()
        mock_settings.story_model = "test/story-model"
        test_client.app.dependency_overrides[get_settings] = lambda: mock_settings
        try:
            response = test_client.get(
                "/health",
                headers={
                    "X-Request-ID": "external-request-123",
                    "X-Prompt-ID": "prompt-abc",
                },
            )
        finally:
            test_client.app.dependency_overrides.pop(get_settings, None)

        assert response.status_code == 200
        assert response.headers["X-Request-ID"] == "external-request-123"
        assert response.headers["X-Prompt-ID"] == "prompt-abc"