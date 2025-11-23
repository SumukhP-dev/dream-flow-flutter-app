"""
Unit tests for service generators and utility functions.

Tests ensure:
- VisualGenerator uploads frames to Supabase Storage and handles fallbacks
- NarrationGenerator uploads audio to Supabase Storage
- HuggingFace calls are async-safe with timeouts and retries
- Scene chunking and paragraph distribution works correctly
- Error handling and fallback mechanisms work properly
"""

import asyncio
import io
import pytest
from unittest.mock import AsyncMock, MagicMock, patch, Mock
from uuid import uuid4
from pathlib import Path

from PIL import Image

from app.prompting import PromptBuilder, PromptContext
from app.schemas import UserProfile
from app.services import (
    VisualGenerator,
    NarrationGenerator,
    StoryGenerator,
    _distribute_paragraphs,
    _truncate_caption,
    _run_with_retry,
    DEFAULT_TIMEOUT,
    MAX_RETRIES,
)
from app.exceptions import (
    HuggingFaceError,
    HuggingFaceTimeoutError,
    HuggingFaceRateLimitError,
    HuggingFaceConnectionError,
    HuggingFaceModelError,
)


class TestDistributeParagraphs:
    """Tests for _distribute_paragraphs utility function."""

    def test_distribute_paragraphs_evenly(self):
        """Test paragraphs are distributed evenly across scenes."""
        paragraphs = ["Para 1", "Para 2", "Para 3", "Para 4"]
        result = _distribute_paragraphs(paragraphs, 2)
        
        assert len(result) == 2
        assert "Para 1 Para 2" in result[0]
        assert "Para 3 Para 4" in result[1]

    def test_distribute_paragraphs_with_remainder(self):
        """Test paragraphs with remainder are distributed correctly."""
        paragraphs = ["Para 1", "Para 2", "Para 3", "Para 4", "Para 5"]
        result = _distribute_paragraphs(paragraphs, 3)
        
        assert len(result) == 3
        # First two scenes get 2 paragraphs, last gets 1
        assert "Para 1 Para 2" in result[0]
        assert "Para 3 Para 4" in result[1]
        assert "Para 5" in result[2]

    def test_distribute_paragraphs_fewer_than_scenes(self):
        """Test when paragraphs are fewer than num_scenes."""
        paragraphs = ["Para 1", "Para 2"]
        result = _distribute_paragraphs(paragraphs, 4)
        
        assert len(result) == 2
        assert result == paragraphs

    def test_distribute_paragraphs_empty(self):
        """Test with empty paragraphs list."""
        result = _distribute_paragraphs([], 3)
        assert result == []

    def test_distribute_paragraphs_zero_scenes(self):
        """Test with zero num_scenes defaults to 1."""
        paragraphs = ["Para 1", "Para 2"]
        result = _distribute_paragraphs(paragraphs, 0)
        
        assert len(result) == 1
        assert "Para 1 Para 2" in result[0]

    def test_distribute_paragraphs_single_paragraph(self):
        """Test with single paragraph."""
        paragraphs = ["Single paragraph"]
        result = _distribute_paragraphs(paragraphs, 3)
        
        assert len(result) == 1
        assert result == paragraphs


class TestTruncateCaption:
    """Tests for _truncate_caption utility function."""

    def test_truncate_caption_short_text(self):
        """Test short text is not truncated."""
        text = "Short text"
        result = _truncate_caption(text)
        assert result == text

    def test_truncate_caption_long_text(self):
        """Test long text is truncated with ellipsis."""
        text = "A" * 250
        result = _truncate_caption(text, max_length=200)
        
        assert len(result) == 200
        assert result.endswith("...")
        assert len(result) <= 200

    def test_truncate_caption_exact_length(self):
        """Test text at exact max_length is not truncated."""
        text = "A" * 200
        result = _truncate_caption(text, max_length=200)
        assert result == text


class TestRunWithRetry:
    """Tests for _run_with_retry async-safe timeout and retry logic."""

    @pytest.mark.asyncio
    async def test_run_with_retry_success_first_attempt(self):
        """Test successful execution on first attempt."""
        def func():
            return "success"
        
        result = await _run_with_retry(
            func,
            model_id="test-model",
            operation="test_operation",
            timeout=1.0,
            max_retries=3,
        )
        
        assert result == "success"

    @pytest.mark.asyncio
    async def test_run_with_retry_success_after_retry(self):
        """Test successful execution after retry."""
        attempt_count = [0]
        
        def func():
            attempt_count[0] += 1
            if attempt_count[0] < 2:
                raise ConnectionError("Connection failed")
            return "success"
        
        result = await _run_with_retry(
            func,
            model_id="test-model",
            operation="test_operation",
            timeout=1.0,
            max_retries=3,
        )
        
        assert result == "success"
        assert attempt_count[0] == 2

    @pytest.mark.asyncio
    async def test_run_with_retry_timeout_error(self):
        """Test timeout error is raised after max retries."""
        def func():
            # Simulate slow operation
            import time
            time.sleep(2)
            return "success"
        
        with pytest.raises(HuggingFaceTimeoutError) as exc_info:
            await _run_with_retry(
                func,
                model_id="test-model",
                operation="test_operation",
                timeout=0.1,  # Very short timeout
                max_retries=2,
            )
        
        assert "test-model" in str(exc_info.value)
        assert "timed out" in str(exc_info.value).lower()

    @pytest.mark.asyncio
    async def test_run_with_retry_rate_limit_error(self):
        """Test rate limit error is retried."""
        attempt_count = [0]
        
        def func():
            attempt_count[0] += 1
            if attempt_count[0] < 2:
                raise Exception("Rate limit exceeded")
            return "success"
        
        # Mock _handle_hf_error to return rate limit error
        with patch('app.services._handle_hf_error') as mock_handle:
            mock_handle.return_value = HuggingFaceRateLimitError(
                "Rate limit exceeded",
                model_id="test-model",
                status_code=429,
            )
            
            result = await _run_with_retry(
                func,
                model_id="test-model",
                operation="test_operation",
                timeout=1.0,
                max_retries=3,
            )
            
            # Should retry and eventually succeed
            assert result == "success"

    @pytest.mark.asyncio
    async def test_run_with_retry_connection_error(self):
        """Test connection error is retried."""
        attempt_count = [0]
        
        def func():
            attempt_count[0] += 1
            if attempt_count[0] < 2:
                raise ConnectionError("Connection failed")
            return "success"
        
        with patch('app.services._handle_hf_error') as mock_handle:
            mock_handle.return_value = HuggingFaceConnectionError(
                "Connection failed",
                model_id="test-model",
            )
            
            result = await _run_with_retry(
                func,
                model_id="test-model",
                operation="test_operation",
                timeout=1.0,
                max_retries=3,
            )
            
            assert result == "success"

    @pytest.mark.asyncio
    async def test_run_with_retry_max_retries_exceeded(self):
        """Test that max retries are respected."""
        def func():
            raise ConnectionError("Connection failed")
        
        with patch('app.services._handle_hf_error') as mock_handle:
            mock_handle.return_value = HuggingFaceConnectionError(
                "Connection failed",
                model_id="test-model",
            )
            
            with pytest.raises(HuggingFaceConnectionError):
                await _run_with_retry(
                    func,
                    model_id="test-model",
                    operation="test_operation",
                    timeout=1.0,
                    max_retries=2,
                )


class TestVisualGenerator:
    """Tests for VisualGenerator class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.builder = PromptBuilder()
        self.generator = VisualGenerator(prompt_builder=self.builder)

    @pytest.mark.asyncio
    async def test_create_frames_with_supabase_upload(self):
        """Test create_frames uploads to Supabase Storage and returns URLs."""
        story = "Paragraph 1\n\nParagraph 2\n\nParagraph 3"
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock Supabase client
        mock_supabase = MagicMock()
        mock_supabase.upload_frame.return_value = "https://supabase.co/storage/frames/test.png"
        
        # Create valid PNG image bytes
        image = Image.new("RGB", (1280, 720), color=(255, 0, 0))
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        mock_image_bytes = buffer.getvalue()
        
        with patch.object(self.generator.client, 'text_to_image', return_value=mock_image_bytes):
            result = await self.generator.create_frames(
                story, context, num_scenes=2, supabase_client=mock_supabase
            )
        
        # Should return list of URLs
        assert len(result) == 2
        assert all(url.startswith("http") for url in result)
        assert mock_supabase.upload_frame.call_count == 2

    @pytest.mark.asyncio
    async def test_create_frames_without_supabase_fallback(self):
        """Test create_frames falls back to local paths when no Supabase client."""
        import tempfile
        
        story = "Paragraph 1\n\nParagraph 2"
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Create valid PNG image bytes
        image = Image.new("RGB", (1280, 720), color=(255, 0, 0))
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        mock_image_bytes = buffer.getvalue()
        
        # Use temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.object(self.generator.client, 'text_to_image', return_value=mock_image_bytes):
                with patch('app.services.settings') as mock_settings:
                    mock_settings.frames_dir = Path(temp_dir)
                    result = await self.generator.create_frames(
                        story, context, num_scenes=2, supabase_client=None
                    )
            
            # Should return list of local paths as strings
            assert len(result) == 2
            assert all(isinstance(url, str) for url in result)

    @pytest.mark.asyncio
    async def test_create_frames_placeholder_fallback(self):
        """Test create_frames falls back to placeholder on HuggingFace error."""
        story = "Paragraph 1"
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock Supabase client
        mock_supabase = MagicMock()
        mock_supabase.upload_frame.return_value = "https://supabase.co/storage/frames/placeholder.png"
        
        # Mock HuggingFace to raise error
        with patch.object(self.generator.client, 'text_to_image', side_effect=HuggingFaceError("API error", model_id="test")):
            result = await self.generator.create_frames(
                story, context, num_scenes=1, supabase_client=mock_supabase
            )
        
        # Should still return URL (placeholder)
        assert len(result) == 1
        assert result[0].startswith("http")
        assert mock_supabase.upload_frame.call_count == 1

    @pytest.mark.asyncio
    async def test_create_frames_chunking(self):
        """Test create_frames correctly chunks story into scenes."""
        story = "Para 1\n\nPara 2\n\nPara 3\n\nPara 4\n\nPara 5"
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock Supabase client
        mock_supabase = MagicMock()
        mock_supabase.upload_frame.return_value = "https://supabase.co/storage/frames/test.png"
        
        # Create valid PNG image bytes
        image = Image.new("RGB", (1280, 720), color=(255, 0, 0))
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        mock_image_bytes = buffer.getvalue()
        
        with patch.object(self.generator.client, 'text_to_image', return_value=mock_image_bytes):
            result = await self.generator.create_frames(
                story, context, num_scenes=3, supabase_client=mock_supabase
            )
        
        # Should create 3 frames (chunked from 5 paragraphs)
        assert len(result) == 3
        assert mock_supabase.upload_frame.call_count == 3

    @pytest.mark.asyncio
    async def test_create_frames_with_timeout(self):
        """Test create_frames handles timeout errors."""
        story = "Paragraph 1"
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock Supabase client
        mock_supabase = MagicMock()
        mock_supabase.upload_frame.return_value = "https://supabase.co/storage/frames/placeholder.png"
        
        # Mock slow HuggingFace call that times out
        def slow_image():
            import time
            time.sleep(2)
            return b"fake_image_data"
        
        with patch.object(self.generator.client, 'text_to_image', side_effect=slow_image):
            # Should fall back to placeholder due to timeout
            result = await self.generator.create_frames(
                story, context, num_scenes=1, supabase_client=mock_supabase
            )
        
        # Should return placeholder URL
        assert len(result) == 1
        assert result[0].startswith("http")

    def test_create_placeholder_image(self):
        """Test placeholder image creation."""
        image = self.generator._create_placeholder_image()
        
        assert isinstance(image, Image.Image)
        assert image.size == (1280, 720)
        assert image.mode == "RGB"

    def test_overlay_caption(self):
        """Test caption overlay on image."""
        image = Image.new("RGB", (1280, 720), color=(255, 255, 255))
        text = "Test caption text"
        
        result = self.generator._overlay_caption(image, text)
        
        assert isinstance(result, Image.Image)
        assert result.size == image.size


class TestNarrationGenerator:
    """Tests for NarrationGenerator class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.builder = PromptBuilder()
        self.generator = NarrationGenerator(prompt_builder=self.builder)

    @pytest.mark.asyncio
    async def test_synthesize_with_supabase_upload(self):
        """Test synthesize uploads to Supabase Storage and returns URL."""
        story = "Once upon a time..."
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock Supabase client
        mock_supabase = MagicMock()
        mock_supabase.upload_audio.return_value = "https://supabase.co/storage/audio/test.wav"
        
        # Mock HuggingFace client - need to mock the entire client since text_to_audio might not exist
        mock_audio_response = {"audio": b"fake_audio_data"}
        mock_client = MagicMock()
        mock_client.text_to_audio = MagicMock(return_value=mock_audio_response)
        self.generator.client = mock_client
        
        result = await self.generator.synthesize(
            story, context, voice="alloy", supabase_client=mock_supabase
        )
        
        assert result.startswith("http")
        assert mock_supabase.upload_audio.call_count == 1

    @pytest.mark.asyncio
    async def test_synthesize_without_supabase_fallback(self):
        """Test synthesize falls back to local path when no Supabase client."""
        import tempfile
        
        story = "Once upon a time..."
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock HuggingFace client
        mock_audio_response = {"audio": b"fake_audio_data"}
        mock_client = MagicMock()
        mock_client.text_to_audio = MagicMock(return_value=mock_audio_response)
        self.generator.client = mock_client
        
        # Use temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            with patch('app.services.settings') as mock_settings:
                mock_settings.audio_dir = Path(temp_dir)
                result = await self.generator.synthesize(
                    story, context, voice="alloy", supabase_client=None
                )
            
            assert isinstance(result, str)
            assert not result.startswith("http")

    @pytest.mark.asyncio
    async def test_synthesize_with_timeout(self):
        """Test synthesize handles timeout errors."""
        story = "Once upon a time..."
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock slow HuggingFace call
        def slow_audio():
            import time
            time.sleep(2)
            return {"audio": b"fake_audio_data"}
        
        mock_client = MagicMock()
        mock_client.text_to_audio = MagicMock(side_effect=slow_audio)
        self.generator.client = mock_client
        
        with pytest.raises(HuggingFaceTimeoutError):
            await self.generator.synthesize(
                story, context, voice="alloy", supabase_client=None
            )

    @pytest.mark.asyncio
    async def test_synthesize_with_retry(self):
        """Test synthesize retries on connection errors."""
        import tempfile
        
        story = "Once upon a time..."
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        attempt_count = [0]
        
        def audio_with_retry(text, voice):
            attempt_count[0] += 1
            if attempt_count[0] < 2:
                raise ConnectionError("Connection failed")
            return {"audio": b"fake_audio_data"}
        
        mock_client = MagicMock()
        mock_client.text_to_audio = MagicMock(side_effect=audio_with_retry)
        self.generator.client = mock_client
        
        # Use temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            # Mock sleep to speed up test
            with patch('app.services.asyncio.sleep', new_callable=AsyncMock):
                with patch('app.services.settings') as mock_settings:
                    mock_settings.audio_dir = Path(temp_dir)
                    result = await self.generator.synthesize(
                        story, context, voice="alloy", supabase_client=None
                    )
                
                assert isinstance(result, str)
                # Should have retried, so attempt_count should be 2
                assert attempt_count[0] == 2


class TestStoryGeneratorTimeout:
    """Tests for StoryGenerator timeout and retry behavior."""

    def setup_method(self):
        """Set up test fixtures."""
        self.builder = PromptBuilder()
        self.generator = StoryGenerator(prompt_builder=self.builder)

    @pytest.mark.asyncio
    async def test_generate_with_timeout(self):
        """Test generate handles timeout errors."""
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        # Mock slow HuggingFace call
        def slow_generate():
            import time
            time.sleep(2)
            return "Generated story"
        
        with patch.object(self.generator.client, 'text_generation', side_effect=slow_generate):
            with pytest.raises(HuggingFaceTimeoutError):
                await self.generator.generate(context)

    @pytest.mark.asyncio
    async def test_generate_with_retry(self):
        """Test generate retries on connection errors."""
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            target_length=400,
            profile=None,
        )
        
        attempt_count = [0]
        
        def generate_with_retry(prompt, **kwargs):
            attempt_count[0] += 1
            if attempt_count[0] < 2:
                raise ConnectionError("Connection failed")
            return "Generated story"
        
        # Mock the client method properly
        original_client = self.generator.client
        mock_client = MagicMock()
        mock_client.text_generation = MagicMock(side_effect=generate_with_retry)
        self.generator.client = mock_client
        
        try:
            # Mock sleep to speed up test
            with patch('app.services.asyncio.sleep', new_callable=AsyncMock):
                result = await self.generator.generate(context)
                
                assert result == "Generated story"
                # Should have retried, so attempt_count should be 2
                assert attempt_count[0] == 2
        finally:
            # Restore original client
            self.generator.client = original_client

