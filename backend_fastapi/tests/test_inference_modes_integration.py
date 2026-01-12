"""
Integration tests for AI inference modes.

Tests both HuggingFace (cloud) and local (GGUF) inference modes
to ensure complete story generation works end-to-end with:
- Story text generation
- Image/frame generation
- Audio narration generation

Run with:
    # Test cloud mode
    AI_INFERENCE_MODE=cloud_only pytest tests/test_inference_modes_integration.py -v -k cloud

    # Test local mode
    AI_INFERENCE_MODE=server_only pytest tests/test_inference_modes_integration.py -v -k local

    # Test fallback
    AI_INFERENCE_MODE=cloud_first pytest tests/test_inference_modes_integration.py -v -k fallback
"""

import os
import pytest
import asyncio
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock
from uuid import uuid4

from app.shared.config import Settings, get_settings
from app.core.prompting import PromptBuilder, PromptContext
from app.core.guardrails import PromptSanitizer


# Mark all tests in this module as integration tests
pytestmark = pytest.mark.integration


class TestCloudInferenceMode:
    """Integration tests for cloud_only mode (HuggingFace APIs)."""

    @pytest.fixture
    def cloud_settings(self):
        """Create settings for cloud-only inference."""
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': 'cloud_only',
            'HUGGINGFACE_API_TOKEN': os.getenv('HUGGINGFACE_API_TOKEN', 'test_token'),
            'SUPABASE_SERVICE_ROLE_KEY': 'test_key',
            'USE_PLACEHOLDERS_ONLY': 'false',
        }):
            settings = Settings()
            yield settings

    @pytest.fixture
    def prompt_builder(self):
        """Create prompt builder for testing."""
        sanitizer = PromptSanitizer()
        return PromptBuilder(sanitizer=sanitizer)

    @pytest.fixture
    def test_context(self):
        """Create test prompt context."""
        return PromptContext(
            prompt="A peaceful bedtime story about the ocean",
            theme="ocean",
            mood="calm",
            target_length=300,
            child_age_range="4-6",
            preferences=["ocean", "waves", "relaxation"],
        )

    @pytest.mark.asyncio
    async def test_cloud_story_generation(self, cloud_settings, prompt_builder, test_context):
        """Test story generation using HuggingFace cloud API."""
        from app.core.services import StoryGenerator

        # Initialize generator
        story_gen = StoryGenerator(prompt_builder=prompt_builder)

        # Generate story
        story_text = await story_gen.generate(test_context)

        # Assertions
        assert story_text is not None
        assert isinstance(story_text, str)
        assert len(story_text) > 50, "Story should be substantial"
        assert any(word in story_text.lower() for word in ['ocean', 'sea', 'water', 'wave']), \
            "Story should contain ocean-related content"

        print(f"\n✅ Cloud Story Generated ({len(story_text)} chars):")
        print(f"   {story_text[:100]}...")

    @pytest.mark.asyncio
    async def test_cloud_narration_generation(self, cloud_settings, prompt_builder, test_context):
        """Test audio narration using HuggingFace TTS API."""
        from app.core.services import NarrationGenerator

        story_text = "Once upon a time, by the peaceful ocean, a little turtle found a friend."

        # Initialize generator
        narration_gen = NarrationGenerator(prompt_builder=prompt_builder)

        # Generate narration (mock Supabase client)
        mock_supabase = MagicMock()
        mock_supabase.upload_audio = AsyncMock(return_value="https://test.supabase.co/audio/test.wav")

        audio_url = await narration_gen.synthesize(
            story_text,
            test_context,
            voice="alloy",
            supabase_client=mock_supabase
        )

        # Assertions
        assert audio_url is not None
        assert isinstance(audio_url, str)
        # Could be local path or URL depending on implementation
        assert len(audio_url) > 0

        print(f"\n✅ Cloud Narration Generated:")
        print(f"   Audio URL: {audio_url[:80]}...")

    @pytest.mark.asyncio
    async def test_cloud_visual_generation(self, cloud_settings, prompt_builder, test_context):
        """Test image generation using HuggingFace image API."""
        from app.core.services import VisualGenerator

        story_text = "Once upon a time, by the peaceful ocean."
        num_scenes = 2

        # Initialize generator
        visual_gen = VisualGenerator(prompt_builder=prompt_builder)

        # Generate frames (mock Supabase client)
        mock_supabase = MagicMock()
        mock_supabase.upload_frame = AsyncMock(
            side_effect=lambda data, filename: f"https://test.supabase.co/frames/{filename}"
        )

        frames = await visual_gen.create_frames(
            story_text,
            test_context,
            num_scenes=num_scenes,
            supabase_client=mock_supabase,
        )

        # Assertions
        assert frames is not None
        assert isinstance(frames, list)
        assert len(frames) == num_scenes, f"Expected {num_scenes} frames, got {len(frames)}"
        for frame_url in frames:
            assert isinstance(frame_url, str)
            assert len(frame_url) > 0

        print(f"\n✅ Cloud Images Generated ({len(frames)} frames):")
        for i, url in enumerate(frames, 1):
            print(f"   Frame {i}: {url[:80]}...")

    @pytest.mark.asyncio
    async def test_cloud_full_story_pipeline(self, cloud_settings, prompt_builder, test_context):
        """Test complete story generation pipeline with cloud inference."""
        from app.core.services import StoryGenerator, NarrationGenerator, VisualGenerator

        # Initialize all generators
        story_gen = StoryGenerator(prompt_builder=prompt_builder)
        narration_gen = NarrationGenerator(prompt_builder=prompt_builder)
        visual_gen = VisualGenerator(prompt_builder=prompt_builder)

        # Mock Supabase
        mock_supabase = MagicMock()
        mock_supabase.upload_audio = AsyncMock(return_value="https://test.supabase.co/audio/test.wav")
        mock_supabase.upload_frame = AsyncMock(
            side_effect=lambda data, filename: f"https://test.supabase.co/frames/{filename}"
        )

        # Step 1: Generate story
        story_text = await story_gen.generate(test_context)
        assert story_text and len(story_text) > 50

        # Step 2: Generate narration (parallel with images)
        narration_task = narration_gen.synthesize(
            story_text,
            test_context,
            voice="alloy",
            supabase_client=mock_supabase
        )

        # Step 3: Generate images
        frames_task = visual_gen.create_frames(
            story_text,
            test_context,
            num_scenes=2,
            supabase_client=mock_supabase,
        )

        # Wait for both
        audio_url, frames = await asyncio.gather(narration_task, frames_task)

        # Final assertions
        assert audio_url is not None
        assert frames is not None and len(frames) == 2

        print(f"\n✅ Complete Cloud Pipeline Success:")
        print(f"   Story: {len(story_text)} chars")
        print(f"   Audio: {audio_url[:80]}...")
        print(f"   Frames: {len(frames)} images")


class TestLocalInferenceMode:
    """Integration tests for server_only mode (local GGUF models)."""

    @pytest.fixture
    def local_settings(self):
        """Create settings for local-only inference."""
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': 'server_only',
            'LOCAL_INFERENCE': 'true',
            'LOCAL_MODEL_PATH': str(Path(__file__).parent.parent / 'models' / 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf'),
            'LOCAL_STORY_MODEL': 'tinyllama',
            'EDGE_TTS_VOICE': 'en-US-AriaNeural',
            'USE_PLACEHOLDERS_ONLY': 'false',
            'LOCAL_IMAGE_ENABLED': 'true',
            'SUPABASE_SERVICE_ROLE_KEY': 'test_key',
        }):
            settings = Settings()
            yield settings

    @pytest.fixture
    def prompt_builder(self):
        """Create prompt builder for testing."""
        sanitizer = PromptSanitizer()
        return PromptBuilder(sanitizer=sanitizer)

    @pytest.fixture
    def test_context(self):
        """Create test prompt context."""
        return PromptContext(
            prompt="A short bedtime story about a friendly turtle",
            theme="ocean",
            mood="calm",
            target_length=200,  # Shorter for local model
            child_age_range="4-6",
            preferences=["animals", "ocean"],
        )

    @pytest.mark.asyncio
    @pytest.mark.skipif(
        not Path(__file__).parent.parent.joinpath('models', 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf').exists(),
        reason="Local model not available"
    )
    async def test_local_story_generation(self, local_settings, prompt_builder, test_context):
        """Test story generation using local GGUF model."""
        from app.core.local_services import LocalStoryGenerator

        # Initialize generator
        story_gen = LocalStoryGenerator(prompt_builder=prompt_builder)

        # Generate story
        story_text = await story_gen.generate(test_context)

        # Assertions
        assert story_text is not None
        assert isinstance(story_text, str)
        assert len(story_text) > 30, "Story should have some content"

        print(f"\n✅ Local Story Generated ({len(story_text)} chars):")
        print(f"   {story_text[:100]}...")

    @pytest.mark.asyncio
    async def test_local_narration_generation(self, local_settings, prompt_builder, test_context):
        """Test audio narration using edge-tts (local TTS)."""
        from app.core.local_services import LocalNarrationGenerator

        story_text = "A friendly turtle swam in the ocean."

        # Initialize generator
        narration_gen = LocalNarrationGenerator(prompt_builder=prompt_builder)

        # Generate narration (mock Supabase client)
        mock_supabase = MagicMock()
        mock_supabase.upload_audio = AsyncMock(return_value="https://test.supabase.co/audio/test.wav")

        audio_url = await narration_gen.synthesize(
            story_text,
            test_context,
            voice="en-US-AriaNeural",
            supabase_client=mock_supabase
        )

        # Assertions
        assert audio_url is not None
        assert isinstance(audio_url, str)
        assert len(audio_url) > 0

        print(f"\n✅ Local Narration Generated:")
        print(f"   Audio URL: {audio_url[:80]}...")

    @pytest.mark.asyncio
    @pytest.mark.skipif(
        not os.getenv('TORCH_AVAILABLE', 'false') == 'true',
        reason="PyTorch not available for local image generation"
    )
    async def test_local_visual_generation(self, local_settings, prompt_builder, test_context):
        """Test image generation using local Stable Diffusion."""
        from app.core.local_services import LocalVisualGenerator

        story_text = "A friendly turtle in the ocean."
        num_scenes = 1  # Just one for speed

        # Initialize generator
        visual_gen = LocalVisualGenerator(prompt_builder=prompt_builder)

        # Generate frames (mock Supabase client)
        mock_supabase = MagicMock()
        mock_supabase.upload_frame = AsyncMock(
            side_effect=lambda data, filename: f"https://test.supabase.co/frames/{filename}"
        )

        frames = await visual_gen.create_frames(
            story_text,
            test_context,
            num_scenes=num_scenes,
            supabase_client=mock_supabase,
        )

        # Assertions
        assert frames is not None
        assert isinstance(frames, list)
        assert len(frames) >= num_scenes  # May include placeholders

        print(f"\n✅ Local Images Generated ({len(frames)} frames):")
        for i, url in enumerate(frames, 1):
            print(f"   Frame {i}: {url[:80]}...")

    @pytest.mark.asyncio
    @pytest.mark.skipif(
        not Path(__file__).parent.parent.joinpath('models', 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf').exists(),
        reason="Local model not available"
    )
    async def test_local_full_story_pipeline(self, local_settings, prompt_builder, test_context):
        """Test complete story generation pipeline with local inference."""
        from app.core.local_services import (
            LocalStoryGenerator,
            LocalNarrationGenerator,
            LocalVisualGenerator
        )

        # Initialize all generators
        story_gen = LocalStoryGenerator(prompt_builder=prompt_builder)
        narration_gen = LocalNarrationGenerator(prompt_builder=prompt_builder)
        visual_gen = LocalVisualGenerator(prompt_builder=prompt_builder)

        # Mock Supabase
        mock_supabase = MagicMock()
        mock_supabase.upload_audio = AsyncMock(return_value="https://test.supabase.co/audio/test.wav")
        mock_supabase.upload_frame = AsyncMock(
            side_effect=lambda data, filename: f"https://test.supabase.co/frames/{filename}"
        )

        # Step 1: Generate story
        story_text = await story_gen.generate(test_context)
        assert story_text and len(story_text) > 30

        # Step 2: Generate narration (parallel with images)
        narration_task = narration_gen.synthesize(
            story_text,
            test_context,
            voice="en-US-AriaNeural",
            supabase_client=mock_supabase
        )

        # Step 3: Generate images
        frames_task = visual_gen.create_frames(
            story_text,
            test_context,
            num_scenes=1,  # Just one for speed
            supabase_client=mock_supabase,
        )

        # Wait for both
        audio_url, frames = await asyncio.gather(narration_task, frames_task)

        # Final assertions
        assert audio_url is not None
        assert frames is not None and len(frames) >= 1

        print(f"\n✅ Complete Local Pipeline Success:")
        print(f"   Story: {len(story_text)} chars")
        print(f"   Audio: {audio_url[:80]}...")
        print(f"   Frames: {len(frames)} images")


class TestFallbackBehavior:
    """Integration tests for fallback between cloud and local inference."""

    @pytest.fixture
    def cloud_first_settings(self):
        """Create settings for cloud_first mode (with fallback)."""
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': 'cloud_first',
            'HUGGINGFACE_API_TOKEN': 'invalid_token',  # Force failure
            'LOCAL_INFERENCE': 'true',
            'LOCAL_MODEL_PATH': str(Path(__file__).parent.parent / 'models' / 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf'),
            'SUPABASE_SERVICE_ROLE_KEY': 'test_key',
        }):
            settings = Settings()
            yield settings

    @pytest.fixture
    def prompt_builder(self):
        """Create prompt builder for testing."""
        sanitizer = PromptSanitizer()
        return PromptBuilder(sanitizer=sanitizer)

    @pytest.fixture
    def test_context(self):
        """Create test prompt context."""
        return PromptContext(
            prompt="A simple bedtime story",
            theme="ocean",
            mood="calm",
            target_length=150,
            child_age_range="4-6",
        )

    @pytest.mark.asyncio
    @pytest.mark.skipif(
        not Path(__file__).parent.parent.joinpath('models', 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf').exists(),
        reason="Local model not available for fallback test"
    )
    async def test_cloud_to_local_fallback_story(self, cloud_first_settings, prompt_builder, test_context):
        """Test fallback from cloud to local when cloud fails."""
        from app.core.services import get_generators

        # Get generators (should fallback to local)
        story_gen, narration_gen, visual_gen = get_generators(prompt_builder)

        # Verify we got local generator (not cloud)
        from app.core.local_services import LocalStoryGenerator
        assert isinstance(story_gen, LocalStoryGenerator), \
            "Should have fallen back to LocalStoryGenerator"

        # Generate story to verify it works
        story_text = await story_gen.generate(test_context)

        assert story_text is not None
        assert len(story_text) > 20

        print(f"\n✅ Fallback Success: Cloud → Local")
        print(f"   Generated story with local model after cloud failure")

    @pytest.mark.asyncio
    async def test_runtime_fallback_on_generation_failure(self, prompt_builder, test_context):
        """Test runtime fallback when primary generator fails during generation."""
        from app.dreamflow.main import _get_fallback_story_generator
        from app.core.services import StoryGenerator
        from app.core.local_services import LocalStoryGenerator

        # Simulate primary generator
        primary_gen = MagicMock(spec=StoryGenerator)
        type(primary_gen).__name__ = 'StoryGenerator'  # Mock the type name

        # Get fallback generator
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': 'cloud_first',
            'LOCAL_INFERENCE': 'true',
        }):
            # Mock local generator availability
            with patch('app.core.local_services.is_local_inference_available', return_value=True):
                with patch('app.core.local_services.LocalStoryGenerator') as MockLocalGen:
                    mock_instance = MagicMock()
                    MockLocalGen.return_value = mock_instance

                    fallback_gen = _get_fallback_story_generator(prompt_builder, primary_gen)

                    # Should have attempted to create LocalStoryGenerator
                    assert fallback_gen is not None or MockLocalGen.called

        print(f"\n✅ Runtime Fallback Logic Works")
        print(f"   Attempted local fallback when cloud generator failed")

    @pytest.mark.asyncio
    async def test_no_fallback_in_only_modes(self, prompt_builder, test_context):
        """Test that *_only modes don't fallback."""
        from app.dreamflow.main import _get_fallback_story_generator
        from app.core.services import StoryGenerator

        primary_gen = MagicMock(spec=StoryGenerator)
        type(primary_gen).__name__ = 'StoryGenerator'

        # Test cloud_only mode (no fallback)
        with patch.dict(os.environ, {'AI_INFERENCE_MODE': 'cloud_only'}):
            fallback_gen = _get_fallback_story_generator(prompt_builder, primary_gen)

            # Should return None (fallback disabled)
            assert fallback_gen is None

        print(f"\n✅ *_only Modes Correctly Disable Fallback")


class TestInferenceModeConfiguration:
    """Tests for proper inference mode initialization and configuration."""

    def test_cloud_only_mode_initialization(self):
        """Test that cloud_only mode initializes without local dependencies."""
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': 'cloud_only',
            'HUGGINGFACE_API_TOKEN': 'test_token',
            'SUPABASE_SERVICE_ROLE_KEY': 'test_key',
        }):
            from app.core.services import get_inference_config

            config = get_inference_config('cloud_only')

            assert config['primary'] == 'cloud'
            assert config['fallback_chain'] == ['cloud']
            assert config['allow_fallback'] is False

        print(f"\n✅ cloud_only Config: {config}")

    def test_cloud_first_mode_initialization(self):
        """Test that cloud_first mode has proper fallback chain."""
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': 'cloud_first',
            'SUPABASE_SERVICE_ROLE_KEY': 'test_key',
        }):
            from app.core.services import get_inference_config

            config = get_inference_config('cloud_first')

            assert config['primary'] == 'cloud'
            assert 'cloud' in config['fallback_chain']
            assert 'local' in config['fallback_chain']
            assert config['allow_fallback'] is True

        print(f"\n✅ cloud_first Config: {config}")

    def test_server_only_mode_initialization(self):
        """Test that server_only mode initializes without cloud dependencies."""
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': 'server_only',
            'LOCAL_INFERENCE': 'true',
            'SUPABASE_SERVICE_ROLE_KEY': 'test_key',
        }):
            from app.core.services import get_inference_config

            config = get_inference_config('server_only')

            assert config['primary'] == 'local'
            assert config['fallback_chain'] == ['local']
            assert config['allow_fallback'] is False

        print(f"\n✅ server_only Config: {config}")


if __name__ == "__main__":
    # Run tests with: python -m pytest tests/test_inference_modes_integration.py -v
    pytest.main([__file__, "-v", "-s"])
