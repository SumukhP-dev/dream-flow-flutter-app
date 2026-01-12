"""
Story service for Studio Website.

Handles CRUD operations for stories created in the Studio with rich editing capabilities.
"""

import logging
from typing import Optional, Any
from uuid import UUID

from fastapi import HTTPException

from ..shared.supabase_client import SupabaseClient
from ..core.services import StoryGenerator, NarrationGenerator, VisualGenerator
from ..core.prompting import PromptBuilder, PromptBuilderMode
from ..core.guardrails import ContentGuard, GuardrailMode

logger = logging.getLogger("dreamflow_studio.story_service")


class StoryService:
    """Service for managing Studio stories."""

    def __init__(self, supabase_client: SupabaseClient):
        """Initialize story service with Supabase client."""
        self.supabase = supabase_client
        self.prompt_builder = PromptBuilder(mode=PromptBuilderMode.BRANDED_WELLNESS)
        self.guard = ContentGuard(mode=GuardrailMode.BRAND_COMPLIANCE)
        self.story_gen = StoryGenerator(prompt_builder=self.prompt_builder)
        self.narration_gen = NarrationGenerator(prompt_builder=self.prompt_builder)
        self.visual_gen = VisualGenerator(prompt_builder=self.prompt_builder)

    def create_story(
        self,
        user_id: UUID,
        prompt: str,
        theme: str,
        title: Optional[str] = None,
        content: Optional[str] = None,
        parameters: Optional[dict[str, Any]] = None,
        generate_video: bool = False,
        generate_audio: bool = False,
    ) -> dict[str, Any]:
        """
        Create a new story.

        If content is not provided, generates story using AI.
        If generate_video or generate_audio is True, queues media generation.

        Args:
            user_id: UUID of the user
            prompt: Story prompt
            theme: Story theme
            title: Optional story title (generated if not provided)
            content: Optional story content (generated if not provided)
            parameters: Optional story parameters (tone, length, style, etc.)
            generate_video: Whether to generate video
            generate_audio: Whether to generate audio

        Returns:
            Created story dictionary
        """
        # Generate story content if not provided
        if not content:
            try:
                story_result = self.story_gen.generate(
                    prompt=prompt,
                    theme=theme,
                    target_length=parameters.get("target_length", 400)
                    if parameters
                    else 400,
                )
                content = story_result.story_text
                if not title:
                    # Extract title from first line or use prompt
                    title = content.split("\n")[0].strip()[:100] or prompt[:100]
            except Exception as e:
                logger.error(f"Failed to generate story: {e}")
                raise HTTPException(
                    status_code=500, detail=f"Story generation failed: {str(e)}"
                )

        if not title:
            title = prompt[:100] or "Untitled Story"

        # Create story in database
        story_data = {
            "user_id": str(user_id),
            "title": title,
            "content": content,
            "theme": theme,
            "parameters": parameters or {},
            "video_url": "pending" if generate_video else None,
            "audio_url": "pending" if generate_audio else None,
        }

        try:
            response = (
                self.supabase.client.table("stories").insert(story_data).execute()
            )
            story = response.data[0] if response.data else story_data

            # Queue media generation if requested
            if generate_video:
                self._queue_video_generation(story["id"], content, title, theme)
            if generate_audio:
                self._queue_audio_generation(story["id"], content, title, theme)

            return story
        except Exception as e:
            logger.error(f"Failed to create story: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to create story: {str(e)}"
            )

    def get_story(self, story_id: UUID, user_id: UUID) -> Optional[dict[str, Any]]:
        """
        Get a story by ID.

        Args:
            story_id: UUID of the story
            user_id: UUID of the user (for authorization)

        Returns:
            Story dictionary or None if not found
        """
        try:
            response = (
                self.supabase.client.table("stories")
                .select("*")
                .eq("id", str(story_id))
                .eq("user_id", str(user_id))
                .maybe_single()
                .execute()
            )
            return response.data if response.data else None
        except Exception as e:
            logger.error(f"Failed to get story: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to get story: {str(e)}"
            )

    def update_story(
        self,
        story_id: UUID,
        user_id: UUID,
        title: Optional[str] = None,
        content: Optional[str] = None,
        theme: Optional[str] = None,
        parameters: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        """
        Update a story.

        Args:
            story_id: UUID of the story
            user_id: UUID of the user (for authorization)
            title: Optional new title
            content: Optional new content
            theme: Optional new theme
            parameters: Optional new parameters

        Returns:
            Updated story dictionary
        """
        update_data: dict[str, Any] = {}
        if title is not None:
            update_data["title"] = title
        if content is not None:
            update_data["content"] = content
        if theme is not None:
            update_data["theme"] = theme
        if parameters is not None:
            update_data["parameters"] = parameters

        if not update_data:
            # No updates provided, return existing story
            story = self.get_story(story_id, user_id)
            if not story:
                raise HTTPException(status_code=404, detail="Story not found")
            return story

        try:
            response = (
                self.supabase.client.table("stories")
                .update(update_data)
                .eq("id", str(story_id))
                .eq("user_id", str(user_id))
                .execute()
            )
            if not response.data:
                raise HTTPException(status_code=404, detail="Story not found")
            return response.data[0]
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to update story: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to update story: {str(e)}"
            )

    def delete_story(self, story_id: UUID, user_id: UUID) -> bool:
        """
        Delete a story.

        Args:
            story_id: UUID of the story
            user_id: UUID of the user (for authorization)

        Returns:
            True if deleted successfully, False otherwise
        """
        try:
            response = (
                self.supabase.client.table("stories")
                .delete()
                .eq("id", str(story_id))
                .eq("user_id", str(user_id))
                .execute()
            )
            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Failed to delete story: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to delete story: {str(e)}"
            )

    def list_stories(
        self,
        user_id: UUID,
        page: int = 1,
        limit: int = 20,
        theme: Optional[str] = None,
        search: Optional[str] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
        has_video: Optional[bool] = None,
        has_audio: Optional[bool] = None,
    ) -> dict[str, Any]:
        """
        List stories with pagination and filters.

        Args:
            user_id: UUID of the user
            page: Page number (1-indexed)
            limit: Number of items per page
            theme: Optional theme filter
            search: Optional search term (searches title and content)
            sort_by: Field to sort by (default: created_at)
            sort_order: Sort order (asc or desc)
            has_video: Optional filter for stories with video
            has_audio: Optional filter for stories with audio

        Returns:
            Dictionary with stories, pagination info
        """
        offset = (page - 1) * limit

        try:
            query = (
                self.supabase.client.table("stories")
                .select("*")
                .eq("user_id", str(user_id))
            )

            # Apply filters
            if theme:
                query = query.eq("theme", theme)
            if has_video is not None:
                if has_video:
                    query = query.not_.is_("video_url", "null")
                else:
                    query = query.is_("video_url", "null")
            if has_audio is not None:
                if has_audio:
                    query = query.not_.is_("audio_url", "null")
                else:
                    query = query.is_("audio_url", "null")
            if search:
                # Search in title and content (PostgreSQL full-text search)
                query = query.or_(f"title.ilike.%{search}%,content.ilike.%{search}%")

            # Apply sorting
            ascending = sort_order.lower() == "asc"
            query = query.order(sort_by, desc=not ascending)

            # Apply pagination
            query = query.range(offset, offset + limit - 1)

            response = query.execute()
            stories = response.data if response.data else []

            # Get total count (for pagination)
            count_query = (
                self.supabase.client.table("stories")
                .select("id", count="exact")
                .eq("user_id", str(user_id))
            )
            if theme:
                count_query = count_query.eq("theme", theme)
            if has_video is not None:
                if has_video:
                    count_query = count_query.not_.is_("video_url", "null")
                else:
                    count_query = count_query.is_("video_url", "null")
            if has_audio is not None:
                if has_audio:
                    count_query = count_query.not_.is_("audio_url", "null")
                else:
                    count_query = count_query.is_("audio_url", "null")
            if search:
                count_query = count_query.or_(
                    f"title.ilike.%{search}%,content.ilike.%{search}%"
                )

            count_response = count_query.execute()
            total = (
                count_response.count
                if hasattr(count_response, "count")
                else len(stories)
            )

            return {
                "stories": stories,
                "pagination": {
                    "page": page,
                    "limit": limit,
                    "total": total,
                    "total_pages": (total + limit - 1) // limit,
                },
            }
        except Exception as e:
            logger.error(f"Failed to list stories: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to list stories: {str(e)}"
            )

    def _queue_video_generation(
        self, story_id: str, content: str, title: str, theme: str
    ):
        """Queue video generation for a story."""
        # TODO: Integrate with media generation service
        logger.info(f"Queuing video generation for story {story_id}")
        # This would typically call a background job queue

    def _queue_audio_generation(
        self, story_id: str, content: str, title: str, theme: str
    ):
        """Queue audio generation for a story."""
        # TODO: Integrate with media generation service
        logger.info(f"Queuing audio generation for story {story_id}")
        # This would typically call a background job queue
