"""
Unit tests for RecommendationEngine.

Tests ensure:
- Theme recommendations work based on feedback
- Similar stories are found correctly
- Popular themes are used as fallback
"""

import pytest
from unittest.mock import MagicMock
from uuid import uuid4, UUID

from app.recommendation_engine import RecommendationEngine


class TestRecommendationEngine:
    """Tests for RecommendationEngine class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mock_client = MagicMock()
        self.mock_table = MagicMock()
        self.mock_client.table.return_value = self.mock_table
        self.engine = RecommendationEngine(self.mock_client)

    def test_get_recommended_themes_from_feedback(self):
        """Test getting recommended themes based on feedback."""
        user_id = uuid4()
        
        # Mock feedback with high ratings
        feedback_data = [
            {
                "rating": 5,
                "mood_delta": 3,
                "sessions": {"theme": "ocean", "rating": 5},
            },
            {
                "rating": 4,
                "mood_delta": 2,
                "sessions": {"theme": "forest", "rating": 4},
            },
        ]
        
        feedback_response = MagicMock()
        feedback_response.data = feedback_data
        chain = self.mock_table.select.return_value
        chain.select.return_value = chain
        chain.eq.return_value = chain
        chain.order.return_value = chain
        chain.limit.return_value = chain
        chain.execute.return_value = feedback_response
        
        recommendations = self.engine.get_recommended_themes(user_id, limit=5)
        
        assert len(recommendations) > 0
        assert all("theme" in r for r in recommendations)
        assert all("score" in r for r in recommendations)

    def test_get_recommended_themes_no_feedback(self):
        """Test getting recommendations when user has no feedback."""
        user_id = uuid4()
        
        # No feedback
        feedback_response = MagicMock()
        feedback_response.data = []
        chain = self.mock_table.select.return_value
        chain.select.return_value = chain
        chain.eq.return_value = chain
        chain.order.return_value = chain
        chain.limit.return_value = chain
        chain.execute.return_value = feedback_response
        
        # Mock popular themes
        popular_response = MagicMock()
        popular_response.data = [
            {"theme": "ocean"},
            {"theme": "forest"},
        ]
        popular_chain = self.mock_table.select.return_value
        popular_chain.select.return_value = popular_chain
        popular_chain.limit.return_value = popular_chain
        popular_chain.execute.return_value = popular_response
        
        recommendations = self.engine.get_recommended_themes(user_id, limit=5)
        
        # Should fall back to popular themes
        assert len(recommendations) > 0

    def test_get_similar_stories(self):
        """Test getting similar stories."""
        user_id = uuid4()
        favorite_session_id = uuid4()
        
        # Mock favorite session - maybe_single returns data directly, not in a list
        favorite_data = {
            "id": str(favorite_session_id),
            "theme": "ocean",
        }
        favorite_response = MagicMock()
        favorite_response.data = favorite_data
        favorite_chain = self.mock_table.select.return_value
        favorite_chain.select.return_value = favorite_chain
        favorite_chain.eq.return_value = favorite_chain
        favorite_chain.eq.return_value = favorite_chain
        favorite_chain.maybe_single.return_value = favorite_chain
        favorite_chain.execute.return_value = favorite_response
        
        # Mock similar sessions
        similar_data = [
            {"id": str(uuid4()), "theme": "ocean"},
            {"id": str(uuid4()), "theme": "ocean"},
        ]
        similar_response = MagicMock()
        similar_response.data = similar_data
        # Need separate chain for similar query
        similar_chain = MagicMock()
        similar_chain.select.return_value = similar_chain
        similar_chain.eq.return_value = similar_chain
        similar_chain.neq.return_value = similar_chain
        similar_chain.order.return_value = similar_chain
        similar_chain.limit.return_value = similar_chain
        similar_chain.execute.return_value = similar_response
        
        # Make table() return different chains for different calls
        call_count = [0]
        def table_side_effect(table_name):
            call_count[0] += 1
            if call_count[0] == 1:
                # First call for favorite session
                return favorite_chain
            else:
                # Second call for similar sessions
                return similar_chain
        
        self.mock_client.table.side_effect = table_side_effect
        
        result = self.engine.get_similar_stories(user_id, favorite_session_id, limit=5)
        
        assert len(result) == 2
        assert all(s["theme"] == "ocean" for s in result)

    def test_get_similar_stories_no_favorite(self):
        """Test getting similar stories when favorite doesn't exist."""
        user_id = uuid4()
        favorite_session_id = uuid4()
        
        # No favorite session
        favorite_response = MagicMock()
        favorite_response.data = None
        favorite_chain = self.mock_table.select.return_value
        favorite_chain.select.return_value = favorite_chain
        favorite_chain.eq.return_value = favorite_chain
        favorite_chain.eq.return_value = favorite_chain
        favorite_chain.maybe_single.return_value = favorite_chain
        favorite_chain.execute.return_value = favorite_response
        
        result = self.engine.get_similar_stories(user_id, favorite_session_id, limit=5)
        
        assert result == []

