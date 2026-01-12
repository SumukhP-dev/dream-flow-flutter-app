"""
Template for adding new inference mode tests.

When adding a new inference mode (e.g., "anthropic", "openai", "azure"):
1. Copy this template
2. Replace {{MODE_NAME}} with your mode name
3. Implement the generator classes
4. Add tests to test_inference_modes_integration.py
5. Update CI/CD workflow

Example: Adding "OpenAI" mode
- Replace {{MODE_NAME}} with "OpenAI"
- Replace {{mode_name}} with "openai"
- Replace {{MODE_CONFIG}} with "openai_only" or "openai_first"
"""

import pytest
import asyncio
from pathlib import Path
from unittest.mock import MagicMock, AsyncMock

from app.shared.config import Settings
from app.core.prompting import PromptBuilder, PromptContext
from app.core.guardrails import PromptSanitizer


class Test{{MODE_NAME}}InferenceMode:
    """Integration tests for {{mode_name}}_only mode."""

    @pytest.fixture
    def {{mode_name}}_settings(self):
        """Create settings for {{mode_name}}-only inference."""
        import os
        with patch.dict(os.environ, {
            'AI_INFERENCE_MODE': '{{MODE_CONFIG}}',
            '{{MODE_NAME}}_API_KEY': os.getenv('{{MODE_NAME}}_API_KEY', 'test_key'),
            'SUPABASE_SERVICE_ROLE_KEY': 'test_key',
            # Add other required env vars
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
    async def test_{{mode_name}}_story_generation(
        self, 
        {{mode_name}}_settings, 
        prompt_builder, 
        test_context
    ):
        """Test story generation using {{MODE_NAME}} API."""
        from app.core.{{mode_name}}_services import {{MODE_NAME}}StoryGenerator

        # Initialize generator
        story_gen = {{MODE_NAME}}StoryGenerator(prompt_builder=prompt_builder)

        # Generate story
        story_text = await story_gen.generate(test_context)

        # Assertions
        assert story_text is not None
        assert isinstance(story_text, str)
        assert len(story_text) > 50, "Story should be substantial"
        assert any(word in story_text.lower() for word in ['ocean', 'sea', 'water', 'wave']), \
            "Story should contain ocean-related content"

        print(f"\n✅ {{MODE_NAME}} Story Generated ({len(story_text)} chars):")
        print(f"   {story_text[:100]}...")

    @pytest.mark.asyncio
    async def test_{{mode_name}}_narration_generation(
        self, 
        {{mode_name}}_settings, 
        prompt_builder, 
        test_context
    ):
        """Test audio narration using {{MODE_NAME}} TTS API."""
        from app.core.{{mode_name}}_services import {{MODE_NAME}}NarrationGenerator

        story_text = "Once upon a time, by the peaceful ocean, a little turtle found a friend."

        # Initialize generator
        narration_gen = {{MODE_NAME}}NarrationGenerator(prompt_builder=prompt_builder)

        # Generate narration (mock Supabase client)
        mock_supabase = MagicMock()
        mock_supabase.upload_audio = AsyncMock(
            return_value="https://test.supabase.co/audio/test.wav"
        )

        audio_url = await narration_gen.synthesize(
            story_text,
            test_context,
            voice="default",
            supabase_client=mock_supabase
        )

        # Assertions
        assert audio_url is not None
        assert isinstance(audio_url, str)
        assert len(audio_url) > 0

        print(f"\n✅ {{MODE_NAME}} Narration Generated:")
        print(f"   Audio URL: {audio_url[:80]}...")

    @pytest.mark.asyncio
    async def test_{{mode_name}}_visual_generation(
        self, 
        {{mode_name}}_settings, 
        prompt_builder, 
        test_context
    ):
        """Test image generation using {{MODE_NAME}} image API."""
        from app.core.{{mode_name}}_services import {{MODE_NAME}}VisualGenerator

        story_text = "Once upon a time, by the peaceful ocean."
        num_scenes = 2

        # Initialize generator
        visual_gen = {{MODE_NAME}}VisualGenerator(prompt_builder=prompt_builder)

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

        print(f"\n✅ {{MODE_NAME}} Images Generated ({len(frames)} frames):")
        for i, url in enumerate(frames, 1):
            print(f"   Frame {i}: {url[:80]}...")

    @pytest.mark.asyncio
    async def test_{{mode_name}}_full_story_pipeline(
        self, 
        {{mode_name}}_settings, 
        prompt_builder, 
        test_context
    ):
        """Test complete story generation pipeline with {{MODE_NAME}} inference."""
        from app.core.{{mode_name}}_services import (
            {{MODE_NAME}}StoryGenerator,
            {{MODE_NAME}}NarrationGenerator,
            {{MODE_NAME}}VisualGenerator
        )

        # Initialize all generators
        story_gen = {{MODE_NAME}}StoryGenerator(prompt_builder=prompt_builder)
        narration_gen = {{MODE_NAME}}NarrationGenerator(prompt_builder=prompt_builder)
        visual_gen = {{MODE_NAME}}VisualGenerator(prompt_builder=prompt_builder)

        # Mock Supabase
        mock_supabase = MagicMock()
        mock_supabase.upload_audio = AsyncMock(
            return_value="https://test.supabase.co/audio/test.wav"
        )
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
            voice="default",
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

        print(f"\n✅ Complete {{MODE_NAME}} Pipeline Success:")
        print(f"   Story: {len(story_text)} chars")
        print(f"   Audio: {audio_url[:80]}...")
        print(f"   Frames: {len(frames)} images")


# ============================================================================
# STEP-BY-STEP GUIDE
# ============================================================================

"""
HOW TO ADD A NEW INFERENCE MODE
================================

1. CREATE GENERATOR CLASSES
----------------------------
Create file: app/core/{{mode_name}}_services.py

```python
from dataclasses import dataclass
from app.core.prompting import PromptBuilder, PromptContext

@dataclass
class {{MODE_NAME}}StoryGenerator:
    prompt_builder: PromptBuilder
    
    async def generate(self, context: PromptContext) -> str:
        # Implement story generation using {{MODE_NAME}} API
        pass

@dataclass
class {{MODE_NAME}}NarrationGenerator:
    prompt_builder: PromptBuilder
    
    async def synthesize(self, story: str, context: PromptContext, 
                        voice: str, supabase_client) -> str:
        # Implement narration using {{MODE_NAME}} TTS
        pass

@dataclass
class {{MODE_NAME}}VisualGenerator:
    prompt_builder: PromptBuilder
    
    async def create_frames(self, story: str, context: PromptContext,
                           num_scenes: int, supabase_client) -> list[str]:
        # Implement image generation using {{MODE_NAME}} API
        pass
```

2. UPDATE CONFIGURATION
-----------------------
Add to app/shared/config.py:

```python
class Settings(BaseModel):
    # ... existing settings ...
    
    # {{MODE_NAME}} Configuration
    {{mode_name}}_api_key: str | None = os.getenv("{{MODE_NAME}}_API_KEY")
    {{mode_name}}_api_url: str = os.getenv("{{MODE_NAME}}_API_URL", "https://api.{{mode_name}}.com")
    {{mode_name}}_story_model: str = os.getenv("{{MODE_NAME}}_STORY_MODEL", "default-model")
    {{mode_name}}_tts_model: str = os.getenv("{{MODE_NAME}}_TTS_MODEL", "default-tts")
    {{mode_name}}_image_model: str = os.getenv("{{MODE_NAME}}_IMAGE_MODEL", "default-image")
```

3. UPDATE FALLBACK SYSTEM
--------------------------
Add to app/core/services.py in get_inference_config():

```python
mode_configs = {
    # ... existing configs ...
    
    "{{mode_name}}_first": {
        "primary": "{{mode_name}}",
        "fallback_chain": ["{{mode_name}}", "local", "cloud"],
        "allow_fallback": True,
        "description": "{{MODE_NAME}} → Server Local → Cloud"
    },
    "{{mode_name}}_only": {
        "primary": "{{mode_name}}",
        "fallback_chain": ["{{mode_name}}"],
        "allow_fallback": False,
        "description": "Only {{MODE_NAME}} APIs, no fallback"
    },
}
```

Add to _get_generators() function:

```python
def _get_{{mode_name}}_generators(prompt_builder: PromptBuilder) -> tuple:
    from .{{mode_name}}_services import (
        {{MODE_NAME}}StoryGenerator,
        {{MODE_NAME}}NarrationGenerator,
        {{MODE_NAME}}VisualGenerator,
    )
    
    logger.info("Using {{MODE_NAME}} inference mode")
    
    story_gen = {{MODE_NAME}}StoryGenerator(prompt_builder=prompt_builder)
    narration_gen = {{MODE_NAME}}NarrationGenerator(prompt_builder=prompt_builder)
    visual_gen = {{MODE_NAME}}VisualGenerator(prompt_builder=prompt_builder)
    
    return (story_gen, narration_gen, visual_gen)

# In get_generators() function, add to the version check:
if version == "{{mode_name}}":
    return _get_{{mode_name}}_generators(prompt_builder)
```

4. UPDATE FALLBACK FUNCTIONS
-----------------------------
Add to app/dreamflow/main.py in generator_map:

```python
generator_map = {
    "cloud": ("StoryGenerator", StoryGenerator),
    "local": ("LocalStoryGenerator", LocalStoryGenerator),
    "{{mode_name}}": ("{{MODE_NAME}}StoryGenerator", {{MODE_NAME}}StoryGenerator),
    # ... other generators ...
}
```

5. ADD TESTS
------------
Copy this template to tests/test_{{mode_name}}_integration.py
Replace all {{MODE_NAME}} and {{mode_name}} placeholders
Implement the test methods

6. UPDATE CI/CD
---------------
Add to .github/workflows/inference-tests.yml:

```yaml
test-{{mode_name}}-inference:
  name: {{MODE_NAME}} Inference Tests
  runs-on: ubuntu-latest
  timeout-minutes: 15
  
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with:
        python-version: '3.11'
    
    - name: Install dependencies
      working-directory: backend_fastapi
      run: |
        pip install -r requirements.txt
        pip install pytest pytest-asyncio
    
    - name: Run {{MODE_NAME}} tests
      working-directory: backend_fastapi
      env:
        {{MODE_NAME}}_API_KEY: ${{ secrets.{{MODE_NAME}}_API_KEY }}
        AI_INFERENCE_MODE: {{mode_name}}_only
      run: |
        pytest tests/test_{{mode_name}}_integration.py -v -s
```

7. UPDATE DOCUMENTATION
-----------------------
Add to backend_fastapi/AI_INFERENCE_MODES.md:

## {{MODE_NAME}} Inference Mode

- **`AI_INFERENCE_MODE={{mode_name}}_first`**
  - **Strategy**: {{MODE_NAME}} → Server Local → Cloud
  - **Best For**: [Use case description]
  - **Performance**: [Expected timing]
  - **Requirements**: {{MODE_NAME}}_API_KEY environment variable

Configuration:
```env
AI_INFERENCE_MODE={{mode_name}}_first
{{MODE_NAME}}_API_KEY=your_api_key_here
```

8. TEST YOUR IMPLEMENTATION
---------------------------
```bash
# Test new mode
AI_INFERENCE_MODE={{mode_name}}_only pytest tests/test_{{mode_name}}_integration.py -v

# Test fallback
AI_INFERENCE_MODE={{mode_name}}_first pytest tests/test_inference_modes_integration.py -k fallback -v

# Run performance benchmarks
python tests/performance_monitor.py --mode {{mode_name}} --iterations 5
```

9. CHECKLIST
------------
- [ ] Created {{mode_name}}_services.py with all three generators
- [ ] Added configuration to Settings class
- [ ] Updated get_inference_config() with new modes
- [ ] Created _get_{{mode_name}}_generators() function
- [ ] Updated generator_map in fallback functions
- [ ] Added tests to test_{{mode_name}}_integration.py
- [ ] Updated CI/CD workflow
- [ ] Updated AI_INFERENCE_MODES.md documentation
- [ ] Tested locally
- [ ] All tests pass
- [ ] Performance benchmarks look good
"""
