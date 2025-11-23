import pytest

from app.guardrails import GuardrailError, PromptSanitizer


class TestPromptSanitizer:
    def setup_method(self):
        self.sanitizer = PromptSanitizer()

    def test_allows_clean_prompt(self):
        prompt = "Gentle waves carry the 🌿 leaves across the moonlit lake."
        sanitized = self.sanitizer.enforce(prompt, prompt_type="narration")
        assert sanitized == prompt

    def test_blocks_banned_term(self):
        with pytest.raises(GuardrailError) as exc:
            self.sanitizer.enforce("This tale mentions violence and conflict.", prompt_type="visual")

        assert exc.value.violations
        assert any("violence" in violation.detail for violation in exc.value.violations)

    def test_blocks_disallowed_emoji(self):
        with pytest.raises(GuardrailError) as exc:
            self.sanitizer.enforce("The brave hero ⚔️ saves the day.", prompt_type="visual")

        assert any("Character" in violation.detail for violation in exc.value.violations)
import yaml

from app.guardrails import ContentGuard, GuardrailConfigLoader
from app.schemas import UserProfile


def write_config(path, payload):
    path.write_text(yaml.safe_dump(payload), encoding="utf-8")


def test_content_guard_flags_terms_from_yaml(tmp_path):
    config_file = tmp_path / "guardrails.yaml"
    write_config(
        config_file,
        {
            "defaults": {
                "banned_terms": ["goblin"],
                "tone_thresholds": {"max_exclamation_points": 10, "max_all_caps_chunks": 10},
            }
        },
    )

    guard = ContentGuard(config_loader=GuardrailConfigLoader(config_file))

    violations = guard.check_story("A friendly GOBLIN appears at dusk.")

    assert len(violations) == 1
    assert violations[0].category == "safety"
    assert "goblin" in violations[0].detail


def test_profile_overrides_tone_thresholds(tmp_path):
    config_file = tmp_path / "guardrails.yaml"
    write_config(
        config_file,
        {
            "defaults": {
                "banned_terms": [],
                "tone_thresholds": {"max_exclamation_points": 10, "max_all_caps_chunks": 10},
            },
            "profiles": {
                "anxious": {
                    "tone_thresholds": {"max_exclamation_points": 2, "max_all_caps_chunks": 1},
                }
            },
        },
    )
    guard = ContentGuard(config_loader=GuardrailConfigLoader(config_file))
    profile = UserProfile(
        mood="Anxious",
        routine="Nighttime",
        preferences=[],
        favorite_characters=[],
        calming_elements=[],
    )

    story = "Soft waves roll..." + "!" * 3

    violations = guard.check_story(story, profile=profile)

    assert any(v.category == "tone" for v in violations)


def test_guardrails_hot_reload_without_restart(tmp_path):
    config_file = tmp_path / "guardrails.yaml"
    write_config(
        config_file,
        {
            "defaults": {
                "banned_terms": [],
                "tone_thresholds": {"max_exclamation_points": 6, "max_all_caps_chunks": 5},
            },
        },
    )
    guard = ContentGuard(config_loader=GuardrailConfigLoader(config_file))

    assert guard.check_story("A peaceful meadow.") == []

    write_config(
        config_file,
        {
            "defaults": {
                "banned_terms": ["storm"],
                "tone_thresholds": {"max_exclamation_points": 6, "max_all_caps_chunks": 5},
            },
        },
    )

    violations = guard.check_story("Storm clouds gather over the hill.")

    assert any(v.category == "safety" for v in violations)

