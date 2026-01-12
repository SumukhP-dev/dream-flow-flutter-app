"""
Tests for churn prediction system.
"""

import pytest
from unittest.mock import Mock, MagicMock, patch
from datetime import datetime, timedelta
from uuid import uuid4

from app.dreamflow.churn_prediction import ChurnPrediction
from app.dreamflow.klaviyo_service import KlaviyoService


@pytest.fixture
def mock_klaviyo_service():
    """Create a mock KlaviyoService."""
    service = MagicMock(spec=KlaviyoService)
    service.enabled = True
    return service


@pytest.fixture
def churn_prediction(mock_klaviyo_service):
    """Create a ChurnPrediction instance."""
    return ChurnPrediction(mock_klaviyo_service)


class TestChurnPrediction:
    """Test suite for ChurnPrediction."""

    def test_calculate_churn_risk_no_activity(self, churn_prediction, mock_klaviyo_service):
        """Test churn risk calculation with no activity."""
        user_id = uuid4()
        mock_klaviyo_service.get_event_metrics = MagicMock(return_value=None)

        risk_score = churn_prediction.calculate_churn_risk(user_id)

        assert risk_score >= 0.9  # High risk for no activity

    def test_calculate_churn_risk_low_engagement(self, churn_prediction, mock_klaviyo_service):
        """Test churn risk calculation with low engagement."""
        user_id = uuid4()
        mock_klaviyo_service.get_event_metrics = MagicMock(return_value={"count": 2})

        risk_score = churn_prediction.calculate_churn_risk(user_id)

        assert risk_score >= 0.7  # High risk for low engagement

    def test_calculate_churn_risk_high_engagement(self, churn_prediction, mock_klaviyo_service):
        """Test churn risk calculation with high engagement."""
        user_id = uuid4()
        mock_klaviyo_service.get_event_metrics = MagicMock(return_value={"count": 15})

        risk_score = churn_prediction.calculate_churn_risk(user_id)

        assert risk_score < 0.5  # Low risk for high engagement

    def test_is_at_risk_high_risk(self, churn_prediction, mock_klaviyo_service):
        """Test is_at_risk returns True for high risk users."""
        user_id = uuid4()
        churn_prediction.calculate_churn_risk = MagicMock(return_value=0.85)

        result = churn_prediction.is_at_risk(user_id)

        assert result is True

    def test_is_at_risk_low_risk(self, churn_prediction, mock_klaviyo_service):
        """Test is_at_risk returns False for low risk users."""
        user_id = uuid4()
        churn_prediction.calculate_churn_risk = MagicMock(return_value=0.3)

        result = churn_prediction.is_at_risk(user_id)

        assert result is False

    def test_trigger_re_engagement_at_risk(self, churn_prediction, mock_klaviyo_service):
        """Test triggering re-engagement for at-risk users."""
        user_id = uuid4()
        churn_prediction.is_at_risk = MagicMock(return_value=True)
        mock_klaviyo_service.track_event = MagicMock(return_value=True)
        mock_klaviyo_service.trigger_flow = MagicMock(return_value=True)

        with patch.object(churn_prediction, "calculate_churn_risk", return_value=0.85):
            result = churn_prediction.trigger_re_engagement(user_id)

        assert result is True
        mock_klaviyo_service.track_event.assert_called_once()

    def test_trigger_re_engagement_not_at_risk(self, churn_prediction, mock_klaviyo_service):
        """Test re-engagement is not triggered for low-risk users."""
        user_id = uuid4()
        churn_prediction.is_at_risk = MagicMock(return_value=False)

        result = churn_prediction.trigger_re_engagement(user_id)

        assert result is False

    def test_get_recommendations_for_at_risk_user(self, churn_prediction):
        """Test getting recommendations for at-risk users."""
        user_id = uuid4()
        churn_prediction.calculate_churn_risk = MagicMock(return_value=0.85)

        recommendations = churn_prediction.get_recommendations_for_at_risk_user(user_id)

        assert isinstance(recommendations, list)
        assert len(recommendations) > 0

    def test_batch_check_at_risk_users(self, churn_prediction):
        """Test batch checking churn risk for multiple users."""
        user_ids = [uuid4() for _ in range(3)]
        churn_prediction.calculate_churn_risk = MagicMock(side_effect=[0.9, 0.3, 0.7])

        risk_scores = churn_prediction.batch_check_at_risk_users(user_ids)

        assert len(risk_scores) == 3
        assert all(0.0 <= score <= 1.0 for score in risk_scores.values())

    def test_churn_prediction_with_disabled_klaviyo(self):
        """Test churn prediction works when Klaviyo is disabled."""
        mock_service = MagicMock(spec=KlaviyoService)
        mock_service.enabled = False
        prediction = ChurnPrediction(mock_service)

        risk_score = prediction.calculate_churn_risk(uuid4())

        assert risk_score == 0.0

