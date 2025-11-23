"""
Tests for GET /api/v1/presets endpoint.

Tests ensure:
- Default prompts/themes are loaded from config file (story_presets.json)
- Featured worlds are correctly identified
- Error handling when config file is missing or invalid
"""

import contextlib
import json
from unittest.mock import MagicMock, patch, mock_open

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.prompting import PromptBuilder


@pytest.fixture
def mock_settings():
    """Create mock settings for testing."""
    settings = MagicMock(spec=Settings)
    settings.app_name = "Dream Flow API"
    settings.hf_token = "test_token"
    settings.story_model = "test/story-model"
    settings.tts_model = "test/tts-model"
    settings.image_model = "test/image-model"
    settings.max_new_tokens = 500
    settings.sentry_dsn = None
    settings.sentry_environment = "test"
    settings.sentry_traces_sample_rate = 0.0
    settings.asset_retention_days = 7
    return settings


@pytest.fixture
def client_factory(mock_settings):
    """Factory to create test clients with optional preset overrides."""

    @contextlib.contextmanager
    def _create_client(presets_data: dict | None = None):
        patch_ctx = (
            patch('app.prompting.PromptBuilder._load_presets', return_value=presets_data)
            if presets_data is not None else
            contextlib.nullcontext()
        )
        with patch_ctx:
            with patch('app.main.get_settings', new=lambda: mock_settings):
                with patch('app.main.SupabaseClient', return_value=None):
                    app = create_app(mock_settings)
                    client = TestClient(app)
                    try:
                        yield client
                    finally:
                        client.close()

    return _create_client


@pytest.fixture
def sample_presets_data():
    """Sample presets data matching story_presets.json structure."""
    return {
        "themes": [
            {
                "title": "Study Grove",
                "emoji": "🌿",
                "description": "Tranquil forest with gentle streams, rustling leaves, and distant bird songs.",
                "mood": "Focused and clear",
                "routine": "Deep breathing and intention setting",
                "category": "focus"
            },
            {
                "title": "Focus Falls",
                "emoji": "💧",
                "description": "Cascading waterfall with rhythmic sounds in a secluded, peaceful setting.",
                "mood": "Centered and attentive",
                "routine": "Mindful listening and concentration",
                "category": "focus"
            },
            {
                "title": "Family Hearth",
                "emoji": "🔥",
                "description": "Warm living room with crackling fireplace, cozy blankets, and shared stories.",
                "mood": "Warm and connected",
                "routine": "Gathering together for storytime",
                "category": "family"
            },
            {
                "title": "Oceanic Serenity",
                "emoji": "🌊",
                "description": "Peaceful beach at night with gentle waves and distant seagull calls.",
                "mood": "Peaceful and relaxed",
                "routine": "Listening to the rhythm of the ocean",
                "category": "unwind"
            },
        ],
        "featured": [
            "Study Grove",
            "Family Hearth",
            "Oceanic Serenity"
        ]
    }


class TestStoryPresetsEndpoint:
    """Tests for GET /api/v1/presets endpoint."""

    def test_get_presets_success(self, client_factory, sample_presets_data):
        """Test successful retrieval of story presets from config file."""
        with client_factory(sample_presets_data) as client:
            response = client.get("/api/v1/presets")
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify response structure
        assert "themes" in data
        assert "featured" in data
        
        # Verify all themes are returned
        assert len(data["themes"]) == len(sample_presets_data["themes"])
        assert data["themes"][0]["title"] == "Study Grove"
        assert data["themes"][0]["emoji"] == "🌿"
        assert data["themes"][0]["description"] == "Tranquil forest with gentle streams, rustling leaves, and distant bird songs."
        assert data["themes"][0]["mood"] == "Focused and clear"
        assert data["themes"][0]["routine"] == "Deep breathing and intention setting"
        assert data["themes"][0]["category"] == "focus"
        
        # Verify featured worlds
        assert len(data["featured"]) == 3
        featured_titles = [theme["title"] for theme in data["featured"]]
        assert "Study Grove" in featured_titles
        assert "Family Hearth" in featured_titles
        assert "Oceanic Serenity" in featured_titles

    def test_get_presets_featured_in_order(self, client_factory, sample_presets_data):
        """Test that featured worlds are returned in the order specified in config."""
        with client_factory(sample_presets_data) as client:
            response = client.get("/api/v1/presets")
        
        assert response.status_code == 200
        data = response.json()
        
        # Featured should be in the order specified in config
        assert data["featured"][0]["title"] == "Study Grove"
        assert data["featured"][1]["title"] == "Family Hearth"
        assert data["featured"][2]["title"] == "Oceanic Serenity"

    def test_get_presets_missing_config_file(self, client_factory):
        """Test handling when config file doesn't exist."""
        with client_factory({"themes": [], "featured": []}) as client:
            response = client.get("/api/v1/presets")
        
        assert response.status_code == 200
        data = response.json()
        
        # Should return empty structure
        assert "themes" in data
        assert "featured" in data
        assert len(data["themes"]) == 0
        assert len(data["featured"]) == 0

    def test_get_presets_invalid_json(self, client_factory):
        """Test handling when config file contains invalid JSON."""
        with client_factory({"themes": [], "featured": []}) as client:
            response = client.get("/api/v1/presets")
        
        assert response.status_code == 200
        data = response.json()
        
        # Should return empty structure on parse error
        assert "themes" in data
        assert "featured" in data

    def test_get_presets_all_theme_fields(self, client_factory, sample_presets_data):
        """Test that all required theme fields are present."""
        with client_factory(sample_presets_data) as client:
            response = client.get("/api/v1/presets")
        
        assert response.status_code == 200
        data = response.json()
        
        # Check all themes have required fields
        for theme in data["themes"]:
            assert "title" in theme
            assert "emoji" in theme
            assert "description" in theme
            assert "mood" in theme
            assert "routine" in theme
            assert "category" in theme

    def test_get_presets_featured_not_in_themes(self, client_factory):
        """Test handling when featured list references non-existent themes."""
        presets_data = {
            "themes": [
                {
                    "title": "Study Grove",
                    "emoji": "🌿",
                    "description": "Test",
                    "mood": "Test",
                    "routine": "Test",
                    "category": "focus"
                }
            ],
            "featured": [
                "Study Grove",
                "Non-existent Theme"  # This should be filtered out
            ]
        }
        
        with client_factory(presets_data) as client:
            response = client.get("/api/v1/presets")
        
        assert response.status_code == 200
        data = response.json()
        
        # Only existing themes should be in featured
        assert len(data["featured"]) == 1
        assert data["featured"][0]["title"] == "Study Grove"


class TestPromptBuilderConfigLoading:
    """Tests for PromptBuilder's config file loading functionality."""

    def test_load_presets_from_file(self, sample_presets_data):
        """Test that PromptBuilder loads presets from config file."""
        with patch('builtins.open', mock_open(read_data=json.dumps(sample_presets_data))):
            with patch('pathlib.Path.exists', return_value=True):
                builder = PromptBuilder()
                
                themes = builder.get_all_themes()
                featured = builder.get_featured_worlds()
        
        assert len(themes) == 4
        assert len(featured) == 3
        assert themes[0]["title"] == "Study Grove"
        assert featured[0]["title"] == "Study Grove"

    def test_load_presets_file_not_found(self):
        """Test PromptBuilder handles missing config file gracefully."""
        with patch('pathlib.Path.exists', return_value=False):
            builder = PromptBuilder()
            
            themes = builder.get_all_themes()
            featured = builder.get_featured_worlds()
        
        assert themes == []
        assert featured == []

    def test_load_presets_invalid_json(self):
        """Test PromptBuilder handles invalid JSON gracefully."""
        invalid_json = "{ invalid json }"
        
        with patch('builtins.open', mock_open(read_data=invalid_json)):
            with patch('pathlib.Path.exists', return_value=True):
                # Should catch JSONDecodeError and return empty structure
                builder = PromptBuilder()
                
                themes = builder.get_all_themes()
                featured = builder.get_featured_worlds()
        
        assert themes == []
        assert featured == []

    def test_get_featured_worlds_lookup(self, sample_presets_data):
        """Test that featured worlds are correctly looked up by title."""
        with patch('builtins.open', mock_open(read_data=json.dumps(sample_presets_data))):
            with patch('pathlib.Path.exists', return_value=True):
                builder = PromptBuilder()
                
                featured = builder.get_featured_worlds()
        
        # Verify all featured themes are correctly retrieved
        assert len(featured) == 3
        featured_titles = [theme["title"] for theme in featured]
        assert "Study Grove" in featured_titles
        assert "Family Hearth" in featured_titles
        assert "Oceanic Serenity" in featured_titles
        
        # Verify featured themes have all properties
        for theme in featured:
            assert "title" in theme
            assert "emoji" in theme
            assert "description" in theme
            assert "mood" in theme
            assert "routine" in theme
            assert "category" in theme

