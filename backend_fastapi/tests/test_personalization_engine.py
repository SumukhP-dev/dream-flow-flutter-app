"""
Tests for personalization engine.
"""

import pytest
from unittest.mock import Mock, MagicMock, patch
from uuid import uuid4

from app.dreamflow.personalization_engine import PersonalizationEngine
from app.dreamflow.klaviyo_service import KlaviyoService


@pytest.fixture
def mock_klaviyo_service():
    """Create a mock KlaviyoService."""
    service = MagicMock(spec=KlaviyoService)
    service.enabled = True
    return service


@pytest.fixture
def personalization_engine(mock_klaviyo_service):
    """Create a PersonalizationEngine instance."""
    return PersonalizationEngine(mock_klaviyo_service)


class TestPersonalizationEngine:
    """Test suite for PersonalizationEngine."""

    def test_get_personalized_theme_with_metrics(self, personalization_engine, mock_klaviyo_service):
        """Test getting personalized theme with metrics."""
        user_id = uuid4()
        mock_klaviyo_service.get_profile_metrics = MagicMock(return_value={"profile_id": "123"})
        mock_klaviyo_service.get_event_metrics = MagicMock(return_value={"count": 15})

        result = personalization_engine.get_personalized_theme(user_id, default_theme="Default")

        assert result is not None
        assert result != "Default"  # Should return a recommended theme

    def test_get_personalized_theme_without_metrics(self, personalization_engine, mock_klaviyo_service):
        """Test getting personalized theme without metrics."""
        user_id = uuid4()
        mock_klaviyo_service.get_profile_metrics = MagicMock(return_value=None)

        result = personalization_engine.get_personalized_theme(user_id, default_theme="Default")

        assert result == "Default"

    def test_get_personalized_story_preferences(self, personalization_engine, mock_klaviyo_service):
        """Test getting personalized story preferences."""
        user_id = uuid4()
        mock_klaviyo_service.get_profile_metrics = MagicMock(return_value={"profile_id": "123"})

        result = personalization_engine.get_personalized_story_preferences(user_id)

        assert isinstance(result, dict)
        assert "theme" in result
        assert "length" in result
        assert "tone" in result

    def test_analyze_user_engagement_pattern(self, personalization_engine, mock_klaviyo_service):
        """Test analyzing user engagement pattern."""
        user_id = uuid4()
        mock_klaviyo_service.get_event_metrics = MagicMock(return_value={"count": 25})

        result = personalization_engine.analyze_user_engagement_pattern(user_id)

        assert isinstance(result, dict)
        assert "engagement_level" in result
        assert "usage_frequency" in result
        assert "recommendations" in result

    def test_engine_with_disabled_klaviyo(self):
        """Test engine works when Klaviyo is disabled."""
        mock_service = MagicMock(spec=KlaviyoService)
        mock_service.enabled = False
        engine = PersonalizationEngine(mock_service)

        result = engine.get_personalized_theme(uuid4(), default_theme="Default")

        assert result == "Default"

