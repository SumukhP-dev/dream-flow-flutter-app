from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Optional
from uuid import UUID, uuid4

from ..core.prompting import PromptBuilderMode
from ..shared.supabase_client import SupabaseClient


logger = logging.getLogger(__name__)


class TemplateService:
    """Service for managing story generation templates."""

    def __init__(self, supabase_client: SupabaseClient):
        """
        Initialize TemplateService.

        Args:
            supabase_client: SupabaseClient for database operations
        """
        self.supabase_client = supabase_client

    def create_template(
        self,
        user_id: UUID,
        name: str,
        prompt: str,
        theme: str,
        target_length: int = 400,
        num_scenes: int = 4,
        voice: Optional[str] = None,
        mode: PromptBuilderMode = PromptBuilderMode.BEDTIME_STORY,
        description: Optional[str] = None,
    ) -> dict[str, Any]:
        """
        Create a new template.

        Args:
            user_id: User ID creating the template
            name: Template name
            prompt: Base prompt for the template
            theme: Theme for the template
            target_length: Target story length
            num_scenes: Number of scenes
            voice: Voice preset
            mode: Prompt builder mode
            description: Optional template description

        Returns:
            Created template dictionary
        """
        template_id = uuid4()
        now = datetime.utcnow()

        template_data = {
            "id": str(template_id),
            "user_id": str(user_id),
            "name": name,
            "description": description,
            "prompt": prompt,
            "theme": theme,
            "target_length": target_length,
            "num_scenes": num_scenes,
            "voice": voice,
            "mode": mode.value,
            "created_at": now.isoformat(),
            "updated_at": now.isoformat(),
        }

        (self.supabase_client.client.table("templates").insert(template_data).execute())

        return template_data

    def get_template(
        self, template_id: UUID, user_id: UUID
    ) -> Optional[dict[str, Any]]:
        """
        Get a template by ID.

        Args:
            template_id: Template ID
            user_id: User ID (for authorization)

        Returns:
            Template dictionary or None if not found
        """
        response = (
            self.supabase_client.client.table("templates")
            .select("*")
            .eq("id", str(template_id))
            .eq("user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        return response.data if response.data else None

    def list_templates(
        self,
        user_id: UUID,
        limit: int = 20,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        """
        List templates for a user.

        Args:
            user_id: User ID
            limit: Maximum number of templates to return
            offset: Number of templates to skip

        Returns:
            List of template dictionaries
        """
        response = (
            self.supabase_client.client.table("templates")
            .select("*")
            .eq("user_id", str(user_id))
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )

        return response.data if response.data else []

    def update_template(
        self,
        template_id: UUID,
        user_id: UUID,
        name: Optional[str] = None,
        prompt: Optional[str] = None,
        theme: Optional[str] = None,
        target_length: Optional[int] = None,
        num_scenes: Optional[int] = None,
        voice: Optional[str] = None,
        mode: Optional[PromptBuilderMode] = None,
        description: Optional[str] = None,
    ) -> Optional[dict[str, Any]]:
        """
        Update a template.

        Args:
            template_id: Template ID
            user_id: User ID (for authorization)
            name: New template name (optional)
            prompt: New prompt (optional)
            theme: New theme (optional)
            target_length: New target length (optional)
            num_scenes: New number of scenes (optional)
            voice: New voice preset (optional)
            mode: New prompt builder mode (optional)
            description: New description (optional)

        Returns:
            Updated template dictionary or None if not found
        """
        # Build update dict
        update_data: dict[str, Any] = {
            "updated_at": datetime.utcnow().isoformat(),
        }

        if name is not None:
            update_data["name"] = name
        if prompt is not None:
            update_data["prompt"] = prompt
        if theme is not None:
            update_data["theme"] = theme
        if target_length is not None:
            update_data["target_length"] = target_length
        if num_scenes is not None:
            update_data["num_scenes"] = num_scenes
        if voice is not None:
            update_data["voice"] = voice
        if mode is not None:
            update_data["mode"] = mode.value
        if description is not None:
            update_data["description"] = description

        response = (
            self.supabase_client.client.table("templates")
            .update(update_data)
            .eq("id", str(template_id))
            .eq("user_id", str(user_id))
            .execute()
        )

        if not response.data:
            return None

        return response.data[0] if isinstance(response.data, list) else response.data

    def delete_template(self, template_id: UUID, user_id: UUID) -> bool:
        """
        Delete a template.

        Args:
            template_id: Template ID
            user_id: User ID (for authorization)

        Returns:
            True if deleted, False if not found
        """
        response = (
            self.supabase_client.client.table("templates")
            .delete()
            .eq("id", str(template_id))
            .eq("user_id", str(user_id))
            .execute()
        )

        return bool(response.data)

    def get_template_usage_stats(
        self,
        template_id: UUID,
        user_id: UUID,
    ) -> dict[str, Any]:
        """
        Get usage statistics for a template.

        Args:
            template_id: Template ID
            user_id: User ID (for authorization)

        Returns:
            Dictionary with usage statistics
        """
        # Verify template exists and belongs to user
        template = self.get_template(template_id, user_id)
        if not template:
            return {}

        # Count sessions created from this template
        # (This assumes sessions table has a template_id field)
        response = (
            self.supabase_client.client.table("sessions")
            .select("id", count="exact")
            .eq("template_id", str(template_id))
            .execute()
        )

        usage_count = response.count if hasattr(response, "count") else 0

        return {
            "template_id": str(template_id),
            "usage_count": usage_count,
            "created_at": template.get("created_at"),
            "last_used": None,  # TODO: Track last usage timestamp
        }
