from __future__ import annotations

import json
import logging
import textwrap
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Optional, Sequence
import re

from ..dreamflow.schemas import StoryRequest, UserProfile
from ..shared.config import get_settings


class PromptBuilderMode(str, Enum):
    """Mode for prompt building - determines tone and style."""

    BEDTIME_STORY = "bedtime_story"
    ASMR = "asmr"
    MINDFULNESS = "mindfulness"
    BRANDED_WELLNESS = "branded_wellness"


# Mode-specific brand tones
BRAND_TONES = {
    PromptBuilderMode.BEDTIME_STORY: "soothing, empathetic, imaginative, bedtime-safe",
    PromptBuilderMode.ASMR: "gentle, whisper-soft, sensory-focused, calming",
    PromptBuilderMode.MINDFULNESS: "peaceful, present-moment, introspective, grounding",
    PromptBuilderMode.BRANDED_WELLNESS: "professional, wellness-focused, brand-aligned, soothing",
}

# Mode-specific brand rules
BRAND_RULESETS = {
    PromptBuilderMode.BEDTIME_STORY: [
        "Never include violence, fear, or harsh language.",
        "Prioritize gentle sensory imagery (soft light, cozy textures, calm sounds).",
        "Encourage positive self-belief and emotional regulation.",
        "Keep sentences short-to-medium for easy listening.",
    ],
    PromptBuilderMode.ASMR: [
        "Focus on sensory triggers: textures, sounds, gentle movements.",
        "Use descriptive language that evokes physical sensations.",
        "Maintain slow, deliberate pacing with natural pauses.",
        "Avoid sudden changes or jarring transitions.",
    ],
    PromptBuilderMode.MINDFULNESS: [
        "Emphasize present-moment awareness and grounding techniques.",
        "Use breath-focused language and body awareness cues.",
        "Encourage non-judgmental observation of thoughts and feelings.",
        "Include gentle guidance for emotional regulation.",
    ],
    PromptBuilderMode.BRANDED_WELLNESS: [
        "Maintain brand voice and messaging guidelines.",
        "Ensure sponsor-safe content with no controversial topics.",
        "Prioritize wellness and positive lifestyle messaging.",
        "Keep content professional yet approachable.",
    ],
}

# Backwards-compatible alias expected by older tests/imports
BRAND_RULES = BRAND_RULESETS[PromptBuilderMode.BEDTIME_STORY]

# Default for backward compatibility
BRAND_TONE = BRAND_TONES[PromptBuilderMode.BEDTIME_STORY]

DEFAULT_VISUAL_STYLE_FRAGMENT = (
    "storybook watercolor and gouache illustration, soft dreamy glow, pastel color palette, "
    "subtle paper texture, gentle vignette, rounded shapes, cozy bedtime mood, child-safe"
)

CLIP_STOPWORDS = {
    "a",
    "an",
    "and",
    "are",
    "as",
    "at",
    "be",
    "but",
    "by",
    "for",
    "from",
    "in",
    "into",
    "is",
    "it",
    "its",
    "of",
    "on",
    "or",
    "so",
    "that",
    "the",
    "their",
    "there",
    "these",
    "they",
    "this",
    "those",
    "to",
    "with",
}


@dataclass
class PromptContext:
    prompt: str
    theme: str
    target_length: int
    profile: Optional[UserProfile]
    child_age: Optional[int] = None  # Age of child for age-appropriate content
    language: str = "en"  # Language code for story generation

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
            items.append(
                f"Favorite characters: {', '.join(self.profile.favorite_characters)}"
            )
        if self.profile.calming_elements:
            items.append(
                f"Calming elements: {', '.join(self.profile.calming_elements)}"
            )
        return " | ".join(items)


logger = logging.getLogger(__name__)


def _normalize_clip_token(word: str) -> str:
    return re.sub(r"[^0-9a-zA-Z]+", "", word).lower()


def summarize_prompt_for_clip(
    text: str,
    max_words: int = 55,
    preserve_phrases: Sequence[str] | None = None,
) -> str:
    """
    Preserve the primary subject while trimming prompts to CLIP-friendly lengths.
    We keep the first sentence intact, then add unique high-signal keywords until we reach the limit.
    """
    if not text:
        return text

    words = text.split()
    if len(words) <= max_words or max_words <= 0:
        return text

    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    primary_sentence = sentences[0] if sentences else text
    primary_words = primary_sentence.split()

    if len(primary_words) >= max_words:
        clipped = " ".join(primary_words[:max_words])
        # Only warn if truncation is significant (>10% loss)
        if len(words) > max_words * 1.1:
            logger.info(
                "Primary clause exceeded CLIP limit; truncated to %s words (original %s).",
                max_words,
                len(words),
            )
        return clipped

    kept: list[str] = primary_words[:]
    used_tokens = {_normalize_clip_token(w) for w in kept if _normalize_clip_token(w)}
    normalized_text = text.lower()
    preserve_list = [
        phrase.strip()
        for phrase in (preserve_phrases or [])
        if phrase and phrase.strip()
    ]
    remaining_slots = max_words - len(kept)

    def _append_word(word: str, slots: int) -> int:
        if slots <= 0:
            return slots
        token = _normalize_clip_token(word)
        if not token or token in used_tokens:
            return slots
        kept.append(word)
        used_tokens.add(token)
        return slots - 1

    for phrase in preserve_list:
        if remaining_slots <= 0:
            break
        if phrase.lower() not in normalized_text:
            continue
        for word in phrase.split():
            prev_slots = remaining_slots
            remaining_slots = _append_word(word, remaining_slots)
            if remaining_slots == prev_slots:
                continue
            if remaining_slots <= 0:
                break

    remaining_words = words[len(primary_words) :]

    for word in remaining_words:
        if remaining_slots <= 0:
            break
        token = _normalize_clip_token(word)
        if not token or token in used_tokens or token in CLIP_STOPWORDS:
            continue
        kept.append(word)
        used_tokens.add(token)
        remaining_slots -= 1

    if remaining_slots > 0:
        for word in remaining_words:
            if remaining_slots <= 0:
                break
            if word in kept:
                continue
            kept.append(word)
            remaining_slots -= 1

    if len(kept) > max_words:
        kept = kept[:max_words]

    logger.info(
        "Visual prompt summarized from %s to %s words for CLIP safety (subject preserved).",
        len(words),
        len(kept),
    )
    return " ".join(kept)


class PromptBuilder:
    def __init__(
        self,
        mode: PromptBuilderMode = PromptBuilderMode.BEDTIME_STORY,
        visual_style_fragment: str | None = None,
    ):
        """
        Initialize PromptBuilder with lazy-loading presets.

        Args:
            mode: Prompt building mode (BEDTIME_STORY, ASMR, MINDFULNESS, BRANDED_WELLNESS)
        """
        self.mode = mode
        self._config_path = Path(__file__).parent / "story_presets.json"
        self._presets: dict | None = None
        settings_style = None
        if visual_style_fragment is None:
            try:
                settings = get_settings()
                settings_style = getattr(settings, "global_visual_style_fragment", None)
            except Exception:
                settings_style = None
        self.visual_style_fragment = (
            visual_style_fragment or settings_style or DEFAULT_VISUAL_STYLE_FRAGMENT
        )

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

    def to_context(self, payload: StoryRequest, child_age: Optional[int] = None) -> PromptContext:
        # Determine language - use primary_language if provided, otherwise fall back to language field
        language = payload.primary_language or payload.language or "en"
        
        context = PromptContext(
            prompt=payload.prompt,
            theme=payload.theme,
            target_length=payload.target_length,
            profile=payload.profile,
            child_age=child_age,
            language=language,
        )
        
        # Add bilingual language info to context if provided
        if payload.primary_language and payload.secondary_language:
            setattr(context, 'primary_language', payload.primary_language)
            setattr(context, 'secondary_language', payload.secondary_language)
            # Log for debugging
            import logging
            logger = logging.getLogger(__name__)
            logger.info(f"Bilingual story requested: primary={payload.primary_language}, secondary={payload.secondary_language}")
        
        return context

    def story_prompt(self, context: PromptContext) -> str:
        """Generate story prompt based on current mode."""
        brand_tone = BRAND_TONES[self.mode]
        rules = BRAND_RULESETS[self.mode]
        rule_block = "\n".join(f"- {rule}" for rule in rules)

        # Age-specific adjustments
        age_guidance = ""
        if context.child_age is not None:
            if context.child_age < 5:
                # Ages 3-5: Very simple, short sentences, familiar concepts
                age_guidance = (
                    "\nAge-specific guidance (ages 3-5):\n"
                    "- Use very simple words and short sentences (5-8 words each).\n"
                    "- Focus on familiar concepts: animals, family, bedtime, toys.\n"
                    "- Use repetition and simple patterns.\n"
                    "- Keep story under 200 words.\n"
                    "- Use concrete, visual imagery (big, soft, warm, cozy)."
                )
                # Adjust target length for younger children
                context.target_length = min(context.target_length, 200)
            elif context.child_age < 9:
                # Ages 6-8: Slightly more complex, but still simple
                age_guidance = (
                    "\nAge-specific guidance (ages 6-8):\n"
                    "- Use simple to medium sentences (8-12 words each).\n"
                    "- Introduce basic adventure and problem-solving.\n"
                    "- Include friendly characters and gentle challenges.\n"
                    "- Keep story engaging but not overstimulating.\n"
                    "- Use descriptive but accessible language."
                )
                context.target_length = min(context.target_length, 350)
            else:
                # Ages 9-12: More complex narratives
                age_guidance = (
                    "\nAge-specific guidance (ages 9-12):\n"
                    "- Can use more complex sentences and vocabulary.\n"
                    "- Include character development and plot progression.\n"
                    "- Can explore themes like friendship, growth, discovery.\n"
                    "- Maintain calming, bedtime-appropriate tone.\n"
                    "- Use richer descriptive language."
                )

        # Mode-specific role descriptions
        role_descriptions = {
            PromptBuilderMode.BEDTIME_STORY: "You are the Dream Flow bedtime story engine.",
            PromptBuilderMode.ASMR: "You are a professional ASMR script writer.",
            PromptBuilderMode.MINDFULNESS: "You are a mindfulness meditation guide and content creator.",
            PromptBuilderMode.BRANDED_WELLNESS: "You are a professional wellness content writer.",
        }

        role = role_descriptions[self.mode]

        # Language-specific instructions
        language_instruction = ""
        # Check if bilingual generation is requested
        if hasattr(context, 'primary_language') and hasattr(context, 'secondary_language'):
            primary_lang = getattr(context, 'primary_language', None)
            secondary_lang = getattr(context, 'secondary_language', None)
            if primary_lang and secondary_lang and primary_lang != secondary_lang:
                # Bilingual generation requested
                lang_names = {
                    "en": "English",
                    "es": "Spanish",
                    "fr": "French",
                    "ja": "Japanese",
                }
                primary_name = lang_names.get(primary_lang.lower(), primary_lang.upper())
                secondary_name = lang_names.get(secondary_lang.lower(), secondary_lang.upper())
                primary_code = primary_lang.upper()
                secondary_code = secondary_lang.upper()
                # Very explicit bilingual instruction - put at START of prompt for TinyLlama
                language_instruction = (
                    f"CRITICAL FORMATTING RULE - YOU MUST FOLLOW THIS:\n"
                    f"Write EVERY paragraph in this EXACT format:\n"
                    f"[{primary_code}: {primary_name} sentence here] [{secondary_code}: {secondary_name} sentence here]\n"
                    f"Example paragraph:\n"
                    f"[{primary_code}: Once upon a time, there was a fox named Nova.] [{secondary_code}: Érase una vez, un zorro llamado Nova.]\n"
                    f"YOU MUST include BOTH languages in EVERY paragraph. Use this format for the entire story.\n"
                    f"NEVER write plain text without [{primary_code}: ] and [{secondary_code}: ] markers.\n"
                    f"EVERY sentence must be wrapped in the bracket format shown above.\n\n"
                )
            elif context.language != "en":
                # Single language (non-English)
                language_map = {
                    "es": "Escribe la historia en español.",
                    "fr": "Écris l'histoire en français.",
                    "ja": "物語を日本語で書いてください。",
                }
                language_instruction = f"\nLanguage: {language_map.get(context.language, 'Write the story in the requested language.')}"
        elif context.language != "en":
            # Single language (non-English) - legacy support
            language_map = {
                "es": "Escribe la historia en español.",
                "fr": "Écris l'histoire en français.",
                "ja": "物語を日本語で書いてください。",
            }
            language_instruction = f"\nLanguage: {language_map.get(context.language, 'Write the story in the requested language.')}"
        
        # For bilingual stories, put the format instruction FIRST so the model sees it immediately
        bilingual_header = ""
        if language_instruction and "CRITICAL" in language_instruction:
            bilingual_header = language_instruction + "\n\n"
            language_instruction = ""  # Remove from end since we put it at start
        
        template = textwrap.dedent(
            f"""
            {bilingual_header}Role: {role}
            Brand tone: {brand_tone}.
            Theme: {context.theme}
            Target length: {context.target_length} words.
            User profile: {context.profile_snippet}
            {age_guidance}
            {language_instruction}
            Guidance:
            {rule_block}

            Seed prompt: "{context.prompt}"

            Produce a cohesive multi-paragraph story with soft scene breaks.
            Story:
            """
        )
        return template.strip()

    def narration_prompt(self, context: PromptContext, story: str) -> str:
        """Generate narration prompt based on current mode."""
        brand_tone = BRAND_TONES[self.mode]

        # Mode-specific narration instructions
        narration_instructions = {
            PromptBuilderMode.BEDTIME_STORY: "Emphasize gentle pacing and subtle pauses.",
            PromptBuilderMode.ASMR: "Use whisper-soft delivery with emphasis on sensory words. Include natural pauses and gentle breathing sounds.",
            PromptBuilderMode.MINDFULNESS: "Use calm, measured pacing with clear enunciation. Include natural pauses for reflection.",
            PromptBuilderMode.BRANDED_WELLNESS: "Use professional, warm delivery with clear articulation and appropriate pacing.",
        }

        instruction = narration_instructions[self.mode]

        return textwrap.dedent(
            f"""
            Narrate the following story with a {brand_tone} delivery.
            {instruction}
            Story:
            {story}
            """
        ).strip()

    def visual_prompt(self, context: PromptContext, scene_text: str) -> str:
        """Generate a CLIP-safe visual prompt focused on the scene content."""
        brand_tone = BRAND_TONES[self.mode]
        favorite_characters = (
            ", ".join(context.profile.favorite_characters)
            if context.profile and context.profile.favorite_characters
            else "dreamy companions"
        )

        visual_styles = {
            PromptBuilderMode.BEDTIME_STORY: "storybook watercolor illustration",
            PromptBuilderMode.ASMR: "soft focus calming illustration",
            PromptBuilderMode.MINDFULNESS: "serene minimalist illustration",
            PromptBuilderMode.BRANDED_WELLNESS: "clean professional illustration",
        }
        style = visual_styles[self.mode]

        import re

        # Remove bilingual markers and collapse whitespace
        cleaned_scene = re.sub(
            r"\[(EN|ES|FR|JA):\s*([^\]]+)\]",
            r"\2",
            scene_text,
            flags=re.IGNORECASE,
        )
        cleaned_scene = re.sub(r"\s+", " ", cleaned_scene).strip()

        # Use the first sentence (or up to 160 chars) to keep nouns up front
        first_sentence = cleaned_scene.split(".")[0][:160].strip()
        if not first_sentence:
            first_sentence = context.theme

        motif_seed = (context.prompt or context.theme or "").strip()
        motif_seed = re.sub(r"\s+", " ", motif_seed)
        motif_snippet = motif_seed.split(".")[0][:120].strip()

        environment = (context.theme or "dreamy bedtime world").strip()
        calming_palette = (
            ", ".join(context.profile.calming_elements)
            if context.profile and context.profile.calming_elements
            else environment
        )
        style_fragment = self._clip_for_clip(
            self.visual_style_fragment,
            max_tokens=20,
        )

        prompt_segments = [
            f"{environment} illustration of {first_sentence}.",
            f"Focus on {favorite_characters}.",
        ]
        if motif_snippet:
            prompt_segments.append(f"Action cue: {motif_snippet}.")
        prompt_segments.extend(
            [
                f"Palette: {calming_palette}; {brand_tone}.",
                "Wide shot, clear subject, gentle depth of field.",
                "Soft lantern glow and moonlit rim light.",
                f"{style}, cinematic watercolor style, {style_fragment}.",
            ]
        )
        prompt = " ".join(prompt_segments)
        prompt = self._clip_for_clip(
            prompt, preserve_phrases=["cinematic watercolor style"]
        )

        return prompt

    @staticmethod
    def _clip_for_clip(
        text: str, max_tokens: int = 55, preserve_phrases: Sequence[str] | None = None
    ) -> str:
        """Approximate CLIP token limit via subject-preserving summarization."""
        return summarize_prompt_for_clip(
            text, max_words=max_tokens, preserve_phrases=preserve_phrases
        )