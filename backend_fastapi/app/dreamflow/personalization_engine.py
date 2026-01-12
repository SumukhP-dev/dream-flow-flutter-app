"""
AI-powered personalization engine using Klaviyo profile data.

This module uses Klaviyo profile attributes and event history to personalize
story generation, making recommendations based on user behavior patterns.
"""

import logging
from typing import Optional, Any
from uuid import UUID

from .klaviyo_service import KlaviyoService

logger = logging.getLogger("dream_flow")


class PersonalizationEngine:
    """Engine for personalizing story generation based on Klaviyo data."""

    def __init__(self, klaviyo_service: KlaviyoService):
        """
        Initialize personalization engine.

        Args:
            klaviyo_service: KlaviyoService instance for accessing profile data
        """
        self.klaviyo_service = klaviyo_service

    def get_personalized_theme(
        self,
        user_id: UUID,
        default_theme: Optional[str] = None,
    ) -> Optional[str]:
        """
        Get personalized story theme based on user's Klaviyo profile data.

        Args:
            user_id: UUID of the user
            default_theme: Default theme to use if personalization fails

        Returns:
            Recommended theme or default theme
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return default_theme

        try:
            # Get user profile metrics from Klaviyo
            profile_metrics = self.klaviyo_service.get_profile_metrics(user_id)
            
            if not profile_metrics:
                logger.debug(f"No Klaviyo metrics found for user {user_id}, using default theme")
                return default_theme

            # Get event metrics to understand user preferences
            story_metrics = self.klaviyo_service.get_event_metrics("Story Generated")
            
            # Analyze user's story preferences from profile
            # This would typically come from profile attributes synced to Klaviyo
            # For now, we'll use a simple heuristic based on engagement
            
            # If user has high engagement, suggest more adventurous themes
            # If user has low engagement, suggest calming themes
            if story_metrics and story_metrics.get("count", 0) > 10:
                # High engagement user - suggest varied themes
                recommended_themes = ["Adventure", "Exploration", "Discovery"]
            else:
                # Lower engagement or new user - suggest calming themes
                recommended_themes = ["Calm Focus", "Peaceful Journey", "Tranquil Dreams"]

            logger.info(f"Recommended themes for user {user_id}: {recommended_themes}")
            return recommended_themes[0] if recommended_themes else default_theme

        except Exception as e:
            logger.warning(f"Failed to get personalized theme: {e}")
            return default_theme

    def get_personalized_story_preferences(
        self,
        user_id: UUID,
    ) -> dict[str, Any]:
        """
        Get personalized story preferences based on Klaviyo profile data.

        Args:
            user_id: UUID of the user

        Returns:
            Dictionary of personalized preferences
        """
        preferences = {
            "theme": None,
            "length": "medium",
            "tone": "calm",
            "characters": [],
            "settings": [],
        }

        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return preferences

        try:
            # Get profile metrics
            profile_metrics = self.klaviyo_service.get_profile_metrics(user_id)
            
            if profile_metrics:
                # Analyze engagement patterns
                # This is a simplified version - in production, you'd analyze
                # historical event data to understand preferences
                
                # Example: If user frequently generates stories at night,
                # prefer calming themes
                preferences["tone"] = "calm"
                preferences["theme"] = "Bedtime Stories"

            logger.debug(f"Personalized preferences for user {user_id}: {preferences}")
            return preferences

        except Exception as e:
            logger.warning(f"Failed to get personalized preferences: {e}")
            return preferences

    def analyze_user_engagement_pattern(
        self,
        user_id: UUID,
    ) -> dict[str, Any]:
        """
        Analyze user engagement patterns from Klaviyo event data.

        Args:
            user_id: UUID of the user

        Returns:
            Dictionary with engagement analysis
        """
        analysis = {
            "engagement_level": "low",
            "preferred_themes": [],
            "usage_frequency": "occasional",
            "recommendations": [],
        }

        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return analysis

        try:
            # Get event metrics for this user
            story_metrics = self.klaviyo_service.get_event_metrics("Story Generated")
            
            if story_metrics:
                count = story_metrics.get("count", 0)
                
                if count > 20:
                    analysis["engagement_level"] = "high"
                    analysis["usage_frequency"] = "frequent"
                elif count > 5:
                    analysis["engagement_level"] = "medium"
                    analysis["usage_frequency"] = "regular"
                else:
                    analysis["engagement_level"] = "low"
                    analysis["usage_frequency"] = "occasional"

                # Generate recommendations based on engagement
                if analysis["engagement_level"] == "high":
                    analysis["recommendations"].append("Try premium features for enhanced stories")
                elif analysis["engagement_level"] == "low":
                    analysis["recommendations"].append("Explore different story themes")
                    analysis["recommendations"].append("Set up bedtime reminders")

            logger.debug(f"Engagement analysis for user {user_id}: {analysis}")
            return analysis

        except Exception as e:
            logger.warning(f"Failed to analyze engagement pattern: {e}")
            return analysis

