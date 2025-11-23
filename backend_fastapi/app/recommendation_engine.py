"""
Personalization engine that learns from user feedback to improve story recommendations.

Analyzes user feedback (ratings, mood_delta) to learn preferences and recommend themes.
"""

import logging
from typing import Optional
from uuid import UUID

from supabase import Client

logger = logging.getLogger("dream_flow")


class RecommendationEngine:
    """Engine for personalized story recommendations based on user feedback."""

    def __init__(self, supabase_client: Client):
        """
        Initialize recommendation engine.

        Args:
            supabase_client: Supabase client instance with service-role authentication
        """
        self.client = supabase_client

    def get_recommended_themes(
        self,
        user_id: UUID,
        limit: int = 5,
        time_of_day: Optional[str] = None,
    ) -> list[dict]:
        """
        Get recommended themes for a user based on their feedback history.

        Args:
            user_id: UUID of the user
            limit: Maximum number of recommendations
            time_of_day: Optional time context ('morning', 'afternoon', 'evening', 'night')

        Returns:
            List of recommended theme dictionaries with scores
        """
        # Get user's feedback history
        feedback_query = (
            self.client.table("session_feedback")
            .select("*, sessions!inner(theme, rating)")
            .eq("user_id", str(user_id))
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )

        feedback_data = feedback_query.data if feedback_query.data else []

        # Analyze feedback to determine preferences
        theme_scores = {}
        for feedback in feedback_data:
            session = feedback.get("sessions", {})
            theme = session.get("theme")
            rating = feedback.get("rating", 3)  # Default to neutral
            mood_delta = feedback.get("mood_delta", 0)

            if theme:
                # Calculate score: rating (1-5) + mood_delta (-5 to 5) normalized
                score = rating + (mood_delta / 5.0)
                if theme not in theme_scores:
                    theme_scores[theme] = {"total_score": 0, "count": 0}
                theme_scores[theme]["total_score"] += score
                theme_scores[theme]["count"] += 1

        # Calculate average scores
        theme_averages = {}
        for theme, data in theme_scores.items():
            theme_averages[theme] = data["total_score"] / data["count"]

        # Sort by score and return top themes
        sorted_themes = sorted(
            theme_averages.items(),
            key=lambda x: x[1],
            reverse=True,
        )[:limit]

        recommendations = []
        for theme, score in sorted_themes:
            recommendations.append({"theme": theme, "score": score, "reason": "Based on your positive feedback"})

        # If not enough recommendations, add popular themes
        if len(recommendations) < limit:
            # Get popular themes from all users
            popular_query = (
                self.client.table("sessions")
                .select("theme")
                .limit(100)
                .execute()
            )

            popular_themes = {}
            for session in (popular_query.data or []):
                theme = session.get("theme")
                if theme:
                    popular_themes[theme] = popular_themes.get(theme, 0) + 1

            # Add popular themes not already in recommendations
            recommended_theme_names = {r["theme"] for r in recommendations}
            for theme, count in sorted(
                popular_themes.items(),
                key=lambda x: x[1],
                reverse=True,
            ):
                if theme not in recommended_theme_names and len(recommendations) < limit:
                    recommendations.append({
                        "theme": theme,
                        "score": count / 100.0,  # Normalize by sample size
                        "reason": "Popular with other users",
                    })

        return recommendations

    def get_similar_stories(
        self,
        user_id: UUID,
        favorite_session_id: UUID,
        limit: int = 5,
    ) -> list[dict]:
        """
        Get stories similar to a user's favorite.

        Args:
            user_id: UUID of the user
            favorite_session_id: UUID of the favorite session
            limit: Maximum number of recommendations

        Returns:
            List of similar session dictionaries
        """
        # Get the favorite session
        favorite_query = (
            self.client.table("sessions")
            .select("*")
            .eq("id", str(favorite_session_id))
            .eq("user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if not favorite_query.data:
            return []

        favorite_session = favorite_query.data
        favorite_theme = favorite_session.get("theme")

        # Find similar sessions (same theme, different users or same user)
        similar_query = (
            self.client.table("sessions")
            .select("*")
            .eq("theme", favorite_theme)
            .neq("id", str(favorite_session_id))
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )

        return similar_query.data if similar_query.data else []

