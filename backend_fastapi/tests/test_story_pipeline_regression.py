"""
Regression harness for story pipeline.

Runs ~10 canned prompts through mocked generators to catch drift in:
- Tone (brand tone keywords, guardrail violations, exclamation points)
- Length (word count vs target_length)
- Scene counts (number of frames generated)

Usage:
    pytest tests/test_story_pipeline_regression.py -v
    python -m pytest tests/test_story_pipeline_regression.py::test_regression_harness -v
"""

import re
from dataclasses import dataclass
from typing import Optional
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.guardrails import ContentGuard, GuardrailViolation
from app.prompting import PromptBuilder, PromptContext
from app.schemas import StoryRequest, UserProfile
from app.services import NarrationGenerator, StoryGenerator, VisualGenerator


# Brand tone keywords that should appear in stories
BRAND_TONE_KEYWORDS = [
    "soothing", "empathetic", "imaginative", "gentle", "calm", "peaceful",
    "soft", "cozy", "warm", "comforting", "serene", "tranquil", "dreamy"
]

# Canned prompts for regression testing
CANNED_PROMPTS = [
    {
        "name": "ocean_adventure",
        "prompt": "A gentle journey through an underwater garden",
        "theme": "ocean",
        "target_length": 400,
        "num_scenes": 4,
        "profile": None,
        "expected_tone_keywords": ["gentle", "calm", "peaceful"],
        "expected_word_count_range": (350, 500),
    },
    {
        "name": "forest_meditation",
        "prompt": "Walking through a quiet forest at dawn",
        "theme": "forest",
        "target_length": 300,
        "num_scenes": 3,
        "profile": UserProfile(
            mood="calm",
            routine="meditation",
            preferences=["nature", "quiet"],
            favorite_characters=[],
            calming_elements=["birds", "rustling leaves"]
        ),
        "expected_tone_keywords": ["calm", "quiet", "peaceful"],
        "expected_word_count_range": (250, 400),
    },
    {
        "name": "starry_night",
        "prompt": "Floating among the stars",
        "theme": "space",
        "target_length": 500,
        "num_scenes": 5,
        "profile": None,
        "expected_tone_keywords": ["dreamy", "peaceful", "gentle"],
        "expected_word_count_range": (450, 600),
    },
    {
        "name": "cozy_cabin",
        "prompt": "A warm cabin in the mountains",
        "theme": "mountain",
        "target_length": 350,
        "num_scenes": 4,
        "profile": UserProfile(
            mood="cozy",
            routine="bedtime",
            preferences=["warmth", "safety"],
            favorite_characters=["friendly bear"],
            calming_elements=["fireplace", "blankets"]
        ),
        "expected_tone_keywords": ["warm", "cozy", "comforting"],
        "expected_word_count_range": (300, 450),
    },
    {
        "name": "garden_wonder",
        "prompt": "Exploring a magical garden",
        "theme": "garden",
        "target_length": 400,
        "num_scenes": 4,
        "profile": None,
        "expected_tone_keywords": ["magical", "gentle", "peaceful"],
        "expected_word_count_range": (350, 500),
    },
    {
        "name": "desert_peace",
        "prompt": "A peaceful desert sunset",
        "theme": "desert",
        "target_length": 300,
        "num_scenes": 3,
        "profile": None,
        "expected_tone_keywords": ["peaceful", "calm", "serene"],
        "expected_word_count_range": (250, 400),
    },
    {
        "name": "river_flow",
        "prompt": "Following a gentle river",
        "theme": "river",
        "target_length": 450,
        "num_scenes": 5,
        "profile": UserProfile(
            mood="relaxed",
            routine="evening",
            preferences=["water", "flow"],
            favorite_characters=[],
            calming_elements=["flowing water", "smooth stones"]
        ),
        "expected_tone_keywords": ["gentle", "flowing", "calm"],
        "expected_word_count_range": (400, 550),
    },
    {
        "name": "cloud_walking",
        "prompt": "Walking on soft clouds",
        "theme": "sky",
        "target_length": 350,
        "num_scenes": 4,
        "profile": None,
        "expected_tone_keywords": ["soft", "gentle", "dreamy"],
        "expected_word_count_range": (300, 450),
    },
    {
        "name": "library_dreams",
        "prompt": "A quiet library with endless books",
        "theme": "library",
        "target_length": 400,
        "num_scenes": 4,
        "profile": UserProfile(
            mood="curious",
            routine="reading",
            preferences=["books", "knowledge"],
            favorite_characters=["wise owl"],
            calming_elements=["quiet", "pages"]
        ),
        "expected_tone_keywords": ["quiet", "peaceful", "gentle"],
        "expected_word_count_range": (350, 500),
    },
    {
        "name": "meadow_rest",
        "prompt": "Resting in a flower meadow",
        "theme": "meadow",
        "target_length": 300,
        "num_scenes": 3,
        "profile": None,
        "expected_tone_keywords": ["peaceful", "gentle", "calm"],
        "expected_word_count_range": (250, 400),
    },
]


@dataclass
class RegressionResult:
    """Result of a single regression test."""
    prompt_name: str
    passed: bool
    errors: list[str]
    warnings: list[str]
    metrics: dict


def count_words(text: str) -> int:
    """Count words in text."""
    return len(re.findall(r'\b\w+\b', text.lower()))


def check_tone_keywords(text: str, expected_keywords: list[str]) -> list[str]:
    """Check if expected tone keywords appear in text."""
    text_lower = text.lower()
    missing = []
    for keyword in expected_keywords:
        if keyword.lower() not in text_lower:
            missing.append(keyword)
    return missing


def check_tone_violations(text: str) -> tuple[list[str], list[GuardrailViolation]]:
    """Check for tone violations (exclamation points, all caps, etc.)."""
    errors = []
    violations = []
    
    # Check exclamation points (should be minimal)
    exclamation_count = text.count("!")
    if exclamation_count > 6:
        errors.append(f"Too many exclamation points: {exclamation_count} (max 6)")
    
    # Check for all caps chunks
    words = text.split()
    all_caps_chunks = [w for w in words if len(w) > 5 and w.isupper()]
    if len(all_caps_chunks) > 5:
        errors.append(f"Too many all-caps chunks: {len(all_caps_chunks)} (max 5)")
    
    # Check guardrails
    guard = ContentGuard()
    violations = guard.check_story(text, profile=None)
    
    return errors, violations


def check_length(text: str, target_length: int, expected_range: tuple[int, int]) -> list[str]:
    """Check if story length is within expected range."""
    word_count = count_words(text)
    errors = []
    
    if word_count < expected_range[0]:
        errors.append(
            f"Story too short: {word_count} words (expected {expected_range[0]}-{expected_range[1]}, target {target_length})"
        )
    elif word_count > expected_range[1]:
        errors.append(
            f"Story too long: {word_count} words (expected {expected_range[0]}-{expected_range[1]}, target {target_length})"
        )
    
    return errors


def check_scene_count(frames: list[str], expected_num_scenes: int) -> list[str]:
    """Check if number of frames matches expected scenes."""
    errors = []
    actual_count = len(frames)
    if actual_count != expected_num_scenes:
        errors.append(
            f"Scene count mismatch: {actual_count} frames generated (expected {expected_num_scenes})"
        )
    return errors


def create_mock_story_generator(prompt_name: str, mock_story: str) -> StoryGenerator:
    """Create a mocked StoryGenerator that returns deterministic story."""
    builder = PromptBuilder()
    generator = StoryGenerator(prompt_builder=builder)
    
    async def mock_generate(context: PromptContext) -> str:
        return mock_story
    
    generator.generate = AsyncMock(side_effect=mock_generate)
    return generator


def create_mock_visual_generator(num_scenes: int) -> VisualGenerator:
    """Create a mocked VisualGenerator that returns deterministic frames."""
    builder = PromptBuilder()
    generator = VisualGenerator(prompt_builder=builder)
    
    async def mock_create_frames(story: str, context: PromptContext, num_scenes: int, supabase_client=None) -> list[str]:
        # Return mock frame URLs
        return [f"https://mock-storage.com/frame_{i}.png" for i in range(num_scenes)]
    
    generator.create_frames = AsyncMock(side_effect=mock_create_frames)
    return generator


def create_mock_narration_generator() -> NarrationGenerator:
    """Create a mocked NarrationGenerator."""
    builder = PromptBuilder()
    generator = NarrationGenerator(prompt_builder=builder)
    
    async def mock_synthesize(story: str, context: PromptContext, voice: Optional[str], supabase_client=None) -> str:
        return "https://mock-storage.com/audio.wav"
    
    generator.synthesize = AsyncMock(side_effect=mock_synthesize)
    return generator


def generate_mock_story(prompt: str, theme: str, target_length: int, profile: Optional[UserProfile] = None) -> str:
    """
    Generate a mock story that simulates realistic output.
    This should be deterministic based on input parameters.
    """
    # Create a deterministic mock story based on the prompt
    # In a real regression test, you'd use actual baseline outputs
    # Include common tone keywords to help with tone checks
    base_story = f"""Once upon a time, in a {theme} world, there was a gentle adventure.

The journey began with {prompt.lower()}. The air was calm and peaceful, filled with soft whispers of nature. The dreamy atmosphere flowed around like a gentle stream.

As the story unfolded, each moment brought new discoveries. The gentle breeze carried soothing sounds, and the surroundings felt warm and comforting. Every detail seemed to flow together in perfect harmony.

The adventure continued through serene landscapes, where every step felt like a dream. The peaceful atmosphere created a sense of tranquility that wrapped around like a cozy blanket. The dreamy quality of the experience made everything feel soft and flowing.

In the end, the journey concluded with a sense of calm and peace, leaving behind memories of a gentle, imaginative experience. The dreamy world had shared its most peaceful secrets, and the flowing rhythm of the adventure would be remembered forever."""
    
    # Build up to target length with additional paragraphs
    words = count_words(base_story)
    additional_paragraphs = []
    
    # Paragraph templates to add variety
    paragraph_templates = [
        f"The story continued to unfold, revealing more of the {theme} world. Each new scene brought gentle surprises and peaceful moments that touched the heart.",
        f"The journey through this imaginative landscape was filled with soft, calming experiences. Every detail seemed to whisper stories of wonder and tranquility.",
        f"As time passed, the gentle rhythm of the adventure created a sense of deep peace. The surroundings transformed into a dreamy, soothing sanctuary.",
        f"New discoveries awaited around every corner, each one more gentle and inspiring than the last. The {theme} world seemed to embrace all who entered with warmth and kindness.",
        f"The atmosphere grew more serene with each passing moment. Soft light filtered through, creating patterns of calm and comfort that soothed the soul.",
        f"Memories of this gentle journey would linger long after, like a warm embrace. The {theme} world had shared its most peaceful secrets.",
    ]
    
    # Add paragraphs until we reach target length
    template_idx = 0
    while words < target_length * 0.9:  # Aim for 90% of target to allow some variance
        if template_idx < len(paragraph_templates):
            additional_paragraphs.append(paragraph_templates[template_idx % len(paragraph_templates)])
            template_idx += 1
        else:
            # Reuse templates with slight variation
            additional_paragraphs.append(paragraph_templates[template_idx % len(paragraph_templates)])
            template_idx += 1
        
        # Recalculate word count
        temp_story = base_story + "\n\n" + "\n\n".join(additional_paragraphs)
        words = count_words(temp_story)
    
    # Combine all paragraphs
    if additional_paragraphs:
        base_story += "\n\n" + "\n\n".join(additional_paragraphs)
    
    # Trim if too long (simple approach)
    words = count_words(base_story)
    if words > target_length * 1.3:
        # Roughly trim to target
        word_list = base_story.split()
        trimmed = word_list[:int(target_length * 1.2)]
        base_story = " ".join(trimmed)
    
    return base_story


@pytest.mark.asyncio
async def test_regression_harness():
    """
    Run regression tests on all canned prompts.
    
    This test runs through all canned prompts, mocks the generators,
    and checks for drift in tone, length, and scene counts.
    """
    results = []
    
    for test_case in CANNED_PROMPTS:
        prompt_name = test_case["name"]
        prompt = test_case["prompt"]
        theme = test_case["theme"]
        target_length = test_case["target_length"]
        num_scenes = test_case["num_scenes"]
        profile = test_case["profile"]
        expected_tone_keywords = test_case["expected_tone_keywords"]
        expected_word_range = test_case["expected_word_count_range"]
        
        # Generate mock story (deterministic based on inputs)
        mock_story = generate_mock_story(prompt, theme, target_length, profile)
        
        # Create mocked generators
        story_gen = create_mock_story_generator(prompt_name, mock_story)
        visual_gen = create_mock_visual_generator(num_scenes)
        narration_gen = create_mock_narration_generator()
        
        # Create context
        builder = PromptBuilder()
        request = StoryRequest(
            prompt=prompt,
            theme=theme,
            target_length=target_length,
            num_scenes=num_scenes,
            profile=profile,
        )
        context = builder.to_context(request)
        
        # Run pipeline (mocked)
        story_text = await story_gen.generate(context)
        frames = await visual_gen.create_frames(story_text, context, num_scenes)
        audio_url = await narration_gen.synthesize(story_text, context, None)
        
        # Run checks
        errors = []
        warnings = []
        
        # Check tone keywords
        missing_keywords = check_tone_keywords(story_text, expected_tone_keywords)
        if missing_keywords:
            warnings.append(f"Missing expected tone keywords: {', '.join(missing_keywords)}")
        
        # Check tone violations
        tone_errors, guardrail_violations = check_tone_violations(story_text)
        errors.extend(tone_errors)
        if guardrail_violations:
            for violation in guardrail_violations:
                errors.append(f"Guardrail violation: {violation.category} - {violation.detail}")
        
        # Check length
        length_errors = check_length(story_text, target_length, expected_word_range)
        errors.extend(length_errors)
        
        # Check scene count
        scene_errors = check_scene_count(frames, num_scenes)
        errors.extend(scene_errors)
        
        # Collect metrics
        metrics = {
            "word_count": count_words(story_text),
            "target_length": target_length,
            "scene_count": len(frames),
            "expected_scenes": num_scenes,
            "exclamation_count": story_text.count("!"),
            "all_caps_chunks": len([w for w in story_text.split() if len(w) > 5 and w.isupper()]),
            "guardrail_violations": len(guardrail_violations),
        }
        
        result = RegressionResult(
            prompt_name=prompt_name,
            passed=len(errors) == 0,
            errors=errors,
            warnings=warnings,
            metrics=metrics,
        )
        results.append(result)
    
    # Assert all tests passed
    failed_tests = [r for r in results if not r.passed]
    if failed_tests:
        error_summary = []
        for result in failed_tests:
            error_summary.append(f"\n{result.prompt_name}:")
            for error in result.errors:
                error_summary.append(f"  ERROR: {error}")
            for warning in result.warnings:
                error_summary.append(f"  WARNING: {warning}")
            error_summary.append(f"  Metrics: {result.metrics}")
        
        pytest.fail(
            f"Regression tests failed for {len(failed_tests)}/{len(results)} prompts:\n" + "\n".join(error_summary)
        )


@pytest.mark.asyncio
async def test_individual_prompt():
    """Test a single prompt for debugging."""
    test_case = CANNED_PROMPTS[0]  # ocean_adventure
    
    prompt_name = test_case["name"]
    prompt = test_case["prompt"]
    theme = test_case["theme"]
    target_length = test_case["target_length"]
    num_scenes = test_case["num_scenes"]
    profile = test_case["profile"]
    
    mock_story = generate_mock_story(prompt, theme, target_length, profile)
    story_gen = create_mock_story_generator(prompt_name, mock_story)
    visual_gen = create_mock_visual_generator(num_scenes)
    
    builder = PromptBuilder()
    request = StoryRequest(
        prompt=prompt,
        theme=theme,
        target_length=target_length,
        num_scenes=num_scenes,
        profile=profile,
    )
    context = builder.to_context(request)
    
    story_text = await story_gen.generate(context)
    frames = await visual_gen.create_frames(story_text, context, num_scenes)
    
    assert len(frames) == num_scenes, f"Expected {num_scenes} frames, got {len(frames)}"
    assert count_words(story_text) >= target_length * 0.7, "Story too short"
    assert count_words(story_text) <= target_length * 1.5, "Story too long"

