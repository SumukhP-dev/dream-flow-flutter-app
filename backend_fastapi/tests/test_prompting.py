"""
Unit tests for PromptBuilder and StoryGenerator.

Tests ensure:
- PromptBuilder enforces brand rules in generated prompts
- StoryGenerator respects target_length and profile context
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

from app.prompting import PromptBuilder, PromptContext, BRAND_TONE, BRAND_RULES
from app.schemas import StoryRequest, UserProfile
from app.services import StoryGenerator


class TestPromptContext:
    """Tests for PromptContext dataclass."""

    def test_profile_snippet_with_full_profile(self):
        """Test profile_snippet includes all profile fields."""
        profile = UserProfile(
            mood="calm",
            routine="reading",
            preferences=["nature", "ocean"],
            favorite_characters=["dolphin", "whale"],
            calming_elements=["blue", "waves", "sand"]
        )
        context = PromptContext(
            prompt="A peaceful journey",
            theme="ocean",
            target_length=400,
            profile=profile
        )
        
        snippet = context.profile_snippet
        assert "Mood: calm" in snippet
        assert "Routine: reading" in snippet
        assert "Preferences: nature, ocean" in snippet
        assert "Favorite characters: dolphin, whale" in snippet
        assert "Calming elements: blue, waves, sand" in snippet

    def test_profile_snippet_with_minimal_profile(self):
        """Test profile_snippet with only required fields."""
        profile = UserProfile(
            mood="tired",
            routine="sleeping"
        )
        context = PromptContext(
            prompt="A dream",
            theme="stars",
            target_length=300,
            profile=profile
        )
        
        snippet = context.profile_snippet
        assert "Mood: tired" in snippet
        assert "Routine: sleeping" in snippet
        assert "Preferences:" not in snippet
        assert "Favorite characters:" not in snippet
        assert "Calming elements:" not in snippet

    def test_profile_snippet_without_profile(self):
        """Test profile_snippet when profile is None."""
        context = PromptContext(
            prompt="A story",
            theme="forest",
            target_length=500,
            profile=None
        )
        
        assert context.profile_snippet == "No additional profile provided."


class TestPromptBuilder:
    """Tests for PromptBuilder class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.builder = PromptBuilder()

    def test_to_context_converts_story_request(self):
        """Test to_context converts StoryRequest to PromptContext."""
        profile = UserProfile(mood="relaxed", routine="meditation")
        request = StoryRequest(
            prompt="A peaceful garden",
            theme="nature",
            target_length=350,
            profile=profile
        )
        
        context = self.builder.to_context(request)
        
        assert isinstance(context, PromptContext)
        assert context.prompt == "A peaceful garden"
        assert context.theme == "nature"
        assert context.target_length == 350
        assert context.profile == profile

    def test_story_prompt_includes_brand_tone(self):
        """Test story_prompt includes brand tone."""
        context = PromptContext(
            prompt="Test story",
            theme="adventure",
            target_length=400,
            profile=None
        )
        
        prompt = self.builder.story_prompt(context)
        
        assert BRAND_TONE in prompt
        assert f"Brand tone: {BRAND_TONE}" in prompt

    def test_story_prompt_includes_all_brand_rules(self):
        """Test story_prompt includes all brand rules."""
        context = PromptContext(
            prompt="Test story",
            theme="fantasy",
            target_length=500,
            profile=None
        )
        
        prompt = self.builder.story_prompt(context)
        
        # Check that all brand rules are present
        for rule in BRAND_RULES:
            assert rule in prompt

    def test_story_prompt_includes_target_length(self):
        """Test story_prompt includes target length."""
        context = PromptContext(
            prompt="A story",
            theme="space",
            target_length=600,
            profile=None
        )
        
        prompt = self.builder.story_prompt(context)
        
        assert "Target length: 600 words" in prompt

    def test_story_prompt_includes_theme(self):
        """Test story_prompt includes theme."""
        context = PromptContext(
            prompt="A story",
            theme="underwater",
            target_length=400,
            profile=None
        )
        
        prompt = self.builder.story_prompt(context)
        
        assert "Theme: underwater" in prompt

    def test_story_prompt_includes_user_profile(self):
        """Test story_prompt includes user profile information."""
        profile = UserProfile(
            mood="peaceful",
            routine="bath",
            preferences=["lavender", "warmth"],
            favorite_characters=["moon", "stars"],
            calming_elements=["purple", "silver"]
        )
        context = PromptContext(
            prompt="A bedtime tale",
            theme="night",
            target_length=450,
            profile=profile
        )
        
        prompt = self.builder.story_prompt(context)
        
        assert "User profile:" in prompt
        assert "Mood: peaceful" in prompt
        assert "Routine: bath" in prompt
        assert "lavender" in prompt
        assert "moon" in prompt
        assert "purple" in prompt

    def test_story_prompt_includes_seed_prompt(self):
        """Test story_prompt includes the seed prompt."""
        seed = "A magical forest with talking trees"
        context = PromptContext(
            prompt=seed,
            theme="forest",
            target_length=400,
            profile=None
        )
        
        prompt = self.builder.story_prompt(context)
        
        assert f'Seed prompt: "{seed}"' in prompt

    def test_story_prompt_has_role_definition(self):
        """Test story_prompt includes role definition."""
        context = PromptContext(
            prompt="Test",
            theme="test",
            target_length=400,
            profile=None
        )
        
        prompt = self.builder.story_prompt(context)
        
        assert "Role: You are the Dream Flow bedtime story engine" in prompt

    def test_story_prompt_requests_cohesive_story(self):
        """Test story_prompt requests cohesive multi-paragraph story."""
        context = PromptContext(
            prompt="Test",
            theme="test",
            target_length=400,
            profile=None
        )
        
        prompt = self.builder.story_prompt(context)
        
        assert "cohesive multi-paragraph story" in prompt.lower()
        assert "soft scene breaks" in prompt.lower()

    def test_narration_prompt_includes_brand_tone(self):
        """Test narration_prompt includes brand tone."""
        context = PromptContext(
            prompt="Test",
            theme="test",
            target_length=400,
            profile=None
        )
        story = "Once upon a time..."
        
        prompt = self.builder.narration_prompt(context, story)
        
        assert BRAND_TONE in prompt
        assert f"with a {BRAND_TONE} delivery" in prompt

    def test_narration_prompt_includes_story(self):
        """Test narration_prompt includes the story text."""
        context = PromptContext(
            prompt="Test",
            theme="test",
            target_length=400,
            profile=None
        )
        story = "Once upon a time in a magical kingdom..."
        
        prompt = self.builder.narration_prompt(context, story)
        
        assert story in prompt

    def test_narration_prompt_emphasizes_pacing(self):
        """Test narration_prompt emphasizes gentle pacing."""
        context = PromptContext(
            prompt="Test",
            theme="test",
            target_length=400,
            profile=None
        )
        story = "A story"
        
        prompt = self.builder.narration_prompt(context, story)
        
        assert "gentle pacing" in prompt.lower()
        assert "subtle pauses" in prompt.lower()

    def test_visual_prompt_includes_theme(self):
        """Test visual_prompt includes theme."""
        context = PromptContext(
            prompt="Test",
            theme="ocean",
            target_length=400,
            profile=None
        )
        scene = "A calm sea"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert "ocean illustration" in prompt

    def test_visual_prompt_includes_brand_tone(self):
        """Test visual_prompt includes brand tone in palette."""
        context = PromptContext(
            prompt="Test",
            theme="forest",
            target_length=400,
            profile=None
        )
        scene = "Trees"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert BRAND_TONE in prompt

    def test_visual_prompt_uses_profile_calming_elements(self):
        """Test visual_prompt uses profile calming elements when available."""
        profile = UserProfile(
            mood="calm",
            routine="sleep",
            calming_elements=["blue", "purple", "silver"]
        )
        context = PromptContext(
            prompt="Test",
            theme="night",
            target_length=400,
            profile=profile
        )
        scene = "Stars"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert "blue, purple, silver" in prompt

    def test_visual_prompt_falls_back_to_theme_when_no_calming_elements(self):
        """Test visual_prompt uses theme when no calming elements."""
        context = PromptContext(
            prompt="Test",
            theme="sunset",
            target_length=400,
            profile=None
        )
        scene = "Sky"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert "sunset" in prompt

    def test_visual_prompt_uses_profile_favorite_characters(self):
        """Test visual_prompt uses profile favorite characters when available."""
        profile = UserProfile(
            mood="happy",
            routine="play",
            favorite_characters=["dolphin", "seal"]
        )
        context = PromptContext(
            prompt="Test",
            theme="ocean",
            target_length=400,
            profile=profile
        )
        scene = "Water"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert "dolphin, seal" in prompt

    def test_visual_prompt_falls_back_to_default_characters(self):
        """Test visual_prompt uses default when no favorite characters."""
        context = PromptContext(
            prompt="Test",
            theme="forest",
            target_length=400,
            profile=None
        )
        scene = "Trees"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert "dreamy companions" in prompt

    def test_visual_prompt_includes_scene_text(self):
        """Test visual_prompt includes scene text."""
        context = PromptContext(
            prompt="Test",
            theme="space",
            target_length=400,
            profile=None
        )
        scene = "A galaxy far away"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert scene in prompt

    def test_visual_prompt_includes_style(self):
        """Test visual_prompt includes cinematic watercolor style."""
        context = PromptContext(
            prompt="Test",
            theme="garden",
            target_length=400,
            profile=None
        )
        scene = "Flowers"
        
        prompt = self.builder.visual_prompt(context, scene)
        
        assert "cinematic watercolor style" in prompt


class TestStoryGenerator:
    """Tests for StoryGenerator class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.builder = PromptBuilder()
        self.generator = StoryGenerator(prompt_builder=self.builder)

    @pytest.mark.asyncio
    async def test_generate_respects_target_length_in_prompt(self):
        """Test that generate includes target_length in the prompt sent to model."""
        context = PromptContext(
            prompt="A peaceful journey",
            theme="ocean",
            target_length=500,
            profile=None
        )
        
        # Mock the client's text_generation method
        mock_response = "Once upon a time, there was a peaceful ocean..."
        with patch.object(self.generator.client, 'text_generation', return_value=mock_response):
            result = await self.generator.generate(context)
            
            # Verify the prompt builder was called with correct context
            # The actual prompt should include target_length
            call_args = self.generator.client.text_generation.call_args
            assert call_args is not None
            prompt_sent = call_args[0][0]  # First positional argument
            assert "Target length: 500 words" in prompt_sent
            assert result == mock_response.strip()

    @pytest.mark.asyncio
    async def test_generate_includes_profile_context_in_prompt(self):
        """Test that generate includes profile context in the prompt."""
        profile = UserProfile(
            mood="calm",
            routine="reading",
            preferences=["nature"],
            favorite_characters=["owl"],
            calming_elements=["green"]
        )
        context = PromptContext(
            prompt="A forest tale",
            theme="forest",
            target_length=400,
            profile=profile
        )
        
        mock_response = "In a peaceful forest..."
        with patch.object(self.generator.client, 'text_generation', return_value=mock_response):
            await self.generator.generate(context)
            
            # Verify profile information is in the prompt
            call_args = self.generator.client.text_generation.call_args
            prompt_sent = call_args[0][0]
            assert "Mood: calm" in prompt_sent
            assert "Routine: reading" in prompt_sent
            assert "nature" in prompt_sent
            assert "owl" in prompt_sent
            assert "green" in prompt_sent

    @pytest.mark.asyncio
    async def test_generate_includes_brand_rules_in_prompt(self):
        """Test that generate includes brand rules in the prompt."""
        context = PromptContext(
            prompt="A story",
            theme="stars",
            target_length=300,
            profile=None
        )
        
        mock_response = "Under the starry sky..."
        with patch.object(self.generator.client, 'text_generation', return_value=mock_response):
            await self.generator.generate(context)
            
            # Verify brand rules are in the prompt
            call_args = self.generator.client.text_generation.call_args
            prompt_sent = call_args[0][0]
            
            # Check that all brand rules are present
            for rule in BRAND_RULES:
                assert rule in prompt_sent
            
            # Check brand tone is present
            assert BRAND_TONE in prompt_sent

    @pytest.mark.asyncio
    async def test_generate_uses_correct_generation_parameters(self):
        """Test that generate uses appropriate text generation parameters."""
        context = PromptContext(
            prompt="Test",
            theme="test",
            target_length=400,
            profile=None
        )
        
        mock_response = "Generated story text"
        with patch.object(self.generator.client, 'text_generation', return_value=mock_response) as mock_gen:
            await self.generator.generate(context)
            
            # Verify the call was made with correct parameters
            call_kwargs = mock_gen.call_args[1]  # Keyword arguments
            assert call_kwargs['return_full_text'] is False
            # Note: max_new_tokens, temperature, etc. come from settings
            # We verify the call was made, which is sufficient

    @pytest.mark.asyncio
    async def test_generate_strips_whitespace(self):
        """Test that generate strips whitespace from response."""
        context = PromptContext(
            prompt="Test",
            theme="test",
            target_length=400,
            profile=None
        )
        
        mock_response = "  \n  Story text with whitespace  \n  "
        with patch.object(self.generator.client, 'text_generation', return_value=mock_response):
            result = await self.generator.generate(context)
            
            assert result == "Story text with whitespace"

    @pytest.mark.asyncio
    async def test_generate_with_different_target_lengths(self):
        """Test generate with different target_length values."""
        for target_length in [200, 400, 600, 800]:
            context = PromptContext(
                prompt="A story",
                theme="adventure",
                target_length=target_length,
                profile=None
            )
            
            mock_response = f"Story for {target_length} words"
            with patch.object(self.generator.client, 'text_generation', return_value=mock_response):
                await self.generator.generate(context)
                
                call_args = self.generator.client.text_generation.call_args
                prompt_sent = call_args[0][0]
                assert f"Target length: {target_length} words" in prompt_sent

    @pytest.mark.asyncio
    async def test_generate_with_complex_profile(self):
        """Test generate with a complex user profile."""
        profile = UserProfile(
            mood="excited but tired",
            routine="bath, then reading",
            preferences=["fantasy", "magic", "dragons"],
            favorite_characters=["wizard", "dragon", "unicorn"],
            calming_elements=["purple", "blue", "stars", "moonlight"]
        )
        context = PromptContext(
            prompt="A magical adventure",
            theme="fantasy",
            target_length=500,
            profile=profile
        )
        
        mock_response = "In a magical realm..."
        with patch.object(self.generator.client, 'text_generation', return_value=mock_response):
            await self.generator.generate(context)
            
            call_args = self.generator.client.text_generation.call_args
            prompt_sent = call_args[0][0]
            
            # Verify all profile elements are included
            assert "excited but tired" in prompt_sent
            assert "bath, then reading" in prompt_sent
            assert "fantasy, magic, dragons" in prompt_sent
            assert "wizard, dragon, unicorn" in prompt_sent
            assert "purple, blue, stars, moonlight" in prompt_sent

    @pytest.mark.asyncio
    async def test_generate_preserves_seed_prompt(self):
        """Test that generate preserves the seed prompt in the generated prompt."""
        seed = "A young explorer discovers a hidden garden"
        context = PromptContext(
            prompt=seed,
            theme="garden",
            target_length=400,
            profile=None
        )
        
        mock_response = "The explorer walked..."
        with patch.object(self.generator.client, 'text_generation', return_value=mock_response):
            await self.generator.generate(context)
            
            call_args = self.generator.client.text_generation.call_args
            prompt_sent = call_args[0][0]
            assert f'Seed prompt: "{seed}"' in prompt_sent

