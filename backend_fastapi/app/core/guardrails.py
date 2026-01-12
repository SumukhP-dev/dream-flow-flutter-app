from __future__ import annotations

import base64
import logging
import re
import string
import threading
import unicodedata
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Iterable, List, Tuple

import yaml

from ..shared.config import PROJECT_ROOT
from ..dreamflow.schemas import MoodboardInspirationRequest, UserProfile


logger = logging.getLogger(__name__)


class GuardrailMode(str, Enum):
    """Mode for guardrail enforcement - determines rule sets."""

    BEDTIME_SAFETY = "bedtime_safety"
    BRAND_COMPLIANCE = "brand_compliance"


# Mode-specific banned terms
BANNED_TERMS = {
    GuardrailMode.BEDTIME_SAFETY: {
        "violence",
        "blood",
        "weapon",
        "scream",
        "monster",
        "kill",
        "death",
        "nightmare",
    },
    GuardrailMode.BRAND_COMPLIANCE: {
        "violence",
        "controversial",
        "political",
        "offensive",
        "inappropriate",
        "explicit",
        "profanity",
        "hate speech",
    },
}

# Default for backward compatibility
DEFAULT_BANNED = BANNED_TERMS[GuardrailMode.BEDTIME_SAFETY]

DEFAULT_TONE_LIMITS = {
    "max_exclamation_points": 6,
    "max_all_caps_chunks": 5,
}

ALLOWED_EMOJIS = {
    "🌿",
    "💧",
    "🪨",
    "🔥",
    "🏕️",
    "📚",
    "🌊",
    "✨",
    "🌲",
    "🌌",
    "🌙",
    "⭐",
    "💤",
    "🪄",
}

ALLOWED_WHITESPACE = {" ", "\n", "\t", "\r"}
ALLOWED_BASIC_CHARS = set(string.ascii_letters + string.digits + string.punctuation)

# Allow common accented characters for bilingual support (Spanish, French, Japanese romanization, etc.)
ALLOWED_EXTENDED_CHARS = set(
    "áéíóúüñÁÉÍÓÚÜÑ¿¡"  # Spanish (including inverted punctuation)
    "àèìòùâêîôûëïçÀÈÌÒÙÂÊÎÔÛËÏÇ"  # French
    "äöÄÖß"  # German
    "āēīōūĀĒĪŌŪ"  # Japanese romanization (macrons)
)

BANNED_PHRASE_REPLACEMENTS = {
    "violence": "gentle adventure",
    "blood": "soft light",
    "weapon": "kind tool",
    "scream": "whisper",
    "monster": "friendly guide",
    "kill": "comfort",
    "death": "rest",
    "nightmare": "dream",
}

GUARDRAIL_CONFIG_PATH = PROJECT_ROOT / "backend_fastapi" / "config" / "guardrails.yaml"


@dataclass
class GuardrailViolation:
    category: str
    detail: str


@dataclass(frozen=True)
class ToneThresholds:
    max_exclamation_points: int
    max_all_caps_chunks: int


@dataclass(frozen=True)
class GuardrailRules:
    banned_terms: set[str]
    tone_thresholds: ToneThresholds
    profile_key: str | None = None


@dataclass
class MoodboardInspectionResult:
    requires_moderation: bool


class GuardrailConfigLoader:
    """Loads guardrail settings from YAML with opt-in hot reload."""

    def __init__(
        self,
        config_path: Path | None = None,
        mode: GuardrailMode = GuardrailMode.BEDTIME_SAFETY,
    ):
        """
        Initialize GuardrailConfigLoader.

        Args:
            config_path: Path to guardrail config YAML file
            mode: Guardrail mode (BEDTIME_SAFETY or BRAND_COMPLIANCE)
        """
        self.config_path = Path(config_path) if config_path else GUARDRAIL_CONFIG_PATH
        self.mode = mode
        self._lock = threading.Lock()
        self._config: dict | None = None
        self._last_mtime_ns: int | None = None

    def resolve_rules(self, profile: UserProfile | None = None) -> GuardrailRules:
        config = self._get_config()
        defaults = config.get("defaults", {})

        # Start with mode-specific banned terms
        mode_banned = BANNED_TERMS.get(self.mode, DEFAULT_BANNED)
        banned_terms = self._merge_terms(
            defaults.get("banned_terms"), fallback=mode_banned
        )
        tone_thresholds = self._compose_thresholds(defaults.get("tone_thresholds"))

        profiles = config.get("profiles", {})
        profile_key = self._match_profile_key(profiles, profile)
        if profile_key:
            profile_cfg = profiles.get(profile_key, {})
            banned_terms |= self._merge_terms(profile_cfg.get("banned_terms"))
            tone_thresholds = self._compose_thresholds(
                profile_cfg.get("tone_thresholds"), tone_thresholds
            )

        return GuardrailRules(
            banned_terms=banned_terms,
            tone_thresholds=tone_thresholds,
            profile_key=profile_key,
        )

    def _merge_terms(
        self, terms: Iterable[str] | None, *, fallback: Iterable[str] | None = None
    ) -> set[str]:
        source = fallback if terms is None else terms
        if not source:
            return set()
        return {str(term).lower() for term in source}

    def _compose_thresholds(
        self,
        overrides: dict | None,
        base: ToneThresholds | None = None,
    ) -> ToneThresholds:
        data = {
            "max_exclamation_points": DEFAULT_TONE_LIMITS["max_exclamation_points"],
            "max_all_caps_chunks": DEFAULT_TONE_LIMITS["max_all_caps_chunks"],
        }
        if base:
            data["max_exclamation_points"] = base.max_exclamation_points
            data["max_all_caps_chunks"] = base.max_all_caps_chunks
        if overrides:
            data.update({k: int(v) for k, v in overrides.items() if v is not None})
        return ToneThresholds(
            max_exclamation_points=int(data["max_exclamation_points"]),
            max_all_caps_chunks=int(data["max_all_caps_chunks"]),
        )

    def _get_config(self) -> dict:
        with self._lock:
            if self._config is None or self._should_reload():
                self._reload()
            return self._config or {}

    def _should_reload(self) -> bool:
        if not self.config_path.exists():
            return self._config is None
        try:
            current_mtime = self.config_path.stat().st_mtime_ns
        except OSError:
            return False
        return current_mtime != self._last_mtime_ns

    def _reload(self) -> None:
        raw: dict | None = None
        if self.config_path.exists():
            try:
                raw = yaml.safe_load(self.config_path.read_text(encoding="utf-8"))
            except Exception as exc:  # pragma: no cover - log unexpected YAML errors
                logger.warning(
                    "Failed to load guardrail config from %s: %s", self.config_path, exc
                )
        sanitized = self._sanitize(raw)
        self._config = sanitized
        try:
            self._last_mtime_ns = self.config_path.stat().st_mtime_ns
        except OSError:
            self._last_mtime_ns = None

    @staticmethod
    def _sanitize(raw: dict | None) -> dict:
        data = raw or {}
        defaults = data.get("defaults") or {}
        profiles = data.get("profiles") or {}

        normalized_profiles = {}
        for key, value in profiles.items():
            if not isinstance(value, dict):
                continue
            normalized_profiles[str(key).strip().lower()] = {
                "banned_terms": value.get("banned_terms"),
                "tone_thresholds": value.get("tone_thresholds"),
            }

        return {
            "defaults": {
                "banned_terms": defaults.get("banned_terms"),
                "tone_thresholds": defaults.get("tone_thresholds"),
            },
            "profiles": normalized_profiles,
        }

    @staticmethod
    def _match_profile_key(profiles: dict, profile: UserProfile | None) -> str | None:
        if not profiles or not profile:
            return None

        candidates: list[str] = []
        if profile.mood:
            candidates.append(profile.mood)
        if profile.routine:
            candidates.append(profile.routine)
        candidates.extend(profile.preferences or [])
        candidates.extend(profile.calming_elements or [])

        for candidate in candidates:
            key = str(candidate).strip().lower()
            if key and key in profiles:
                return key
        return None


class ContentGuard:
    def __init__(
        self,
        config_loader: GuardrailConfigLoader | None = None,
        mode: GuardrailMode = GuardrailMode.BEDTIME_SAFETY,
    ):
        """
        Initialize ContentGuard.

        Args:
            config_loader: Optional GuardrailConfigLoader instance
            mode: Guardrail mode (BEDTIME_SAFETY or BRAND_COMPLIANCE)
        """
        self.mode = mode
        self.config_loader = config_loader or GuardrailConfigLoader(mode=mode)
        
        # Initialize Azure Content Safety client if enabled
        self._azure_content_safety_client = None
        try:
            from ..core.azure_content_safety import get_content_safety_client
            self._azure_content_safety_client = get_content_safety_client()
        except Exception as e:
            logger.debug(f"Azure Content Safety client not available: {e}")

    def check_story(
        self,
        story_text: str,
        profile: UserProfile | None = None,
        child_mode: bool = False,
        content_filter_level: str = "standard",
    ) -> List[GuardrailViolation]:
        """
        Check story against guardrails.

        Args:
            story_text: Story text to check
            profile: User profile for context
            child_mode: If True, apply stricter child-safe filters
            content_filter_level: 'strict', 'standard', or 'relaxed' for child mode

        Returns:
            List of guardrail violations
        """
        issues: List[GuardrailViolation] = []
        rules = self.config_loader.resolve_rules(profile)

        # Apply stricter filters for child mode
        if child_mode:
            if content_filter_level == "strict":
                # Additional banned terms for strict child mode
                child_banned = rules.banned_terms | {
                    "scary",
                    "frightening",
                    "dark",
                    "shadow",
                    "loud",
                    "angry",
                    "fight",
                    "battle",
                }
                rules = GuardrailRules(
                    banned_terms=child_banned,
                    tone_thresholds=ToneThresholds(
                        max_exclamation_points=3,  # Stricter for children
                        max_all_caps_chunks=2,
                    ),
                    profile_key=rules.profile_key,
                )
            elif content_filter_level == "standard":
                rules = GuardrailRules(
                    banned_terms=rules.banned_terms,
                    tone_thresholds=ToneThresholds(
                        max_exclamation_points=4,
                        max_all_caps_chunks=3,
                    ),
                    profile_key=rules.profile_key,
                )

        lowered = story_text.lower()
        for term in rules.banned_terms:
            if term in lowered:
                # Mode-specific violation messages
                if self.mode == GuardrailMode.BEDTIME_SAFETY:
                    detail = f"Contains banned term '{term}' which breaks the soothing brand promise."
                else:  # BRAND_COMPLIANCE
                    detail = f"Contains banned term '{term}' which violates brand compliance guidelines."

                issues.append(
                    GuardrailViolation(
                        category="safety"
                        if self.mode == GuardrailMode.BEDTIME_SAFETY
                        else "brand_compliance",
                        detail=detail,
                    )
                )
        if self._is_overstimulating(story_text, rules.tone_thresholds):
            issues.append(
                GuardrailViolation(
                    category="tone",
                    detail="Story reads overstimulating (too many exclamation marks or all caps).",
                )
            )
        
        # Azure Content Safety moderation (enhances keyword-based filtering)
        if self._azure_content_safety_client:
            try:
                from ..shared.config import get_settings
                
                settings = get_settings()
                severity_threshold = settings.azure_content_safety_severity_threshold
                if child_mode and content_filter_level == "strict":
                    # Use stricter threshold for child mode
                    severity_threshold = 1  # Lower threshold = stricter
                
                moderation_result = self._azure_content_safety_client.moderate_text(
                    text=story_text,
                    severity_threshold=severity_threshold,
                )
                
                if not moderation_result.get("is_safe", True):
                    # Extract unsafe categories
                    categories_analyzed = moderation_result.get("categories_analyzed", {})
                    unsafe_categories = [
                        cat for cat, data in categories_analyzed.items()
                        if data.get("severity", 0) >= severity_threshold
                    ]
                    
                    if unsafe_categories:
                        issues.append(
                            GuardrailViolation(
                                category="ai_moderation",
                                detail=f"Azure Content Safety detected unsafe content in categories: {', '.join(unsafe_categories)}",
                            )
                        )
                        logger.warning(
                            f"Azure Content Safety flagged story content: {unsafe_categories}"
                        )
            except Exception as e:
                # Fail open - don't block content if Azure moderation fails
                logger.warning(f"Azure Content Safety moderation failed, continuing with keyword-based checks: {e}")
        
        return issues

    def check_video_prompt(
        self,
        prompt: str,
        profile: UserProfile | None = None,
        child_mode: bool = False,
        content_filter_level: str = "standard",
    ) -> List[GuardrailViolation]:
        """
        Check video generation prompt against guardrails with COPPA-specific rules.
        
        Args:
            prompt: Video generation prompt to check
            profile: User profile for context
            child_mode: If True, apply stricter child-safe filters
            content_filter_level: 'strict', 'standard', or 'relaxed' for child mode
            
        Returns:
            List of guardrail violations
        """
        # Use same logic as check_story but with video-specific banned terms
        violations = self.check_story(
            prompt,
            profile=profile,
            child_mode=child_mode,
            content_filter_level=content_filter_level,
        )
        
        # Add video-specific COPPA rules
        if child_mode:
            video_banned_terms = {
                "scary", "frightening", "horror", "terror",
                "violence", "blood", "weapon", "fight", "battle",
                "dark", "shadow", "nightmare", "monster", "ghost",
                "death", "kill", "murder", "attack",
            }
            
            if content_filter_level == "strict":
                video_banned_terms.update({
                    "loud", "angry", "scream", "shout", "yell",
                    "danger", "fear", "afraid", "scared",
                })
            
            lowered = prompt.lower()
            for term in video_banned_terms:
                if term in lowered:
                    violations.append(
                        GuardrailViolation(
                            category="coppa",
                            detail=f"Video prompt contains '{term}' which violates COPPA safety guidelines for children.",
                        )
                    )
        
        return violations

    @staticmethod
    def _is_overstimulating(text: str, thresholds: ToneThresholds) -> bool:
        if text.count("!") > thresholds.max_exclamation_points:
            return True
        upper_chunks = [
            segment
            for segment in text.split()
            if len(segment) > 5 and segment.isupper()
        ]
        return len(upper_chunks) > thresholds.max_all_caps_chunks


@dataclass
class GuardrailError(Exception):
    violations: List[GuardrailViolation]
    content: str = ""
    prompt_type: str = "prompt"

    def __post_init__(self):
        super().__init__("Prompt failed guardrail checks.")


class MoodboardInputInspector:
    """Guardrail entry point dedicated to caregiver-provided inspiration assets."""

    def __init__(
        self,
        *,
        max_upload_bytes: int,
        guard: ContentGuard | None = None,
        coppa_face_filter: bool = False,
    ) -> None:
        self.max_upload_bytes = max_upload_bytes
        self.guard = guard or ContentGuard()
        self.coppa_face_filter = coppa_face_filter
        self._face_terms = {
            "face",
            "faces",
            "selfie",
            "crowd",
            "class",
            "friends",
            "party",
        }
        self._non_family_terms = {
            "class",
            "school",
            "camp",
            "party",
            "friends",
            "teammates",
        }

    def inspect(
        self, payload: MoodboardInspirationRequest
    ) -> MoodboardInspectionResult:
        if not payload.caregiver_consent:
            raise GuardrailError(
                violations=[
                    GuardrailViolation(
                        category="consent",
                        detail="Caregiver consent is required before uploading inspiration.",
                    )
                ],
                prompt_type="moodboard_inspiration",
            )

        requires_moderation = False
        caption = (payload.caption or "").strip()

        if caption:
            violations = self.guard.check_story(caption, child_mode=True)
            if violations:
                raise GuardrailError(
                    violations=violations,
                    content=caption,
                    prompt_type="moodboard_caption",
                )
            lowered = caption.lower()
            if any(term in lowered for term in self._face_terms):
                requires_moderation = True
            if self.coppa_face_filter and any(
                term in lowered for term in self._non_family_terms
            ):
                raise GuardrailError(
                    violations=[
                        GuardrailViolation(
                            category="coppa",
                            detail="Caption hints at non-family faces which violates COPPA guardrails.",
                        )
                    ],
                    content=caption,
                    prompt_type="moodboard_caption",
                )
        else:
            # Missing captions make moderation harder; flag for review.
            requires_moderation = True

        if payload.type == "photo":
            self._validate_photo_payload(payload)
        elif payload.type == "sketch":
            self._validate_sketch_payload(payload)
        else:
            raise ValueError("Inspiration type must be 'photo' or 'sketch'.")

        return MoodboardInspectionResult(requires_moderation=requires_moderation)

    def _validate_photo_payload(self, payload: MoodboardInspirationRequest) -> None:
        if not payload.data:
            raise ValueError("Photo inspiration must include a base64 payload.")
        try:
            decoded = base64.b64decode(payload.data, validate=True)
        except Exception as exc:
            raise ValueError("Unable to decode inspiration payload.") from exc
        if len(decoded) > self.max_upload_bytes:
            raise ValueError(
                f"Inspiration upload exceeds {self.max_upload_bytes // (1024 * 1024)}MB limit."
            )
        # Basic heuristic: very small images are suspicious/noisy and should be rejected.
        if len(decoded) < 1024:
            raise ValueError("Inspiration payload is too small to analyze safely.")

    def _validate_sketch_payload(self, payload: MoodboardInspirationRequest) -> None:
        if not payload.strokes:
            raise ValueError("Sketch inspiration requires at least one stroke.")
        for stroke in payload.strokes:
            if not stroke.points:
                raise ValueError("Sketch strokes must contain points.")
            if stroke.width <= 0 or stroke.width > 48:
                raise ValueError("Sketch stroke width must be between 0 and 48.")
            for point in stroke.points:
                x = point.x
                y = point.y
                if not (0 <= x <= 1 and 0 <= y <= 1):
                    raise ValueError(
                        "Sketch coordinates must be normalized between 0 and 1."
                    )


class PromptSanitizer:
    """Sanitize narration and visual prompts before model calls."""

    def __init__(
        self,
        banned_terms: Iterable[str] | None = None,
        emoji_whitelist: Iterable[str] | None = None,
    ) -> None:
        self.banned_terms = {term.lower() for term in (banned_terms or DEFAULT_BANNED)}
        self.emoji_whitelist = set(emoji_whitelist or ALLOWED_EMOJIS)

    def enforce(self, prompt: str, prompt_type: str) -> str:
        sanitized = prompt or ""
        violations: List[GuardrailViolation] = []

        sanitized, banned_violations = self._strip_banned_phrases(sanitized)
        violations.extend(banned_violations)

        sanitized, char_violations = self._enforce_character_whitelist(sanitized)
        violations.extend(char_violations)

        sanitized = self._normalize_whitespace(sanitized)

        if not sanitized.strip():
            violations.append(
                GuardrailViolation(
                    category="prompt_integrity",
                    detail=f"{prompt_type.capitalize()} prompt became empty after sanitization.",
                )
            )

        if violations:
            for violation in violations:
                logger.warning(
                    "Guardrail violation detected for %s prompt: %s",
                    prompt_type,
                    violation.detail,
                )
            raise GuardrailError(
                violations=violations,
                content=prompt,
                prompt_type=prompt_type,
            )

        return sanitized

    def _strip_banned_phrases(self, text: str) -> Tuple[str, List[GuardrailViolation]]:
        violations: List[GuardrailViolation] = []
        sanitized = text
        for term in self.banned_terms:
            pattern = re.compile(re.escape(term), re.IGNORECASE)
            if pattern.search(sanitized):
                replacement = BANNED_PHRASE_REPLACEMENTS.get(term, "")
                sanitized = pattern.sub(replacement, sanitized)
                action = "replaced" if replacement else "removed"
                violations.append(
                    GuardrailViolation(
                        category="prompt_safety",
                        detail=f"Banned term '{term}' {action} in prompt.",
                    )
                )
        return sanitized, violations

    def _enforce_character_whitelist(
        self, text: str
    ) -> Tuple[str, List[GuardrailViolation]]:
        violations: List[GuardrailViolation] = []
        sanitized_chars: list[str] = []
        seen: set[str] = set()

        for char in text:
            if char in ALLOWED_WHITESPACE or char in ALLOWED_BASIC_CHARS or char in ALLOWED_EXTENDED_CHARS:
                sanitized_chars.append(char)
                continue

            if char in self.emoji_whitelist:
                sanitized_chars.append(char)
                continue

            if char not in seen:
                category = (
                    "emoji_whitelist"
                    if self._looks_like_emoji(char)
                    else "character_whitelist"
                )
                violations.append(
                    GuardrailViolation(
                        category=category,
                        detail=f"Character '{char}' is not permitted in prompts.",
                    )
                )
                seen.add(char)

        return "".join(sanitized_chars), violations

    @staticmethod
    def _normalize_whitespace(text: str) -> str:
        normalized_lines = [" ".join(segment.split()) for segment in text.splitlines()]
        collapsed: list[str] = []
        previous_blank = False
        for line in normalized_lines:
            if not line:
                if not previous_blank:
                    collapsed.append("")
                previous_blank = True
                continue
            collapsed.append(line.strip())
            previous_blank = False

        # Remove leading/trailing empty entries
        while collapsed and not collapsed[0]:
            collapsed.pop(0)
        while collapsed and not collapsed[-1]:
            collapsed.pop()

        return "\n".join(collapsed)

    @staticmethod
    def _looks_like_emoji(char: str) -> bool:
        name = unicodedata.name(char, "")
        return "EMOJI" in name or ("FACE" in name and "\u2600" <= char <= "\U0001faff")
