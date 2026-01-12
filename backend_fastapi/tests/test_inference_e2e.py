#!/usr/bin/env python3
"""
Direct integration test script for AI inference modes.

Tests both cloud and local inference end-to-end without pytest.
Can be run directly: python test_inference_e2e.py

Requirements:
- For cloud tests: HUGGINGFACE_API_TOKEN env var
- For local tests: Local model files in models/ directory
"""

import os
import sys
import asyncio
import time
from pathlib import Path
from typing import Dict, Any

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

# Set minimal environment for testing
os.environ.setdefault('SUPABASE_SERVICE_ROLE_KEY', 'test_key')
os.environ.setdefault('SUPABASE_URL', 'https://test.supabase.co')
os.environ.setdefault('SUPABASE_ANON_KEY', 'test_anon_key')


class Colors:
    """ANSI color codes for terminal output."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def print_header(text: str):
    """Print a section header."""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.RESET}\n")


def print_success(text: str):
    """Print success message."""
    print(f"{Colors.GREEN}✅ {text}{Colors.RESET}")


def print_error(text: str):
    """Print error message."""
    print(f"{Colors.RED}❌ {text}{Colors.RESET}")


def print_info(text: str):
    """Print info message."""
    print(f"{Colors.YELLOW}ℹ️  {text}{Colors.RESET}")


def print_result(name: str, duration: float, success: bool, details: str = ""):
    """Print test result."""
    status = "✅ PASS" if success else "❌ FAIL"
    color = Colors.GREEN if success else Colors.RED
    print(f"{color}{status}{Colors.RESET} {name} ({duration:.2f}s)")
    if details:
        print(f"     {details}")


class InferenceTester:
    """Test runner for AI inference modes."""

    def __init__(self):
        self.results: Dict[str, Dict[str, Any]] = {}

    async def test_cloud_story_generation(self) -> bool:
        """Test cloud-based story generation."""
        print_header("TEST 1: Cloud Story Generation (HuggingFace)")

        try:
            # Set cloud mode
            os.environ['AI_INFERENCE_MODE'] = 'cloud_only'

            # Check for API token
            if not os.getenv('HUGGINGFACE_API_TOKEN'):
                print_error("HUGGINGFACE_API_TOKEN not set. Skipping cloud tests.")
                return False

            from app.core.services import StoryGenerator
            from app.core.prompting import PromptBuilder, PromptContext
            from app.core.guardrails import PromptSanitizer

            # Setup
            sanitizer = PromptSanitizer()
            prompt_builder = PromptBuilder(sanitizer=sanitizer)
            context = PromptContext(
                prompt="A short bedtime story about a peaceful ocean",
                theme="ocean",
                mood="calm",
                target_length=200,
                child_age_range="4-6",
            )

            # Generate
            start = time.time()
            story_gen = StoryGenerator(prompt_builder=prompt_builder)
            story_text = await story_gen.generate(context)
            duration = time.time() - start

            # Validate
            success = (
                story_text is not None and
                isinstance(story_text, str) and
                len(story_text) > 50
            )

            if success:
                print_success("Story generated successfully")
                print_info(f"Length: {len(story_text)} characters")
                print_info(f"Preview: {story_text[:100]}...")
            else:
                print_error("Story generation failed validation")

            self.results['cloud_story'] = {
                'success': success,
                'duration': duration,
                'output_length': len(story_text) if story_text else 0
            }

            return success

        except Exception as e:
            print_error(f"Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            return False

    async def test_cloud_narration_generation(self) -> bool:
        """Test cloud-based narration generation."""
        print_header("TEST 2: Cloud Narration Generation (HuggingFace TTS)")

        try:
            os.environ['AI_INFERENCE_MODE'] = 'cloud_only'

            if not os.getenv('HUGGINGFACE_API_TOKEN'):
                print_error("HUGGINGFACE_API_TOKEN not set. Skipping.")
                return False

            from app.core.services import NarrationGenerator
            from app.core.prompting import PromptBuilder, PromptContext
            from app.core.guardrails import PromptSanitizer
            from unittest.mock import MagicMock, AsyncMock

            # Setup
            sanitizer = PromptSanitizer()
            prompt_builder = PromptBuilder(sanitizer=sanitizer)
            context = PromptContext(
                prompt="Test story",
                theme="ocean",
                mood="calm",
                target_length=100,
            )

            story_text = "Once upon a time, by the peaceful ocean, a turtle found a friend."

            # Mock Supabase client
            mock_supabase = MagicMock()
            mock_supabase.upload_audio = AsyncMock(
                return_value="https://test.supabase.co/audio/test.wav"
            )

            # Generate
            start = time.time()
            narration_gen = NarrationGenerator(prompt_builder=prompt_builder)
            audio_url = await narration_gen.synthesize(
                story_text,
                context,
                voice="alloy",
                supabase_client=mock_supabase
            )
            duration = time.time() - start

            # Validate
            success = audio_url is not None and len(audio_url) > 0

            if success:
                print_success("Narration generated successfully")
                print_info(f"Audio URL: {audio_url[:80]}...")
            else:
                print_error("Narration generation failed")

            self.results['cloud_narration'] = {
                'success': success,
                'duration': duration,
            }

            return success

        except Exception as e:
            print_error(f"Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            return False

    async def test_cloud_image_generation(self) -> bool:
        """Test cloud-based image generation."""
        print_header("TEST 3: Cloud Image Generation (HuggingFace)")

        try:
            os.environ['AI_INFERENCE_MODE'] = 'cloud_only'
            os.environ['USE_PLACEHOLDERS_ONLY'] = 'false'

            if not os.getenv('HUGGINGFACE_API_TOKEN'):
                print_error("HUGGINGFACE_API_TOKEN not set. Skipping.")
                return False

            from app.core.services import VisualGenerator
            from app.core.prompting import PromptBuilder, PromptContext
            from app.core.guardrails import PromptSanitizer
            from unittest.mock import MagicMock, AsyncMock

            # Setup
            sanitizer = PromptSanitizer()
            prompt_builder = PromptBuilder(sanitizer=sanitizer)
            context = PromptContext(
                prompt="A peaceful ocean scene",
                theme="ocean",
                mood="calm",
                target_length=100,
            )

            story_text = "A peaceful ocean with gentle waves."

            # Mock Supabase client
            mock_supabase = MagicMock()
            mock_supabase.upload_frame = AsyncMock(
                side_effect=lambda data, filename: f"https://test.supabase.co/frames/{filename}"
            )

            # Generate
            start = time.time()
            visual_gen = VisualGenerator(prompt_builder=prompt_builder)
            frames = await visual_gen.create_frames(
                story_text,
                context,
                num_scenes=2,
                supabase_client=mock_supabase
            )
            duration = time.time() - start

            # Validate
            success = (
                frames is not None and
                isinstance(frames, list) and
                len(frames) == 2
            )

            if success:
                print_success(f"Generated {len(frames)} images successfully")
                for i, url in enumerate(frames, 1):
                    print_info(f"Frame {i}: {url[:80]}...")
            else:
                print_error("Image generation failed")

            self.results['cloud_images'] = {
                'success': success,
                'duration': duration,
                'frame_count': len(frames) if frames else 0
            }

            return success

        except Exception as e:
            print_error(f"Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            return False

    async def test_local_story_generation(self) -> bool:
        """Test local story generation with GGUF models."""
        print_header("TEST 4: Local Story Generation (GGUF Models)")

        try:
            # Set local mode
            os.environ['AI_INFERENCE_MODE'] = 'server_only'
            os.environ['LOCAL_INFERENCE'] = 'true'

            # Check for model file
            model_path = Path(__file__).parent.parent / 'models' / 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf'
            if not model_path.exists():
                print_error(f"Local model not found at {model_path}")
                print_info("Download with: scripts/download_models.sh")
                return False

            os.environ['LOCAL_MODEL_PATH'] = str(model_path)

            from app.core.local_services import LocalStoryGenerator, is_local_inference_available
            from app.core.prompting import PromptBuilder, PromptContext
            from app.core.guardrails import PromptSanitizer

            # Check dependencies
            if not is_local_inference_available():
                print_error("Local inference dependencies not available")
                print_info("Install with: pip install llama-cpp-python")
                return False

            # Setup
            sanitizer = PromptSanitizer()
            prompt_builder = PromptBuilder(sanitizer=sanitizer)
            context = PromptContext(
                prompt="A very short bedtime story",
                theme="ocean",
                mood="calm",
                target_length=150,  # Shorter for local
                child_age_range="4-6",
            )

            # Generate
            start = time.time()
            story_gen = LocalStoryGenerator(prompt_builder=prompt_builder)
            story_text = await story_gen.generate(context)
            duration = time.time() - start

            # Validate
            success = (
                story_text is not None and
                isinstance(story_text, str) and
                len(story_text) > 30
            )

            if success:
                print_success("Story generated successfully")
                print_info(f"Length: {len(story_text)} characters")
                print_info(f"Generation time: {duration:.2f}s")
                print_info(f"Preview: {story_text[:100]}...")
            else:
                print_error("Story generation failed validation")

            self.results['local_story'] = {
                'success': success,
                'duration': duration,
                'output_length': len(story_text) if story_text else 0
            }

            return success

        except Exception as e:
            print_error(f"Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            return False

    async def test_local_narration_generation(self) -> bool:
        """Test local narration with edge-tts."""
        print_header("TEST 5: Local Narration Generation (edge-tts)")

        try:
            os.environ['AI_INFERENCE_MODE'] = 'server_only'
            os.environ['LOCAL_INFERENCE'] = 'true'

            from app.core.local_services import LocalNarrationGenerator
            from app.core.prompting import PromptBuilder, PromptContext
            from app.core.guardrails import PromptSanitizer
            from unittest.mock import MagicMock, AsyncMock

            # Setup
            sanitizer = PromptSanitizer()
            prompt_builder = PromptBuilder(sanitizer=sanitizer)
            context = PromptContext(
                prompt="Test",
                theme="ocean",
                mood="calm",
                target_length=50,
            )

            story_text = "A friendly turtle swam in the ocean."

            # Mock Supabase
            mock_supabase = MagicMock()
            mock_supabase.upload_audio = AsyncMock(
                return_value="https://test.supabase.co/audio/test.wav"
            )

            # Generate
            start = time.time()
            narration_gen = LocalNarrationGenerator(prompt_builder=prompt_builder)
            audio_url = await narration_gen.synthesize(
                story_text,
                context,
                voice="en-US-AriaNeural",
                supabase_client=mock_supabase
            )
            duration = time.time() - start

            # Validate
            success = audio_url is not None and len(audio_url) > 0

            if success:
                print_success("Narration generated successfully")
                print_info(f"Audio URL: {audio_url[:80]}...")
            else:
                print_error("Narration generation failed")

            self.results['local_narration'] = {
                'success': success,
                'duration': duration,
            }

            return success

        except Exception as e:
            print_error(f"Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            return False

    async def test_fallback_behavior(self) -> bool:
        """Test fallback from cloud to local."""
        print_header("TEST 6: Fallback Behavior (Cloud → Local)")

        try:
            # Set cloud_first mode with invalid token (force fallback)
            os.environ['AI_INFERENCE_MODE'] = 'cloud_first'
            os.environ['HUGGINGFACE_API_TOKEN'] = 'invalid_token'
            os.environ['LOCAL_INFERENCE'] = 'true'

            # Check for model
            model_path = Path(__file__).parent.parent / 'models' / 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf'
            if not model_path.exists():
                print_error("Local model not available for fallback test")
                return False

            os.environ['LOCAL_MODEL_PATH'] = str(model_path)

            from app.core.services import get_generators
            from app.core.prompting import PromptBuilder
            from app.core.guardrails import PromptSanitizer

            # Setup
            sanitizer = PromptSanitizer()
            prompt_builder = PromptBuilder(sanitizer=sanitizer)

            # Get generators (should fallback to local)
            start = time.time()
            story_gen, narration_gen, visual_gen = get_generators(prompt_builder)
            duration = time.time() - start

            # Check if we got local generator
            from app.core.local_services import LocalStoryGenerator
            success = isinstance(story_gen, LocalStoryGenerator)

            if success:
                print_success("Fallback to local generator successful")
                print_info(f"Generator type: {type(story_gen).__name__}")
            else:
                print_error("Fallback did not work as expected")

            self.results['fallback'] = {
                'success': success,
                'duration': duration,
            }

            return success

        except Exception as e:
            print_error(f"Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            return False

    def print_summary(self):
        """Print test summary."""
        print_header("TEST SUMMARY")

        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results.values() if r['success'])
        failed_tests = total_tests - passed_tests

        for test_name, result in self.results.items():
            print_result(
                test_name,
                result['duration'],
                result['success'],
                f"{result.get('output_length', 0)} chars" if 'output_length' in result else ""
            )

        print(f"\n{Colors.BOLD}Results: {passed_tests}/{total_tests} tests passed{Colors.RESET}")

        if failed_tests > 0:
            print(f"{Colors.RED}⚠️  {failed_tests} test(s) failed{Colors.RESET}")
        else:
            print(f"{Colors.GREEN}🎉 All tests passed!{Colors.RESET}")

        return failed_tests == 0


async def main():
    """Run all integration tests."""
    print_header("AI Inference Integration Tests")
    print_info("Testing both cloud and local inference modes\n")

    tester = InferenceTester()

    # Run cloud tests
    print_info("Running cloud inference tests...")
    await tester.test_cloud_story_generation()
    await tester.test_cloud_narration_generation()
    await tester.test_cloud_image_generation()

    # Run local tests
    print_info("\nRunning local inference tests...")
    await tester.test_local_story_generation()
    await tester.test_local_narration_generation()

    # Run fallback test
    print_info("\nRunning fallback tests...")
    await tester.test_fallback_behavior()

    # Print summary
    all_passed = tester.print_summary()

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
