"""
Unit tests for SupabaseClient.

Tests ensure:
- Session creation and persistence works correctly
- Session assets are created and linked properly
- Media uploads (audio, video, frames) work correctly
- Signed URLs are generated properly
- Error handling works correctly
"""

import pytest
from unittest.mock import MagicMock, patch, Mock
from uuid import uuid4, UUID

from app.config import Settings
from app.supabase_client import SupabaseClient


class TestSupabaseClientInitialization:
    """Tests for SupabaseClient initialization."""

    def test_init_with_valid_settings(self):
        """Test initialization with valid settings."""
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_service_role_key = "test_key"
        
        with patch('app.supabase_client.create_client') as mock_create:
            mock_client = MagicMock()
            mock_create.return_value = mock_client
            
            client = SupabaseClient(mock_settings)
            
            assert client.settings == mock_settings
            assert client.client == mock_client
            mock_create.assert_called_once()

    def test_init_without_url_raises_error(self):
        """Test initialization without URL raises ValueError."""
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = None
        mock_settings.supabase_service_role_key = "test_key"
        
        with pytest.raises(ValueError, match="SUPABASE_URL"):
            SupabaseClient(mock_settings)

    def test_init_without_key_raises_error(self):
        """Test initialization without service role key raises ValueError."""
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_service_role_key = None
        
        with pytest.raises(ValueError, match="SUPABASE_SERVICE_ROLE_KEY"):
            SupabaseClient(mock_settings)


class TestSupabaseClientSessions:
    """Tests for session creation and management."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_create_session(self):
        """Test session creation."""
        user_id = uuid4()
        session_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "prompt": "Test prompt",
            "theme": "ocean",
            "story_text": "Test story",
            "target_length": 400,
            "num_scenes": 4,
            "voice": "alloy",
        }
        
        mock_response = MagicMock()
        mock_response.data = [session_data]
        self.mock_table.insert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.create_session(
            user_id=user_id,
            prompt="Test prompt",
            theme="ocean",
            story_text="Test story",
            target_length=400,
            num_scenes=4,
            voice="alloy",
        )
        
        assert result == session_data
        self.mock_table.insert.assert_called_once()

    def test_get_session(self):
        """Test getting a session by ID."""
        session_id = uuid4()
        session_data = {
            "id": str(session_id),
            "user_id": str(uuid4()),
            "prompt": "Test prompt",
            "theme": "ocean",
            "story_text": "Test story",
        }
        
        mock_response = MagicMock()
        mock_response.data = [session_data]
        self.mock_table.select.return_value.eq.return_value.single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_session(session_id)
        
        # The get_session method returns response.data[0] if data exists, else {}
        assert result == session_data

    def test_get_user_sessions(self):
        """Test getting all sessions for a user."""
        user_id = uuid4()
        sessions = [
            {"id": str(uuid4()), "user_id": str(user_id), "prompt": "Prompt 1"},
            {"id": str(uuid4()), "user_id": str(user_id), "prompt": "Prompt 2"},
        ]
        
        mock_response = MagicMock()
        mock_response.data = sessions
        # Set up the chain properly - get_user_sessions uses .range() not .limit()
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.order.return_value = chain
        chain.range.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.supabase_client.get_user_sessions(user_id, limit=10)
        
        # The get_user_sessions method returns response.data if data exists, else []
        assert len(result) == 2
        assert result == sessions


class TestSupabaseClientSessionAssets:
    """Tests for session asset creation and management."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_create_session_asset(self):
        """Test creating a single session asset."""
        session_id = uuid4()
        asset_data = {
            "id": str(uuid4()),
            "session_id": str(session_id),
            "asset_type": "audio",
            "asset_url": "https://supabase.co/storage/audio/test.wav",
            "display_order": 0,
        }
        
        mock_response = MagicMock()
        mock_response.data = [asset_data]
        self.mock_table.insert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.create_session_asset(
            session_id=session_id,
            asset_type="audio",
            asset_url="https://supabase.co/storage/audio/test.wav",
            display_order=0,
        )
        
        assert result == asset_data

    def test_create_session_assets_batch(self):
        """Test creating multiple session assets in batch."""
        session_id = uuid4()
        assets = [
            {"asset_type": "audio", "asset_url": "https://supabase.co/storage/audio/test.wav", "display_order": 0},
            {"asset_type": "video", "asset_url": "https://supabase.co/storage/video/test.mp4", "display_order": 1},
            {"asset_type": "frame", "asset_url": "https://supabase.co/storage/frames/test.png", "display_order": 2},
        ]
        
        mock_response = MagicMock()
        mock_response.data = [
            {"id": str(uuid4()), "session_id": str(session_id), **asset}
            for asset in assets
        ]
        self.mock_table.insert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.create_session_assets_batch(
            session_id=session_id,
            assets=assets,
        )
        
        assert len(result) == 3
        self.mock_table.insert.assert_called_once()

    def test_create_session_asset_invalid_type(self):
        """Test creating asset with invalid type raises ValueError."""
        session_id = uuid4()
        
        with pytest.raises(ValueError, match="asset_type must be"):
            self.supabase_client.create_session_asset(
                session_id=session_id,
                asset_type="invalid",
                asset_url="https://test.com/file",
            )

    def test_get_session_assets(self):
        """Test getting all assets for a session."""
        session_id = uuid4()
        assets = [
            {"id": str(uuid4()), "session_id": str(session_id), "asset_type": "audio", "display_order": 0},
            {"id": str(uuid4()), "session_id": str(session_id), "asset_type": "frame", "display_order": 1},
        ]
        
        mock_response = MagicMock()
        mock_response.data = assets
        self.mock_table.select.return_value.eq.return_value.order.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_session_assets(session_id)
        
        assert len(result) == 2
        assert result == assets

    def test_get_session_assets_filtered_by_type(self):
        """Test getting assets filtered by type."""
        session_id = uuid4()
        assets = [
            {"id": str(uuid4()), "session_id": str(session_id), "asset_type": "frame", "display_order": 0},
        ]
        
        mock_response = MagicMock()
        mock_response.data = assets
        # Set up the chain properly - two eq calls, then order, then execute
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain  # First eq for session_id
        chain.eq.return_value = chain  # Second eq for asset_type  
        chain.order.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.supabase_client.get_session_assets(session_id, asset_type="frame")
        
        assert len(result) == 1
        assert result[0]["asset_type"] == "frame"


class TestSupabaseClientStorage:
    """Tests for Supabase Storage operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_storage = MagicMock()
        self.mock_bucket = MagicMock()
        self.mock_client.storage.from_.return_value = self.mock_bucket
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_upload_file(self):
        """Test file upload to storage."""
        file_data = b"test file content"
        mock_response = MagicMock()
        mock_response.error = None
        self.mock_bucket.upload.return_value = mock_response
        
        result = self.supabase_client.upload_file(
            bucket_name="test_bucket",
            file_path="test/file.png",
            file_data=file_data,
            content_type="image/png",
        )
        
        assert result == "test/file.png"
        self.mock_bucket.upload.assert_called_once()

    def test_get_signed_url(self):
        """Test getting signed URL for a file."""
        signed_url = "https://supabase.co/storage/v1/object/sign/test_bucket/test/file.png?token=abc123"
        
        mock_response = MagicMock()
        mock_response.error = None
        mock_response.data = {"signedURL": signed_url}
        self.mock_bucket.create_signed_url.return_value = mock_response
        
        result = self.supabase_client.get_signed_url(
            bucket_name="test_bucket",
            file_path="test/file.png",
            expires_in=3600,
        )
        
        assert result == signed_url
        # Verify the method was called
        assert self.mock_bucket.create_signed_url.called

    def test_upload_audio(self):
        """Test audio upload returns signed URL."""
        file_data = b"audio data"
        signed_url = "https://supabase.co/storage/v1/object/sign/audio/audio/test.wav?token=abc123"
        
        # Mock upload_file
        with patch.object(self.supabase_client, 'upload_file', return_value="audio/test.wav") as mock_upload:
            # Mock get_signed_url
            with patch.object(self.supabase_client, 'get_signed_url', return_value=signed_url) as mock_get_url:
                result = self.supabase_client.upload_audio(file_data, "test.wav")
        
        assert result == signed_url
        # Verify methods were called
        assert mock_upload.called
        assert mock_get_url.called

    def test_upload_video(self):
        """Test video upload returns signed URL."""
        file_data = b"video data"
        signed_url = "https://supabase.co/storage/v1/object/sign/video/video/test.mp4?token=abc123"
        
        # Mock upload_file
        with patch.object(self.supabase_client, 'upload_file', return_value="video/test.mp4") as mock_upload:
            # Mock get_signed_url
            with patch.object(self.supabase_client, 'get_signed_url', return_value=signed_url) as mock_get_url:
                result = self.supabase_client.upload_video(file_data, "test.mp4")
        
        assert result == signed_url
        # Verify methods were called
        assert mock_upload.called
        assert mock_get_url.called

    def test_upload_frame(self):
        """Test frame upload returns signed URL."""
        file_data = b"image data"
        signed_url = "https://supabase.co/storage/v1/object/sign/frames/frames/test.png?token=abc123"
        
        # Mock upload_file
        with patch.object(self.supabase_client, 'upload_file', return_value="frames/test.png") as mock_upload:
            # Mock get_signed_url
            with patch.object(self.supabase_client, 'get_signed_url', return_value=signed_url) as mock_get_url:
                result = self.supabase_client.upload_frame(file_data, "test.png")
        
        assert result == signed_url
        # Verify methods were called
        assert mock_upload.called
        assert mock_get_url.called

    def test_get_signed_url_dict_response(self):
        """Test get_signed_url handles dict response format."""
        signed_url = "https://supabase.co/storage/v1/object/sign/test_bucket/test/file.png?token=abc123"
        
        # Test dict response with signedURL key
        mock_response = {"signedURL": signed_url}
        self.mock_bucket.create_signed_url.return_value = mock_response
        
        result = self.supabase_client.get_signed_url(
            bucket_name="test_bucket",
            file_path="test/file.png",
        )
        
        assert result == signed_url

    def test_get_signed_url_error_handling(self):
        """Test get_signed_url handles errors correctly."""
        mock_response = MagicMock()
        mock_response.error = "File not found"
        self.mock_bucket.create_signed_url.return_value = mock_response
        
        with pytest.raises(Exception, match="Failed to create signed URL"):
            self.supabase_client.get_signed_url(
                bucket_name="test_bucket",
                file_path="test/file.png",
            )


class TestSupabaseClientProfile:
    """Tests for profile operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_upsert_profile(self):
        """Test profile upsert operation."""
        user_id = uuid4()
        profile_data = {
            "id": str(uuid4()),
            "user_id": str(user_id),
            "mood": "calm",
            "routine": "reading",
            "preferences": ["nature", "ocean"],
        }
        
        mock_response = MagicMock()
        mock_response.data = [profile_data]
        self.mock_table.upsert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.upsert_profile(
            user_id=user_id,
            mood="calm",
            routine="reading",
            preferences=["nature", "ocean"],
        )
        
        assert result == profile_data
        self.mock_table.upsert.assert_called_once()

    def test_get_profile(self):
        """Test getting a profile by user ID."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "calm",
            "routine": "reading",
            "preferences": ["nature", "ocean"],
        }
        
        mock_response = MagicMock()
        mock_response.data = profile_data
        self.mock_table.select.return_value.eq.return_value.maybe_single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_profile(user_id)
        
        assert result == profile_data

    def test_get_profile_not_found(self):
        """Test getting a profile that doesn't exist returns None."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = None
        self.mock_table.select.return_value.eq.return_value.maybe_single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_profile(user_id)
        
        assert result is None

    def test_create_profile(self):
        """Test creating a new profile."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "calm",
            "routine": "reading",
            "preferences": ["nature"],
            "favorite_characters": [],
            "calming_elements": [],
        }
        
        mock_response = MagicMock()
        mock_response.data = [profile_data]
        self.mock_table.insert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.create_profile(
            user_id=user_id,
            mood="calm",
            routine="reading",
            preferences=["nature"],
        )
        
        assert result == profile_data

    def test_update_profile(self):
        """Test updating an existing profile."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "relaxed",
            "routine": "meditation",
        }
        
        mock_response = MagicMock()
        mock_response.data = [profile_data]
        self.mock_table.update.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.update_profile(
            user_id=user_id,
            mood="relaxed",
            routine="meditation",
        )
        
        assert result == profile_data

    def test_update_profile_no_changes(self):
        """Test updating profile with no changes returns existing profile."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "calm",
        }
        
        # Mock get_profile to return existing profile
        with patch.object(self.supabase_client, 'get_profile', return_value=profile_data):
            result = self.supabase_client.update_profile(user_id=user_id)
        
        assert result == profile_data

    def test_delete_profile(self):
        """Test deleting a profile."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = [{"id": str(user_id)}]
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.delete_profile(user_id)
        
        assert result is True

    def test_delete_profile_not_found(self):
        """Test deleting a profile that doesn't exist returns False."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = []
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.delete_profile(user_id)
        
        assert result is False


class TestSupabaseClientSessionOperations:
    """Tests for session update and delete operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_update_session(self):
        """Test updating a session."""
        session_id = uuid4()
        session_data = {
            "id": str(session_id),
            "prompt": "Updated prompt",
            "theme": "ocean",
        }
        
        mock_response = MagicMock()
        mock_response.data = [session_data]
        self.mock_table.update.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.update_session(
            session_id=session_id,
            prompt="Updated prompt",
        )
        
        assert result == session_data

    def test_update_session_no_changes(self):
        """Test updating session with no changes returns existing session."""
        session_id = uuid4()
        session_data = {"id": str(session_id), "prompt": "Original"}
        
        with patch.object(self.supabase_client, 'get_session', return_value=session_data):
            result = self.supabase_client.update_session(session_id=session_id)
        
        assert result == session_data

    def test_delete_session(self):
        """Test deleting a session."""
        session_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = [{"id": str(session_id)}]
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.delete_session(session_id)
        
        assert result is True

    def test_delete_session_not_found(self):
        """Test deleting a session that doesn't exist returns False."""
        session_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = []
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.delete_session(session_id)
        
        assert result is False


class TestSupabaseClientSessionAssetOperations:
    """Tests for session asset delete operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_delete_session_asset(self):
        """Test deleting a single session asset."""
        asset_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = [{"id": str(asset_id)}]
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.delete_session_asset(asset_id)
        
        assert result is True

    def test_delete_session_assets_by_type(self):
        """Test deleting all assets for a session filtered by type."""
        session_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = [
            {"id": str(uuid4()), "asset_type": "frame"},
            {"id": str(uuid4()), "asset_type": "frame"},
        ]
        chain = self.mock_table.delete.return_value
        chain.eq.return_value = chain
        chain.eq.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.supabase_client.delete_session_assets(session_id, asset_type="frame")
        
        assert result == 2

    def test_delete_session_assets_all_types(self):
        """Test deleting all assets for a session."""
        session_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = [
            {"id": str(uuid4())},
            {"id": str(uuid4())},
            {"id": str(uuid4())},
        ]
        chain = self.mock_table.delete.return_value
        chain.eq.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.supabase_client.delete_session_assets(session_id)
        
        assert result == 3


class TestSupabaseClientStorageDelete:
    """Tests for storage delete operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_storage = MagicMock()
        self.mock_bucket = MagicMock()
        self.mock_client.storage.from_.return_value = self.mock_bucket
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_delete_file(self):
        """Test deleting a file from storage."""
        mock_response = MagicMock()
        mock_response.error = None
        self.mock_bucket.remove.return_value = mock_response
        
        result = self.supabase_client.delete_file(
            bucket_name="test_bucket",
            file_path="test/file.png"
        )
        
        assert result is True
        self.mock_bucket.remove.assert_called_once_with(["test/file.png"])

    def test_delete_file_with_error(self):
        """Test deleting a file that raises an error."""
        mock_response = MagicMock()
        mock_response.error = "File not found"
        self.mock_bucket.remove.return_value = mock_response
        
        with pytest.raises(Exception, match="Failed to delete file"):
            self.supabase_client.delete_file(
                bucket_name="test_bucket",
                file_path="test/file.png"
            )


class TestSupabaseClientFeedback:
    """Tests for feedback operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_create_feedback(self):
        """Test creating feedback."""
        session_id = uuid4()
        user_id = uuid4()
        feedback_data = {
            "id": str(uuid4()),
            "session_id": str(session_id),
            "user_id": str(user_id),
            "rating": 5,
            "mood_delta": 2,
        }
        
        mock_response = MagicMock()
        mock_response.data = [feedback_data]
        self.mock_table.upsert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.create_feedback(
            session_id=session_id,
            user_id=user_id,
            rating=5,
            mood_delta=2,
        )
        
        assert result == feedback_data

    def test_get_feedback(self):
        """Test getting feedback for a session."""
        session_id = uuid4()
        feedback_data = {
            "id": str(uuid4()),
            "session_id": str(session_id),
            "rating": 4,
            "mood_delta": 1,
        }
        
        mock_response = MagicMock()
        mock_response.data = feedback_data
        self.mock_table.select.return_value.eq.return_value.maybe_single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_feedback(session_id)
        
        assert result == feedback_data

    def test_get_feedback_not_found(self):
        """Test getting feedback that doesn't exist returns None."""
        session_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = None
        self.mock_table.select.return_value.eq.return_value.maybe_single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_feedback(session_id)
        
        assert result is None


class TestSupabaseClientModeration:
    """Tests for moderation queue operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_create_moderation_item(self):
        """Test creating a moderation queue item."""
        violations = [{"category": "safety", "detail": "Contains banned term"}]
        moderation_data = {
            "id": str(uuid4()),
            "violations": violations,
            "content": "Test content",
            "content_type": "story",
            "status": "pending",
        }
        
        mock_response = MagicMock()
        mock_response.data = [moderation_data]
        self.mock_table.insert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.create_moderation_item(
            violations=violations,
            content="Test content",
            content_type="story",
        )
        
        assert result == moderation_data

    def test_get_moderation_items(self):
        """Test getting moderation items with filters."""
        items = [
            {"id": str(uuid4()), "status": "pending", "content_type": "story"},
            {"id": str(uuid4()), "status": "pending", "content_type": "story"},
        ]
        
        mock_response = MagicMock()
        mock_response.data = items
        chain = self.mock_table.select.return_value
        chain.eq.return_value = chain
        chain.order.return_value = chain
        chain.range.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.supabase_client.get_moderation_items(
            status="pending",
            content_type="story",
            limit=10,
            offset=0,
        )
        
        assert len(result) == 2

    def test_get_moderation_item(self):
        """Test getting a single moderation item."""
        item_id = uuid4()
        item_data = {
            "id": str(item_id),
            "status": "pending",
            "content": "Test",
        }
        
        mock_response = MagicMock()
        mock_response.data = item_data
        self.mock_table.select.return_value.eq.return_value.maybe_single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_moderation_item(item_id)
        
        assert result == item_data

    def test_resolve_moderation_item(self):
        """Test resolving a moderation item."""
        from datetime import datetime, timezone
        
        item_id = uuid4()
        resolved_by = uuid4()
        existing_item = {
            "id": str(item_id),
            "status": "pending",
            "audit_log": [],
        }
        
        updated_item = {
            "id": str(item_id),
            "status": "resolved",
            "resolved_by": str(resolved_by),
            "audit_log": [{"action": "resolved"}],
        }
        
        # Mock get_moderation_item
        with patch.object(self.supabase_client, 'get_moderation_item', return_value=existing_item):
            mock_response = MagicMock()
            mock_response.data = [updated_item]
            self.mock_table.update.return_value.eq.return_value.execute.return_value = mock_response
            
            result = self.supabase_client.resolve_moderation_item(
                item_id=item_id,
                resolved_by=resolved_by,
                resolution="resolved",
                notes="Approved",
            )
        
        assert result == updated_item

    def test_resolve_moderation_item_invalid_resolution(self):
        """Test resolving with invalid resolution raises ValueError."""
        item_id = uuid4()
        resolved_by = uuid4()
        
        with pytest.raises(ValueError, match="resolution must be"):
            self.supabase_client.resolve_moderation_item(
                item_id=item_id,
                resolved_by=resolved_by,
                resolution="invalid",
            )

    def test_resolve_moderation_item_not_found(self):
        """Test resolving a non-existent item raises ValueError."""
        item_id = uuid4()
        resolved_by = uuid4()
        
        with patch.object(self.supabase_client, 'get_moderation_item', return_value=None):
            with pytest.raises(ValueError, match="not found"):
                self.supabase_client.resolve_moderation_item(
                    item_id=item_id,
                    resolved_by=resolved_by,
                    resolution="resolved",
                )


class TestSupabaseClientPurge:
    """Tests for expired asset purge operations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_settings = MagicMock(spec=Settings)
        self.mock_settings.supabase_url = "https://test.supabase.co"
        self.mock_settings.supabase_service_role_key = "test_key"
        
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_storage = MagicMock()
        self.mock_bucket = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        self.mock_client.storage.from_.return_value = self.mock_bucket
        
        with patch('app.supabase_client.create_client', return_value=self.mock_client):
            self.supabase_client = SupabaseClient(self.mock_settings)

    def test_get_expired_session_assets(self):
        """Test getting expired session assets."""
        from datetime import datetime, timedelta, timezone
        
        assets = [
            {"id": str(uuid4()), "asset_url": "https://test.com/old.png", "asset_type": "frame"},
        ]
        
        mock_response = MagicMock()
        mock_response.data = assets
        chain = self.mock_table.select.return_value
        chain.lt.return_value = chain
        chain.order.return_value = chain
        chain.execute.return_value = mock_response
        
        result = self.supabase_client.get_expired_session_assets(days_old=7)
        
        assert len(result) == 1

    def test_purge_expired_assets(self):
        """Test purging expired assets."""
        from datetime import datetime, timedelta, timezone
        
        asset_id = uuid4()
        assets = [
            {
                "id": str(asset_id),
                "asset_url": "https://test.supabase.co/storage/v1/object/public/frames/old.png",
                "asset_type": "frame",
            }
        ]
        
        # Mock expired assets query
        mock_response = MagicMock()
        mock_response.data = assets
        chain = self.mock_table.select.return_value
        chain.lt.return_value = chain
        chain.order.return_value = chain
        chain.range.return_value = chain
        chain.execute.return_value = mock_response
        
        # Mock delete operations
        delete_response = MagicMock()
        delete_response.data = [{"id": str(asset_id)}]
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = delete_response
        
        # Mock storage delete
        storage_response = MagicMock()
        storage_response.error = None
        self.mock_bucket.remove.return_value = storage_response
        
        result = self.supabase_client.purge_expired_assets(days_old=7, batch_size=100)
        
        assert result["assets_found"] == 1
        assert result["assets_deleted"] == 1
        assert result["storage_deleted"] == 1
        assert result["storage_errors"] == 0

    def test_get_profile(self):
        """Test getting a profile by user ID."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "calm",
            "routine": "reading",
            "preferences": ["nature", "ocean"],
        }
        
        mock_response = MagicMock()
        mock_response.data = profile_data
        self.mock_table.select.return_value.eq.return_value.maybe_single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_profile(user_id)
        
        assert result == profile_data

    def test_get_profile_not_found(self):
        """Test getting a profile that doesn't exist returns None."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = None
        self.mock_table.select.return_value.eq.return_value.maybe_single.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.get_profile(user_id)
        
        assert result is None

    def test_create_profile(self):
        """Test creating a new profile."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "calm",
            "routine": "reading",
            "preferences": ["nature"],
            "favorite_characters": [],
            "calming_elements": [],
        }
        
        mock_response = MagicMock()
        mock_response.data = [profile_data]
        self.mock_table.insert.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.create_profile(
            user_id=user_id,
            mood="calm",
            routine="reading",
            preferences=["nature"],
        )
        
        assert result == profile_data

    def test_update_profile(self):
        """Test updating an existing profile."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "relaxed",
            "routine": "meditation",
        }
        
        mock_response = MagicMock()
        mock_response.data = [profile_data]
        self.mock_table.update.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.update_profile(
            user_id=user_id,
            mood="relaxed",
            routine="meditation",
        )
        
        assert result == profile_data

    def test_update_profile_no_changes(self):
        """Test updating profile with no changes returns existing profile."""
        user_id = uuid4()
        profile_data = {
            "id": str(user_id),
            "mood": "calm",
        }
        
        # Mock get_profile to return existing profile
        with patch.object(self.supabase_client, 'get_profile', return_value=profile_data):
            result = self.supabase_client.update_profile(user_id=user_id)
        
        assert result == profile_data

    def test_delete_profile(self):
        """Test deleting a profile."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = [{"id": str(user_id)}]
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.delete_profile(user_id)
        
        assert result is True

    def test_delete_profile_not_found(self):
        """Test deleting a profile that doesn't exist returns False."""
        user_id = uuid4()
        
        mock_response = MagicMock()
        mock_response.data = []
        self.mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
        
        result = self.supabase_client.delete_profile(user_id)
        
        assert result is False

