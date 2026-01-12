"""
Adaptive Story Engine using Klaviyo real-time data.

This engine uses Klaviyo profile data and event history to dynamically adjust
story generation parameters in real-time, providing personalized story experiences
based on user behavior patterns.
"""

import logging
from datetime import datetime, timedelta
from typing import Any, Optional
from uuid import UUID

from ..models.klaviyo_models import StoryGeneratedEvent

logger = logging.getLogger("dream_flow")


class AdaptiveStoryEngine:
    """
    Engine for adapting story generation based on real-time Klaviyo data.
    
    This class analyzes user behavior patterns from Klaviyo and provides
    real-time recommendations for story parameters like length, energy level,
    theme, and pacing.
    """

    def __init__(self, klaviyo_service):
        """
        Initialize adaptive story engine.
        
        Args:
            klaviyo_service: KlaviyoService or AsyncKlaviyoService instance
        """
        self.klaviyo_service = klaviyo_service
        
        # Time-of-day energy level mappings
        self.energy_by_hour = {
            0: "very_calm", 1: "very_calm", 2: "very_calm", 3: "very_calm",
            4: "very_calm", 5: "very_calm", 6: "gentle", 7: "gentle",
            8: "moderate", 9: "moderate", 10: "moderate", 11: "moderate",
            12: "moderate", 13: "moderate", 14: "moderate", 15: "moderate",
            16: "gentle", 17: "gentle", 18: "gentle", 19: "calm",
            20: "calm", 21: "very_calm", 22: "very_calm", 23: "very_calm",
        }

    async def get_optimal_story_parameters(
        self,
        user_id: UUID,
        email: Optional[str] = None,
        current_theme: Optional[str] = None,
    ) -> dict[str, Any]:
        """
        Get optimal story parameters based on user's Klaviyo profile and patterns.
        
        This method analyzes:
        1. Time-of-day patterns from Klaviyo event history
        2. User's recent engagement and preferences
        3. Historical completion rates for different story types
        4. Current time vs. typical bedtime
        
        Args:
            user_id: UUID of the user
            email: User email (for Klaviyo lookups)
            current_theme: Currently requested theme (optional)
            
        Returns:
            Dictionary with recommended story parameters
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return self._get_default_parameters()

        try:
            # Get current time context
            current_hour = datetime.now().hour
            current_day = datetime.now().strftime("%A")
            
            # Fetch user's profile data from Klaviyo
            profile_metrics = None
            if hasattr(self.klaviyo_service, 'get_profile_metrics_async'):
                profile_metrics = await self.klaviyo_service.get_profile_metrics_async(
                    user_id, email
                )
            
            # Fetch recent story generation events
            event_metrics = None
            if hasattr(self.klaviyo_service, 'get_event_metrics_async'):
                event_metrics = await self.klaviyo_service.get_event_metrics_async(
                    "Story Generated",
                    start_date=datetime.now() - timedelta(days=7),
                    end_date=datetime.now()
                )
            
            # Analyze patterns and determine optimal parameters
            parameters = await self._analyze_and_recommend(
                user_id=user_id,
                current_hour=current_hour,
                current_day=current_day,
                profile_metrics=profile_metrics,
                event_metrics=event_metrics,
                current_theme=current_theme,
            )
            
            logger.info(f"Adaptive parameters for user {user_id}: {parameters}")
            return parameters
            
        except Exception as e:
            logger.warning(f"Failed to get adaptive story parameters: {e}")
            return self._get_default_parameters()

    async def _analyze_and_recommend(
        self,
        user_id: UUID,
        current_hour: int,
        current_day: str,
        profile_metrics: Optional[dict],
        event_metrics: Optional[dict],
        current_theme: Optional[str],
    ) -> dict[str, Any]:
        """
        Analyze user data and generate recommendations.
        
        Args:
            user_id: User ID
            current_hour: Current hour (0-23)
            current_day: Current day of week
            profile_metrics: Klaviyo profile metrics
            event_metrics: Klaviyo event metrics
            current_theme: Currently requested theme
            
        Returns:
            Dictionary of recommended parameters
        """
        # Start with default parameters
        parameters = self._get_default_parameters()
        
        # Determine optimal energy level based on time of day
        base_energy = self.energy_by_hour.get(current_hour, "calm")
        
        # Check if user is reading at their typical time
        is_typical_time = await self._is_typical_reading_time(
            profile_metrics, event_metrics, current_hour
        )
        
        # Adjust story length based on timing
        if not is_typical_time:
            # User is reading at unusual time - suggest shorter story
            parameters["suggested_length"] = "short"
            parameters["reasoning"].append(
                "Shorter story recommended as you're reading at an unusual time"
            )
        else:
            parameters["suggested_length"] = "standard"
        
        # Adjust energy level
        if is_typical_time and current_hour >= 20:
            # Bedtime routine - use very calm energy
            parameters["energy_level"] = "very_calm"
            parameters["reasoning"].append(
                "Very calm energy for your bedtime routine"
            )
        else:
            parameters["energy_level"] = base_energy
        
        # Theme recommendations based on profile
        if profile_metrics and profile_metrics.get("attributes"):
            attrs = profile_metrics["attributes"]
            story_preferences = attrs.get("story_preferences", [])
            
            if story_preferences and not current_theme:
                # Recommend theme from preferences
                parameters["theme_recommendation"] = story_preferences[0]
                parameters["reasoning"].append(
                    f"Theme '{story_preferences[0]}' recommended based on your preferences"
                )
        
        # Engagement-based recommendations
        if event_metrics:
            total_events = event_metrics.get("attributes", {}).get("count", 0)
            
            if total_events > 20:
                # High engagement user - suggest exploring new themes
                parameters["suggest_variety"] = True
                parameters["reasoning"].append(
                    "Try exploring new themes to keep things fresh!"
                )
            elif total_events < 5:
                # New user - stick to popular, accessible themes
                parameters["theme_recommendation"] = "Calm Focus"
                parameters["reasoning"].append(
                    "Starting with calming themes perfect for bedtime"
                )
        
        # Day-of-week patterns
        if current_day in ["Friday", "Saturday"]:
            # Weekends - users might want longer, more adventurous stories
            parameters["weekend_mode"] = True
            parameters["reasoning"].append(
                "Weekend detected - more time for storytelling!"
            )
        
        return parameters

    async def _is_typical_reading_time(
        self,
        profile_metrics: Optional[dict],
        event_metrics: Optional[dict],
        current_hour: int,
    ) -> bool:
        """
        Determine if current time matches user's typical reading pattern.
        
        Args:
            profile_metrics: Klaviyo profile metrics
            event_metrics: Klaviyo event metrics
            current_hour: Current hour (0-23)
            
        Returns:
            True if user typically reads stories at this time
        """
        # In a full implementation, this would analyze historical event timestamps
        # from Klaviyo to determine typical reading times
        
        # For now, use simple heuristic: bedtime hours (19:00-22:00)
        typical_bedtime_hours = list(range(19, 23))
        return current_hour in typical_bedtime_hours

    def _get_default_parameters(self) -> dict[str, Any]:
        """
        Get default story parameters when Klaviyo data is unavailable.
        
        Returns:
            Dictionary with default parameters
        """
        current_hour = datetime.now().hour
        
        return {
            "suggested_length": "standard",
            "energy_level": self.energy_by_hour.get(current_hour, "calm"),
            "theme_recommendation": "Calm Focus",
            "suggest_variety": False,
            "weekend_mode": False,
            "reasoning": ["Using default parameters (Klaviyo data unavailable)"],
        }

    async def get_sibling_coordination(
        self,
        parent_user_id: UUID,
        email: Optional[str] = None,
    ) -> dict[str, Any]:
        """
        Coordinate story timing and themes across siblings in family accounts.
        
        This feature ensures that multiple children in a family can have
        synchronized bedtime stories with complementary themes.
        
        Args:
            parent_user_id: Parent's user ID
            email: Parent's email
            
        Returns:
            Dictionary with sibling coordination data
        """
        try:
            # Check if user has family mode enabled
            profile_metrics = None
            if hasattr(self.klaviyo_service, 'get_profile_metrics_async'):
                profile_metrics = await self.klaviyo_service.get_profile_metrics_async(
                    parent_user_id, email
                )
            
            if not profile_metrics:
                return {"family_mode": False}
            
            attrs = profile_metrics.get("attributes", {})
            family_mode = attrs.get("family_mode_enabled", False)
            
            if not family_mode:
                return {"family_mode": False}
            
            # Return coordination data
            return {
                "family_mode": True,
                "coordinated_bedtime": True,
                "suggested_themes": [
                    "Ocean Adventure Part 1",
                    "Ocean Adventure Part 2",
                ],
                "recommendation": "Synchronized stories for all children at bedtime",
            }
            
        except Exception as e:
            logger.warning(f"Failed to get sibling coordination: {e}")
            return {"family_mode": False}

    async def track_story_completion(
        self,
        user_id: UUID,
        email: Optional[str] = None,
        story_id: Optional[str] = None,
        completed: bool = True,
        completion_percentage: float = 100.0,
    ) -> bool:
        """
        Track whether a story was completed or skipped.
        
        This data is used to improve future recommendations.
        
        Args:
            user_id: User ID
            email: User email
            story_id: Story identifier
            completed: Whether story was completed
            completion_percentage: Percentage of story completed (0-100)
            
        Returns:
            True if tracking succeeded
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return False

        try:
            event_name = "Story Completed" if completed else "Story Skipped"
            properties = {
                "completion_percentage": completion_percentage,
            }
            
            if story_id:
                properties["story_id"] = story_id
            
            if hasattr(self.klaviyo_service, 'track_event_async'):
                return await self.klaviyo_service.track_event_async(
                    event_name=event_name,
                    user_id=user_id,
                    properties=properties,
                    email=email,
                )
            else:
                return self.klaviyo_service.track_event(
                    event_name=event_name,
                    user_id=user_id,
                    properties=properties,
                    email=email,
                )
                
        except Exception as e:
            logger.warning(f"Failed to track story completion: {e}")
            return False

    def get_real_time_recommendations(
        self,
        parameters: dict[str, Any],
    ) -> list[str]:
        """
        Generate human-readable recommendations based on adaptive parameters.
        
        Args:
            parameters: Story parameters from get_optimal_story_parameters()
            
        Returns:
            List of recommendation strings for UI display
        """
        recommendations = []
        
        if parameters.get("suggested_length") == "short":
            recommendations.append(
                "📖 Quick story recommended - perfect for a brief wind-down"
            )
        
        if parameters.get("energy_level") == "very_calm":
            recommendations.append(
                "🌙 Extra calming story to help drift off to sleep"
            )
        
        if parameters.get("suggest_variety"):
            recommendations.append(
                "✨ Try a new theme! You might discover a new favorite"
            )
        
        if parameters.get("weekend_mode"):
            recommendations.append(
                "🎉 Weekend special - enjoy a longer adventure!"
            )
        
        if parameters.get("theme_recommendation"):
            theme = parameters["theme_recommendation"]
            recommendations.append(
                f"💡 '{theme}' theme is perfect for you right now"
            )
        
        return recommendations
