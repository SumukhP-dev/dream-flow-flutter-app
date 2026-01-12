"""
Media service for Studio Website.

Handles media generation status tracking and regeneration.
"""

import logging
from typing import Optional
from uuid import UUID

from fastapi import HTTPException

from ..shared.supabase_client import SupabaseClient

logger = logging.getLogger("dreamflow_studio.media_service")


class MediaService:
    """Service for managing media generation status."""

    def __init__(self, supabase_client: SupabaseClient):
        """Initialize media service with Supabase client."""
        self.supabase = supabase_client

    def get_media_status(self, story_id: UUID, user_id: UUID) -> dict[str, str]:
        """
        Get media generation status for a story.

        Args:
            story_id: UUID of the story
            user_id: UUID of the user (for authorization)

        Returns:
            Dictionary with video and audio status
        """
        try:
            response = (
                self.supabase.client.table("stories")
                .select("video_url, audio_url")
                .eq("id", str(story_id))
                .eq("user_id", str(user_id))
                .maybe_single()
                .execute()
            )
            if not response.data:
                raise HTTPException(status_code=404, detail="Story not found")

            story = response.data
            return {
                "video": self._get_status_from_url(story.get("video_url")),
                "audio": self._get_status_from_url(story.get("audio_url")),
            }
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to get media status: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to get media status: {str(e)}"
            )

    def regenerate_media(
        self,
        story_id: UUID,
        user_id: UUID,
        media_type: str,
    ) -> dict[str, str]:
        """
        Regenerate media for a story.

        Args:
            story_id: UUID of the story
            user_id: UUID of the user (for authorization)
            media_type: Type of media to regenerate ('video' or 'audio')

        Returns:
            Dictionary with status message
        """
        if media_type not in ("video", "audio"):
            raise HTTPException(
                status_code=400, detail=f"Invalid media type: {media_type}"
            )

        # Get story
        try:
            response = (
                self.supabase.client.table("stories")
                .select("*")
                .eq("id", str(story_id))
                .eq("user_id", str(user_id))
                .maybe_single()
                .execute()
            )
            if not response.data:
                raise HTTPException(status_code=404, detail="Story not found")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to get story: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to get story: {str(e)}"
            )

        # Update status to pending
        update_field = f"{media_type}_url"
        try:
            self.supabase.client.table("stories").update({update_field: "pending"}).eq(
                "id", str(story_id)
            ).eq("user_id", str(user_id)).execute()

            # TODO: Queue media generation
            # This would typically call a background job queue
            logger.info(f"Queued {media_type} regeneration for story {story_id}")

            return {
                "status": "queued",
                "message": f"{media_type.capitalize()} regeneration queued",
            }
        except Exception as e:
            logger.error(f"Failed to queue media regeneration: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to queue media regeneration: {str(e)}"
            )

    def get_media_usage(self, user_id: UUID) -> dict[str, dict[str, int]]:
        """
        Get media usage statistics for a user.

        Args:
            user_id: UUID of the user

        Returns:
            Dictionary with usage statistics for video and audio
        """
        try:
            # Count stories with video
            video_response = (
                self.supabase.client.table("stories")
                .select("id", count="exact")
                .eq("user_id", str(user_id))
                .not_.is_("video_url", "null")
                .neq("video_url", "pending")
                .execute()
            )
            video_count = (
                video_response.count if hasattr(video_response, "count") else 0
            )

            # Count stories with audio
            audio_response = (
                self.supabase.client.table("stories")
                .select("id", count="exact")
                .eq("user_id", str(user_id))
                .not_.is_("audio_url", "null")
                .neq("audio_url", "pending")
                .execute()
            )
            audio_count = (
                audio_response.count if hasattr(audio_response, "count") else 0
            )

            # TODO: Get limits from subscription/user settings
            # For now, use default limits
            video_limit = 10  # Default monthly limit
            audio_limit = 20  # Default monthly limit

            return {
                "video": {
                    "count": video_count,
                    "limit": video_limit,
                    "remaining": max(0, video_limit - video_count),
                },
                "audio": {
                    "count": audio_count,
                    "limit": audio_limit,
                    "remaining": max(0, audio_limit - audio_count),
                },
            }
        except Exception as e:
            logger.error(f"Failed to get media usage: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to get media usage: {str(e)}"
            )

    def _get_status_from_url(self, url: Optional[str]) -> str:
        """
        Get status from URL value.

        Args:
            url: URL string or None

        Returns:
            Status string: 'available', 'pending', or 'none'
        """
        if not url:
            return "none"
        if url == "pending":
            return "pending"
        if url.startswith("http"):
            return "available"
        return "none"
