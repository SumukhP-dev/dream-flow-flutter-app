from __future__ import annotations

import json
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .schemas import StoryRequest, UserProfile


BRAND_TONE = "soothing, empathetic, imaginative, bedtime-safe"
BRAND_RULES = [
    "Never include violence, fear, or harsh language.",
    "Prioritize gentle sensory imagery (soft light, cozy textures, calm sounds).",
    "Encourage positive self-belief and emotional regulation.",
    "Keep sentences short-to-medium for easy listening.",
]


@dataclass
class PromptContext:
    prompt: str
    theme: str
    target_length: int
    profile: Optional[UserProfile]

    @property
    def profile_snippet(self) -> str:
        if not self.profile:
            return "No additional profile provided."
        items: list[str] = [
            f"Mood: {self.profile.mood}",
            f"Routine: {self.profile.routine}",
        ]
        if self.profile.preferences:
            items.append(f"Preferences: {', '.join(self.profile.preferences)}")
        if self.profile.favorite_characters:
            items.append(f"Favorite characters: {', '.join(self.profile.favorite_characters)}")
        if self.profile.calming_elements:
            items.append(f"Calming elements: {', '.join(self.profile.calming_elements)}")
        return " | ".join(items)


class PromptBuilder:
    def __init__(self):
        """Initialize PromptBuilder with lazy-loading presets."""
        self._config_path = Path(__file__).parent / "story_presets.json"
        self._presets: dict | None = None
    
    def reload_presets(self) -> None:
        """Invalidate the cached presets so they are reloaded from disk on next access."""
        self._presets = None
    
    def _ensure_presets_loaded(self) -> dict:
        if self._presets is None:
            self._presets = self._load_presets()
        return self._presets
    
    def _load_presets(self) -> dict:
        """Load story presets from JSON config file."""
        if not self._config_path.exists():
            return {"themes": [], "featured": []}
        try:
            with open(self._config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            # Return empty structure if config file doesn't exist
            return {"themes": [], "featured": []}
        except json.JSONDecodeError as e:
            # Log error and return empty structure
            print(f"Warning: Failed to parse story_presets.json: {e}")
            return {"themes": [], "featured": []}
    
    def get_all_themes(self) -> list[dict]:
        """Get all available themes from the config."""
        presets = self._ensure_presets_loaded()
        return presets.get("themes", [])
    
    def get_featured_worlds(self) -> list[dict]:
        """Get featured worlds (one from each category) from the config."""
        presets = self._ensure_presets_loaded()
        featured_titles = presets.get("featured", [])
        all_themes = presets.get("themes", [])
        
        # Create a lookup by title
        theme_lookup = {theme["title"]: theme for theme in all_themes}
        
        # Return featured themes in order
        featured = []
        for title in featured_titles:
            if title in theme_lookup:
                featured.append(theme_lookup[title])
        
        return featured
    
    def to_context(self, payload: StoryRequest) -> PromptContext:
        return PromptContext(
            prompt=payload.prompt,
            theme=payload.theme,
            target_length=payload.target_length,
            profile=payload.profile,
        )

    def story_prompt(self, context: PromptContext) -> str:
        rule_block = "\n".join(f"- {rule}" for rule in BRAND_RULES)
        template = textwrap.dedent(
            f"""
            Role: You are the Dream Flow bedtime story engine.
            Brand tone: {BRAND_TONE}.
            Theme: {context.theme}
            Target length: {context.target_length} words.
            User profile: {context.profile_snippet}
            Guidance:
            {rule_block}

            Seed prompt: "{context.prompt}"

            Produce a cohesive multi-paragraph story with soft scene breaks.
            Story:
            """
        )
        return template.strip()

    def narration_prompt(self, context: PromptContext, story: str) -> str:
        return textwrap.dedent(
            f"""
            Narrate the following story with a {BRAND_TONE} delivery.
            Emphasize gentle pacing and subtle pauses.
            Story:
            {story}
            """
        ).strip()

    def visual_prompt(self, context: PromptContext, scene_text: str) -> str:
        calming_palette = ", ".join(context.profile.calming_elements) if context.profile and context.profile.calming_elements else context.theme
        favorite_characters = ", ".join(context.profile.favorite_characters) if context.profile and context.profile.favorite_characters else "dreamy companions"
        return (
            f"{context.theme} illustration, {BRAND_TONE} palette ({calming_palette}), "
            f"features {favorite_characters}, cinematic watercolor style, {scene_text}"
        )

