"""
Analytics service for querying user and system analytics.
Uses database views created in migration 20240101000006_create_analytics_views.sql
"""

import logging
from datetime import datetime, timedelta
from typing import Optional
from uuid import UUID

from supabase import Client

logger = logging.getLogger("dream_flow")


class AnalyticsService:
    """Service for querying analytics data."""

    def __init__(self, supabase_client: Client):
        """
        Initialize analytics service.

        Args:
            supabase_client: Supabase client instance with service-role authentication
        """
        self.client = supabase_client

    def get_user_analytics(
        self,
        user_id: UUID,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> dict:
        """
        Get analytics for a specific user.

        Args:
            user_id: UUID of the user
            start_date: Start date for analytics (defaults to 30 days ago)
            end_date: End date for analytics (defaults to now)

        Returns:
            Dictionary with user analytics
        """
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=30)
        if not end_date:
            end_date = datetime.utcnow()

        try:
            # Get story count
            stories_response = (
                self.client.table("sessions")
                .select("id", count="exact")
                .eq("user_id", str(user_id))
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            story_count = stories_response.count if stories_response.count else 0

            # Get themes used
            themes_response = (
                self.client.table("sessions")
                .select("theme")
                .eq("user_id", str(user_id))
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            themes = {}
            if themes_response.data:
                for session in themes_response.data:
                    theme = session.get("theme", "unknown")
                    themes[theme] = themes.get(theme, 0) + 1

            # Get average story length
            sessions_response = (
                self.client.table("sessions")
                .select("story_text")
                .eq("user_id", str(user_id))
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            total_length = 0
            story_count_with_text = 0
            if sessions_response.data:
                for session in sessions_response.data:
                    story_text = session.get("story_text", "")
                    if story_text:
                        total_length += len(story_text)
                        story_count_with_text += 1

            avg_length = (
                total_length / story_count_with_text if story_count_with_text > 0 else 0
            )

            return {
                "user_id": str(user_id),
                "period": {
                    "start": start_date.isoformat(),
                    "end": end_date.isoformat(),
                },
                "story_count": story_count,
                "themes_used": themes,
                "average_story_length": round(avg_length, 0),
                "most_used_theme": max(themes.items(), key=lambda x: x[1])[0] if themes else None,
            }
        except Exception as e:
            logger.error(f"Failed to get user analytics: {e}", exc_info=True)
            raise

    def get_system_analytics(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> dict:
        """
        Get system-wide analytics.

        Args:
            start_date: Start date for analytics (defaults to 30 days ago)
            end_date: End date for analytics (defaults to now)

        Returns:
            Dictionary with system analytics
        """
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=30)
        if not end_date:
            end_date = datetime.utcnow()

        try:
            # Get total stories
            stories_response = (
                self.client.table("sessions")
                .select("id", count="exact")
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            total_stories = stories_response.count if stories_response.count else 0

            # Get unique users
            users_response = (
                self.client.table("sessions")
                .select("user_id")
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            unique_users = set()
            if users_response.data:
                for session in users_response.data:
                    unique_users.add(session.get("user_id"))

            # Get popular themes
            themes_response = (
                self.client.table("sessions")
                .select("theme")
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            themes = {}
            if themes_response.data:
                for session in themes_response.data:
                    theme = session.get("theme", "unknown")
                    themes[theme] = themes.get(theme, 0) + 1

            popular_themes = sorted(
                themes.items(), key=lambda x: x[1], reverse=True
            )[:10]

            return {
                "period": {
                    "start": start_date.isoformat(),
                    "end": end_date.isoformat(),
                },
                "total_stories": total_stories,
                "unique_users": len(unique_users),
                "popular_themes": [{"theme": theme, "count": count} for theme, count in popular_themes],
            }
        except Exception as e:
            logger.error(f"Failed to get system analytics: {e}", exc_info=True)
            raise

    def get_usage_trends(
        self,
        user_id: Optional[UUID] = None,
        days: int = 30,
    ) -> dict:
        """
        Get usage trends over time.

        Args:
            user_id: Optional user ID to filter by (None for system-wide)
            days: Number of days to analyze

        Returns:
            Dictionary with daily usage trends
        """
        end_date = datetime.utcnow()
        start_date = end_date - timedelta(days=days)

        try:
            query = (
                self.client.table("sessions")
                .select("created_at")
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
            )

            if user_id:
                query = query.eq("user_id", str(user_id))

            response = query.execute()

            # Group by date
            daily_counts = {}
            if response.data:
                for session in response.data:
                    created_at = datetime.fromisoformat(
                        session["created_at"].replace("Z", "+00:00")
                    )
                    date_key = created_at.date().isoformat()
                    daily_counts[date_key] = daily_counts.get(date_key, 0) + 1

            # Fill in missing dates with 0
            trends = []
            current_date = start_date.date()
            while current_date <= end_date.date():
                date_key = current_date.isoformat()
                trends.append({
                    "date": date_key,
                    "count": daily_counts.get(date_key, 0),
                })
                current_date += timedelta(days=1)

            return {
                "trends": trends,
                "total": sum(daily_counts.values()),
            }
        except Exception as e:
            logger.error(f"Failed to get usage trends: {e}", exc_info=True)
            raise

