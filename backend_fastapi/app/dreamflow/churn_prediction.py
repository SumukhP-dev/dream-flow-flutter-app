"""
Predictive churn prevention system using Klaviyo event patterns.

This module analyzes user behavior patterns from Klaviyo events to predict
churn risk and automatically trigger re-engagement flows.
"""

import logging
from datetime import datetime, timedelta
from typing import Optional, Any
from uuid import UUID

from .klaviyo_service import KlaviyoService

logger = logging.getLogger("dream_flow")


class ChurnPrediction:
    """System for predicting user churn and triggering re-engagement."""

    def __init__(self, klaviyo_service: KlaviyoService):
        """
        Initialize churn prediction system.

        Args:
            klaviyo_service: KlaviyoService instance for accessing event data
        """
        self.klaviyo_service = klaviyo_service
        self.churn_risk_threshold = 0.7  # 70% risk threshold
        self.inactivity_days_threshold = 14  # 14 days of inactivity

    def calculate_churn_risk(
        self,
        user_id: UUID,
    ) -> float:
        """
        Calculate churn risk score for a user (0.0 to 1.0).

        Args:
            user_id: UUID of the user

        Returns:
            Churn risk score (0.0 = low risk, 1.0 = high risk)
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return 0.0

        try:
            risk_score = 0.0

            # Get recent event metrics
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(days=30)

            story_metrics = self.klaviyo_service.get_event_metrics(
                "Story Generated",
                start_date=start_date,
                end_date=end_date,
            )

            if not story_metrics:
                # No recent activity - high churn risk
                risk_score = 0.9
                logger.info(f"User {user_id} has no recent activity - high churn risk")
                return risk_score

            # Calculate days since last story
            # This is simplified - in production, you'd query actual event timestamps
            count = story_metrics.get("count", 0)
            
            if count == 0:
                # No stories in last 30 days - very high risk
                risk_score = 0.95
            elif count < 3:
                # Very low engagement - high risk
                risk_score = 0.7
            elif count < 7:
                # Low engagement - medium risk
                risk_score = 0.4
            else:
                # Good engagement - low risk
                risk_score = 0.1

            logger.debug(f"Churn risk score for user {user_id}: {risk_score}")
            return risk_score

        except Exception as e:
            logger.warning(f"Failed to calculate churn risk: {e}")
            return 0.5  # Default to medium risk on error

    def is_at_risk(
        self,
        user_id: UUID,
    ) -> bool:
        """
        Check if user is at risk of churning.

        Args:
            user_id: UUID of the user

        Returns:
            True if user is at risk, False otherwise
        """
        risk_score = self.calculate_churn_risk(user_id)
        return risk_score >= self.churn_risk_threshold

    def trigger_re_engagement(
        self,
        user_id: UUID,
        email: Optional[str] = None,
    ) -> bool:
        """
        Trigger re-engagement flow for at-risk user.

        Args:
            user_id: UUID of the user
            email: Optional user email

        Returns:
            True if re-engagement was triggered successfully
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return False

        try:
            # Check if user is at risk
            if not self.is_at_risk(user_id):
                logger.debug(f"User {user_id} is not at risk, skipping re-engagement")
                return False

            # Track re-engagement event
            self.klaviyo_service.track_event(
                event_name="Re-engagement Triggered",
                user_id=user_id,
                email=email,
                properties={
                    "churn_risk_score": self.calculate_churn_risk(user_id),
                    "triggered_at": datetime.utcnow().isoformat(),
                },
            )

            # Trigger re-engagement flow (if flow ID is configured)
            # In production, you'd have a specific flow ID for re-engagement
            flow_id = "re-engagement-flow"  # This would be configured
            self.klaviyo_service.trigger_flow(flow_id, user_id, email)

            logger.info(f"Triggered re-engagement for at-risk user {user_id}")
            return True

        except Exception as e:
            logger.error(f"Failed to trigger re-engagement: {e}")
            return False

    def get_recommendations_for_at_risk_user(
        self,
        user_id: UUID,
    ) -> list[str]:
        """
        Get personalized recommendations for at-risk users.

        Args:
            user_id: UUID of the user

        Returns:
            List of recommendation messages
        """
        recommendations = []

        try:
            risk_score = self.calculate_churn_risk(user_id)

            if risk_score >= 0.8:
                recommendations.append("We miss you! Try a new story theme today")
                recommendations.append("Explore our premium features for enhanced stories")
            elif risk_score >= 0.5:
                recommendations.append("Discover new calming stories for better sleep")
                recommendations.append("Set up bedtime reminders to build a routine")
            else:
                recommendations.append("Keep up the great work with your story routine!")

            return recommendations

        except Exception as e:
            logger.warning(f"Failed to get recommendations: {e}")
            return ["Try exploring new story themes!"]

    def batch_check_at_risk_users(
        self,
        user_ids: list[UUID],
    ) -> dict[UUID, float]:
        """
        Batch check churn risk for multiple users.

        Args:
            user_ids: List of user UUIDs to check

        Returns:
            Dictionary mapping user_id to churn risk score
        """
        risk_scores = {}

        for user_id in user_ids:
            try:
                risk_score = self.calculate_churn_risk(user_id)
                risk_scores[user_id] = risk_score
            except Exception as e:
                logger.warning(f"Failed to calculate risk for user {user_id}: {e}")
                risk_scores[user_id] = 0.5  # Default to medium risk

        return risk_scores

