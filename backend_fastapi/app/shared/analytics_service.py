"""
Analytics service for aggregating user and story statistics.

Uses existing analytics views from migration 20240101000006.
"""

from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
from uuid import UUID

from app.shared.supabase_client import SupabaseClient


class AnalyticsService:
    """Service for retrieving analytics data."""

    def __init__(self, supabase_client: SupabaseClient):
        self.client = supabase_client

    def get_user_analytics(
        self,
        user_id: UUID,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Get analytics for a specific user.

        Args:
            user_id: User ID
            start_date: Optional start date filter
            end_date: Optional end date filter

        Returns:
            Dictionary with user analytics
        """
        if start_date is None:
            start_date = datetime.now() - timedelta(days=30)
        if end_date is None:
            end_date = datetime.now()

        # Get user sessions
        sessions = self.client.get_user_sessions(user_id)

        # Filter by date range
        filtered_sessions = [
            s
            for s in sessions
            if start_date
            <= datetime.fromisoformat(s["created_at"].replace("Z", "+00:00"))
            <= end_date
        ]

        # Calculate statistics
        total_stories = len(filtered_sessions)
        this_week = len(
            [
                s
                for s in filtered_sessions
                if (
                    datetime.now()
                    - datetime.fromisoformat(s["created_at"].replace("Z", "+00:00"))
                ).days
                <= 7
            ]
        )
        this_month = len(
            [
                s
                for s in filtered_sessions
                if (
                    datetime.now()
                    - datetime.fromisoformat(s["created_at"].replace("Z", "+00:00"))
                ).days
                <= 30
            ]
        )

        # Get favorite themes
        theme_counts: Dict[str, int] = {}
        for session in filtered_sessions:
            theme = session.get("theme", "Unknown")
            theme_counts[theme] = theme_counts.get(theme, 0) + 1

        favorite_themes = dict(
            sorted(theme_counts.items(), key=lambda x: x[1], reverse=True)[:5]
        )

        # Calculate streak
        streak = self._calculate_streak(filtered_sessions)

        return {
            "total_stories": total_stories,
            "this_week": this_week,
            "this_month": this_month,
            "favorite_themes": favorite_themes,
            "streak": streak,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
        }

    def get_admin_analytics(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Get admin-level analytics across all users.

        Args:
            start_date: Optional start date filter
            end_date: Optional end date filter

        Returns:
            Dictionary with admin analytics
        """
        if start_date is None:
            start_date = datetime.now() - timedelta(days=30)
        if end_date is None:
            end_date = datetime.now()

        # Query analytics views (these should exist from migration 20240101000006)
        try:
            # Get total stories
            stories_response = (
                self.client.client.table("sessions")
                .select("id", count="exact")
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            total_stories = (
                stories_response.count if hasattr(stories_response, "count") else 0
            )

            # Get active users
            users_response = (
                self.client.client.table("sessions")
                .select("user_id", count="exact")
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )
            active_users = (
                len(set(s["user_id"] for s in users_response.data))
                if users_response.data
                else 0
            )

            # Get popular themes
            themes_response = (
                self.client.client.table("sessions")
                .select("theme")
                .gte("created_at", start_date.isoformat())
                .lte("created_at", end_date.isoformat())
                .execute()
            )

            theme_counts: Dict[str, int] = {}
            if themes_response.data:
                for session in themes_response.data:
                    theme = session.get("theme", "Unknown")
                    theme_counts[theme] = theme_counts.get(theme, 0) + 1

            popular_themes = dict(
                sorted(theme_counts.items(), key=lambda x: x[1], reverse=True)[:10]
            )

            return {
                "total_stories": total_stories,
                "active_users": active_users,
                "popular_themes": popular_themes,
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
            }
        except Exception as e:
            # Fallback if views don't exist
            return {
                "total_stories": 0,
                "active_users": 0,
                "popular_themes": {},
                "error": str(e),
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
            }

    def _calculate_streak(self, sessions: List[Dict[str, Any]]) -> int:
        """Calculate user streak from sessions."""
        if not sessions:
            return 0

        # Sort by date descending
        sorted_sessions = sorted(
            sessions,
            key=lambda s: datetime.fromisoformat(
                s["created_at"].replace("Z", "+00:00")
            ),
            reverse=True,
        )

        streak = 0
        last_date: Optional[datetime] = None

        for session in sorted_sessions:
            created = datetime.fromisoformat(
                session["created_at"].replace("Z", "+00:00")
            )
            story_date = datetime(created.year, created.month, created.day)

            if last_date is None:
                # First story - check if it's today or yesterday
                today = datetime.now()
                today_date = datetime(today.year, today.month, today.day)
                yesterday_date = today_date - timedelta(days=1)

                if story_date == today_date or story_date == yesterday_date:
                    streak = 1
                    last_date = story_date
                else:
                    break
            else:
                # Check if this story is the day before the last one
                expected_date = last_date - timedelta(days=1)
                if story_date == expected_date or story_date == last_date:
                    if story_date == expected_date:
                        streak += 1
                    last_date = story_date
                else:
                    break

        return streak
