"""Smoke tests for advanced feature endpoints."""

import base64
from uuid import uuid4
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.dreamflow.main import create_app


@pytest.fixture
def mock_settings():
    settings = MagicMock(spec=Settings)
    settings.app_name = "Dream Flow API"
    settings.hf_token = "token"
    settings.story_model = "story-model"
    settings.supabase_url = "https://supabase.local"
    settings.supabase_service_role_key = "srv"
    settings.sentry_dsn = None
    settings.sentry_environment = "test"
    settings.sentry_traces_sample_rate = 0.0
    settings.asset_retention_days = 7
    return settings


@pytest.fixture
def advanced_client(mock_settings):
    """Create a FastAPI client where Supabase is intentionally unavailable."""
    with patch("app.dreamflow.main.get_settings", new=lambda: mock_settings):
        with (
            patch(
                "app.dreamflow.main.SupabaseClient", side_effect=ValueError("missing")
            ),
            patch("app.dreamflow.main.SubscriptionService", return_value=MagicMock()),
            patch("app.dreamflow.main.NotificationService", return_value=MagicMock()),
            patch("app.dreamflow.main.RecommendationEngine", return_value=MagicMock()),
        ):
            app = create_app(mock_settings)
            yield TestClient(app)


def test_maestro_insights_fallback(advanced_client):
    response = advanced_client.get("/api/v1/maestro/insights")
    assert response.status_code == 200
    body = response.json()
    assert "nightly_tip" in body
    assert body["quick_actions"], "Expected default quick actions"


def test_maestro_quick_action_logs(advanced_client):
    response = advanced_client.post(
        "/api/v1/maestro/quick-actions",
        json={"action_id": "lights_dim", "value": 50},
    )
    assert response.status_code == 202


def test_moodboard_inspiration_placeholder(advanced_client):
    response = advanced_client.post(
        "/api/v1/moodboard/inspiration",
        json={
            "type": "sketch",
            "caption": "Ocean sparks",
            "strokes": [{"points": [{"x": 0.1, "y": 0.2}]}],
            "caregiver_consent": True,
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert len(body["frames"]) == 3


def test_moodboard_requires_consent(advanced_client):
    payload = {
        "type": "photo",
        "data": base64.b64encode(b"sample image bytes").decode("utf-8"),
        "caregiver_consent": False,
    }
    response = advanced_client.post("/api/v1/moodboard/inspiration", json=payload)
    assert response.status_code == 422


def test_reflection_submission_without_supabase(advanced_client):
    payload = {
        "mood": "calm",
        "note": "Loved the lantern ritual",
        "tags": ["lantern"],
    }
    response = advanced_client.post("/api/v1/reflections", json=payload)
    assert response.status_code == 201


def test_reflection_insights_empty(advanced_client):
    response = advanced_client.get("/api/v1/reflections/insights")
    assert response.status_code == 200
    body = response.json()
    assert body["streak"] == 0
    assert body["celebrations"]["weekly_recap"]["entries_logged"] == 0
    assert body["weekly_clusters"] == []
    assert body["recommendations"] == []


def test_run_smart_scene_default(advanced_client):
    response = advanced_client.post(
        "/api/v1/smart-scenes/run",
        json={"scene_id": "scene_family", "user_id": str(uuid4())},
    )
    assert response.status_code == 202
    assert response.json()["status"] == "queued"
