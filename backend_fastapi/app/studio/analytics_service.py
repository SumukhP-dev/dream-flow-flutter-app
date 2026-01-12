from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Any, Optional
from uuid import UUID

from ..shared.supabase_client import SupabaseClient


logger = logging.getLogger(__name__)


class AnalyticsService:
    """Service for creator analytics and metrics."""

    def __init__(self, supabase_client: SupabaseClient):
        """
        Initialize AnalyticsService.

        Args:
            supabase_client: SupabaseClient for database operations
        """
        self.supabase_client = supabase_client

    def get_render_stats(
        self,
        user_id: UUID,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> dict[str, Any]:
        """
        Get render statistics for a user.

        Args:
            user_id: User ID
            start_date: Start date for statistics (default: 30 days ago)
            end_date: End date for statistics (default: now)

        Returns:
            Dictionary with render statistics
        """
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=30)
        if not end_date:
            end_date = datetime.utcnow()

        # Count total renders (sessions)
        response = (
            self.supabase_client.client.table("sessions")
            .select("id", count="exact")
            .eq("user_id", str(user_id))
            .gte("created_at", start_date.isoformat())
            .lte("created_at", end_date.isoformat())
            .execute()
        )

        total_renders = response.count if hasattr(response, "count") else 0

        # Count renders by status (if we track status)
        # For now, assume all completed sessions are successful renders

        return {
            "user_id": str(user_id),
            "period": {
                "start": start_date.isoformat(),
                "end": end_date.isoformat(),
            },
            "total_renders": total_renders,
            "successful_renders": total_renders,  # TODO: Track failures separately
            "failed_renders": 0,
        }

    def get_download_stats(
        self,
        user_id: UUID,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> dict[str, Any]:
        """
        Get download statistics for a user.

        Args:
            user_id: User ID
            start_date: Start date for statistics (default: 30 days ago)
            end_date: End date for statistics (default: now)

        Returns:
            Dictionary with download statistics
        """
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=30)
        if not end_date:
            end_date = datetime.utcnow()

        # Count downloads (if we track downloads in a separate table)
        # For now, estimate based on session assets
        response = (
            self.supabase_client.client.table("session_assets")
            .select("id", count="exact")
            .eq("session.user_id", str(user_id))  # Join with sessions
            .gte("created_at", start_date.isoformat())
            .lte("created_at", end_date.isoformat())
            .execute()
        )

        total_downloads = response.count if hasattr(response, "count") else 0

        return {
            "user_id": str(user_id),
            "period": {
                "start": start_date.isoformat(),
                "end": end_date.isoformat(),
            },
            "total_downloads": total_downloads,
            "downloads_by_type": {
                "video": 0,  # TODO: Track by asset type
                "audio": 0,
                "frames": 0,
            },
        }

    def get_template_performance(
        self,
        user_id: UUID,
        template_id: Optional[UUID] = None,
    ) -> dict[str, Any]:
        """
        Get template performance statistics.

        Args:
            user_id: User ID
            template_id: Optional template ID (if None, returns all templates)

        Returns:
            Dictionary with template performance statistics
        """
        if template_id:
            # Get stats for specific template
            response = (
                self.supabase_client.client.table("sessions")
                .select("id", count="exact")
                .eq("user_id", str(user_id))
                .eq("template_id", str(template_id))
                .execute()
            )

            usage_count = response.count if hasattr(response, "count") else 0

            return {
                "template_id": str(template_id),
                "usage_count": usage_count,
                "success_rate": 1.0,  # TODO: Calculate from actual data
            }
        else:
            # Get stats for all templates
            templates_response = (
                self.supabase_client.client.table("templates")
                .select("id, name")
                .eq("user_id", str(user_id))
                .execute()
            )

            templates = []
            for template in templates_response.data or []:
                template_id = UUID(template["id"])
                sessions_response = (
                    self.supabase_client.client.table("sessions")
                    .select("id", count="exact")
                    .eq("user_id", str(user_id))
                    .eq("template_id", str(template_id))
                    .execute()
                )

                usage_count = (
                    sessions_response.count
                    if hasattr(sessions_response, "count")
                    else 0
                )

                templates.append(
                    {
                        "template_id": str(template_id),
                        "template_name": template.get("name", "Unnamed"),
                        "usage_count": usage_count,
                    }
                )

            return {
                "templates": templates,
                "total_templates": len(templates),
            }

    def get_referral_revenue(
        self,
        user_id: UUID,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> dict[str, Any]:
        """
        Get referral revenue statistics.

        Args:
            user_id: User ID
            start_date: Start date for statistics (default: 30 days ago)
            end_date: End date for statistics (default: now)

        Returns:
            Dictionary with referral revenue statistics
        """
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=30)
        if not end_date:
            end_date = datetime.utcnow()

        # TODO: Implement referral tracking
        # This would require a referrals table tracking:
        # - Referrer user_id
        # - Referred user_id
        # - Revenue generated
        # - Commission rate

        return {
            "user_id": str(user_id),
            "period": {
                "start": start_date.isoformat(),
                "end": end_date.isoformat(),
            },
            "total_referrals": 0,
            "total_revenue": 0.0,
            "commission_earned": 0.0,
        }

    def get_overview_stats(
        self,
        user_id: UUID,
    ) -> dict[str, Any]:
        """
        Get overview statistics for a creator.

        Args:
            user_id: User ID

        Returns:
            Dictionary with overview statistics
        """
        # Get render stats (last 30 days)
        render_stats = self.get_render_stats(user_id)

        # Get download stats (last 30 days)
        download_stats = self.get_download_stats(user_id)

        # Get template performance
        template_perf = self.get_template_performance(user_id)

        # Get referral revenue (last 30 days)
        referral_revenue = self.get_referral_revenue(user_id)

        return {
            "user_id": str(user_id),
            "renders": render_stats,
            "downloads": download_stats,
            "templates": template_perf,
            "referrals": referral_revenue,
            "generated_at": datetime.utcnow().isoformat(),
        }
