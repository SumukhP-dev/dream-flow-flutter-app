"""
Notification service for sending push notifications via FCM and APNs.

Handles bedtime reminders, streak notifications, story recommendations, and weekly summaries.
"""

import logging
from datetime import time
from typing import Optional
from uuid import UUID

from supabase import Client

logger = logging.getLogger("dream_flow")


class NotificationService:
    """Service for managing push notifications."""

    def __init__(self, supabase_client: Client):
        """
        Initialize notification service.

        Args:
            supabase_client: Supabase client instance with service-role authentication
        """
        self.client = supabase_client

    def register_token(
        self,
        user_id: UUID,
        token: str,
        platform: str,
        device_id: Optional[str] = None,
    ) -> dict:
        """
        Register a notification token for a user.

        Args:
            user_id: UUID of the user
            token: FCM or APNs token
            platform: 'android', 'ios', or 'web'
            device_id: Optional device identifier

        Returns:
            Created or updated token record
        """
        token_data = {
            "user_id": str(user_id),
            "token": token,
            "platform": platform,
        }
        if device_id:
            token_data["device_id"] = device_id

        # Upsert token (update if exists, insert if not)
        response = (
            self.client.table("notification_tokens")
            .upsert(
                token_data,
                on_conflict="user_id,token,platform",
            )
            .execute()
        )

        return response.data[0] if response.data else {}

    def get_user_tokens(
        self, user_id: UUID, platform: Optional[str] = None
    ) -> list[dict]:
        """
        Get all notification tokens for a user.

        Args:
            user_id: UUID of the user
            platform: Optional platform filter ('android', 'ios', 'web')

        Returns:
            List of token records
        """
        query = (
            self.client.table("notification_tokens")
            .select("*")
            .eq("user_id", str(user_id))
        )

        if platform:
            query = query.eq("platform", platform)

        response = query.execute()
        return response.data if response.data else []

    def delete_token(self, user_id: UUID, token: str) -> None:
        """
        Delete a notification token.

        Args:
            user_id: UUID of the user
            token: Token to delete
        """
        self.client.table("notification_tokens").delete().eq(
            "user_id", str(user_id)
        ).eq("token", token).execute()

    def get_notification_preferences(self, user_id: UUID) -> Optional[dict]:
        """
        Get user's notification preferences.

        Args:
            user_id: UUID of the user

        Returns:
            Notification preferences dictionary or None
        """
        response = (
            self.client.table("notification_preferences")
            .select("*")
            .eq("user_id", str(user_id))
            .maybe_single()
            .execute()
        )
        return response.data if response.data else None

    def update_notification_preferences(
        self,
        user_id: UUID,
        bedtime_reminders_enabled: Optional[bool] = None,
        bedtime_reminder_time: Optional[time] = None,
        streak_notifications_enabled: Optional[bool] = None,
        story_recommendations_enabled: Optional[bool] = None,
        weekly_summary_enabled: Optional[bool] = None,
        maestro_nudges_enabled: Optional[bool] = None,
        maestro_digest_time: Optional[time] = None,
    ) -> dict:
        """
        Update user's notification preferences.

        Args:
            user_id: UUID of the user
            bedtime_reminders_enabled: Enable/disable bedtime reminders
            bedtime_reminder_time: Time for bedtime reminder (HH:MM format)
            streak_notifications_enabled: Enable/disable streak notifications
            story_recommendations_enabled: Enable/disable story recommendations
            weekly_summary_enabled: Enable/disable weekly summaries

        Returns:
            Updated preferences dictionary
        """
        preferences_data = {}

        if bedtime_reminders_enabled is not None:
            preferences_data["bedtime_reminders_enabled"] = bedtime_reminders_enabled
        if bedtime_reminder_time is not None:
            preferences_data["bedtime_reminder_time"] = (
                bedtime_reminder_time.isoformat()
            )
        if streak_notifications_enabled is not None:
            preferences_data["streak_notifications_enabled"] = (
                streak_notifications_enabled
            )
        if story_recommendations_enabled is not None:
            preferences_data["story_recommendations_enabled"] = (
                story_recommendations_enabled
            )
        if weekly_summary_enabled is not None:
            preferences_data["weekly_summary_enabled"] = weekly_summary_enabled
        if maestro_nudges_enabled is not None:
            preferences_data["maestro_nudges_enabled"] = maestro_nudges_enabled
        if maestro_digest_time is not None:
            preferences_data["maestro_digest_time"] = maestro_digest_time.isoformat()

        # Check if preferences exist
        existing = (
            self.client.table("notification_preferences")
            .select("*")
            .eq("user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if existing.data:
            # Update existing preferences
            response = (
                self.client.table("notification_preferences")
                .update(preferences_data)
                .eq("id", existing.data["id"])
                .execute()
            )
            return response.data[0] if response.data else existing.data
        else:
            # Create new preferences with defaults
            default_preferences = {
                "user_id": str(user_id),
                "bedtime_reminders_enabled": True,
                "streak_notifications_enabled": True,
                "story_recommendations_enabled": True,
                "weekly_summary_enabled": True,
                "maestro_nudges_enabled": False,
            }
            default_preferences.update(preferences_data)

            response = (
                self.client.table("notification_preferences")
                .insert(default_preferences)
                .execute()
            )
            return response.data[0] if response.data else {}

    def get_users_for_bedtime_reminder(self, reminder_time: time) -> list[dict]:
        """
        Get all users who should receive bedtime reminders at the specified time.

        Args:
            reminder_time: Time to check (HH:MM format)

        Returns:
            List of user records with tokens and preferences
        """
        # Get all users with bedtime reminders enabled and matching time
        response = (
            self.client.table("notification_preferences")
            .select("*, notification_tokens(*)")
            .eq("bedtime_reminders_enabled", True)
            .eq("bedtime_reminder_time", reminder_time.isoformat())
            .execute()
        )

        return response.data if response.data else []

    def get_users_with_active_streaks(self) -> list[dict]:
        """
        Get all users with active streaks who should receive streak notifications.

        Returns:
            List of user records with tokens and streak information
        """
        # Get users with active streaks (current_streak > 0)
        response = (
            self.client.table("user_streaks")
            .select("*, notification_preferences!inner(*), notification_tokens(*)")
            .gt("current_streak", 0)
            .eq("notification_preferences.streak_notifications_enabled", True)
            .execute()
        )

        return response.data if response.data else []

    def send_maestro_nudge(
        self, user_id: UUID, title: str, body: str
    ) -> dict[str, int]:
        """
        Send a Maestro Mode automation nudge to all registered devices for a caregiver.

        This is a lightweight placeholder that logs the outbound payload so mobile clients
        can poll/receive updates even if FCM/APNs credentials are not configured locally.
        """
        tokens = self.get_user_tokens(user_id)
        delivered = 0
        for token in tokens:
            delivered += 1
            logger.info(
                "notification.maestro_nudge user=%s platform=%s device=%s title=%s body=%s",
                user_id,
                token.get("platform"),
                token.get("device_id"),
                title,
                body,
            )
        return {"delivered": delivered}
