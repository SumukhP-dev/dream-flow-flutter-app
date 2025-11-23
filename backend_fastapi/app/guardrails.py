from __future__ import annotations

import logging
import re
import string
import threading
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple

import yaml

from .config import PROJECT_ROOT
from .schemas import UserProfile


logger = logging.getLogger(__name__)

DEFAULT_BANNED = {
    "violence",
    "blood",
    "weapon",
    "scream",
    "monster",
    "kill",
    "death",
    "nightmare",
}

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

GUARDRAIL_CONFIG_PATH = PROJECT_ROOT / "config" / "guardrails.yaml"


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


class GuardrailConfigLoader:
    """Loads guardrail settings from YAML with opt-in hot reload."""

    def __init__(self, config_path: Path | None = None):
        self.config_path = Path(config_path) if config_path else GUARDRAIL_CONFIG_PATH
        self._lock = threading.Lock()
        self._config: dict | None = None
        self._last_mtime_ns: int | None = None

    def resolve_rules(self, profile: UserProfile | None = None) -> GuardrailRules:
        config = self._get_config()
        defaults = config.get("defaults", {})

        banned_terms = self._merge_terms(defaults.get("banned_terms"), fallback=DEFAULT_BANNED)
        tone_thresholds = self._compose_thresholds(defaults.get("tone_thresholds"))

        profiles = config.get("profiles", {})
        profile_key = self._match_profile_key(profiles, profile)
        if profile_key:
            profile_cfg = profiles.get(profile_key, {})
            banned_terms |= self._merge_terms(profile_cfg.get("banned_terms"))
            tone_thresholds = self._compose_thresholds(profile_cfg.get("tone_thresholds"), tone_thresholds)

        return GuardrailRules(
            banned_terms=banned_terms,
            tone_thresholds=tone_thresholds,
            profile_key=profile_key,
        )

    def _merge_terms(self, terms: Iterable[str] | None, *, fallback: Iterable[str] | None = None) -> set[str]:
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
                logger.warning("Failed to load guardrail config from %s: %s", self.config_path, exc)
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
    def __init__(self, config_loader: GuardrailConfigLoader | None = None):
        self.config_loader = config_loader or GuardrailConfigLoader()

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
                issues.append(
                    GuardrailViolation(
                        category="safety",
                        detail=f"Contains banned term '{term}' which breaks the soothing brand promise.",
                    )
                )
        if self._is_overstimulating(story_text, rules.tone_thresholds):
            issues.append(
                GuardrailViolation(
                    category="tone",
                    detail="Story reads overstimulating (too many exclamation marks or all caps).",
                )
            )
        return issues

    @staticmethod
    def _is_overstimulating(text: str, thresholds: ToneThresholds) -> bool:
        if text.count("!") > thresholds.max_exclamation_points:
            return True
        upper_chunks = [segment for segment in text.split() if len(segment) > 5 and segment.isupper()]
        return len(upper_chunks) > thresholds.max_all_caps_chunks


@dataclass
class GuardrailError(Exception):
    violations: List[GuardrailViolation]
    content: str = ""
    prompt_type: str = "prompt"

    def __post_init__(self):
        super().__init__("Prompt failed guardrail checks.")


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

    def _enforce_character_whitelist(self, text: str) -> Tuple[str, List[GuardrailViolation]]:
        violations: List[GuardrailViolation] = []
        sanitized_chars: list[str] = []
        seen: set[str] = set()

        for char in text:
            if char in ALLOWED_WHITESPACE or char in ALLOWED_BASIC_CHARS:
                sanitized_chars.append(char)
                continue

            if char in self.emoji_whitelist:
                sanitized_chars.append(char)
                continue

            if char not in seen:
                category = "emoji_whitelist" if self._looks_like_emoji(char) else "character_whitelist"
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
        return "EMOJI" in name or ("FACE" in name and "\u2600" <= char <= "\U0001FAFF")

