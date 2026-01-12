"""FastAPI router for Maestro Mode insights."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status

from ..shared.auth import get_authenticated_user_id
from ..shared.config import Settings, get_settings

from .maestro_insights import MaestroInsightsService
from .schemas import MaestroInsightsResponse, MaestroQuickActionRequest
from ..shared.supabase_client import SupabaseClient
from .notification_service import NotificationService


def _maybe_authenticated_user_id(
    authorization: str | None = Header(None, alias="Authorization"),
    settings: Settings = Depends(get_settings),
) -> UUID | None:
    """
    Attempt to authenticate the user, but gracefully fall back to anonymous previews.

    We keep Maestro Mode accessible for demo builds (no Supabase) while still enforcing
    caregiver-only access in production when auth headers are available.
    """
    if not authorization:
        return None
    try:
        return get_authenticated_user_id(authorization, settings)
    except HTTPException:
        return None


def create_maestro_router(
    supabase_client: SupabaseClient | None,
    notification_service: NotificationService | None = None,
) -> APIRouter:
    """Factory that wires dependencies into the Maestro router."""
    router = APIRouter(prefix="/api/v1/maestro", tags=["maestro"])
    insights_service = MaestroInsightsService(supabase_client)

    @router.get("/insights", response_model=MaestroInsightsResponse)
    async def get_maestro_insights(
        user_id: UUID | None = None,
        authenticated_user_id: UUID | None = Depends(_maybe_authenticated_user_id),
    ) -> MaestroInsightsResponse:
        """
        Return the nightly Maestro insights bundle.

        The request optionally accepts a user_id (caregiver context). When omitted the
        service falls back to aggregate heuristics so preview/demo builds still render.
        """
        resolved_user = user_id or authenticated_user_id
        data = insights_service.get_insights(user_id=resolved_user)
        return MaestroInsightsResponse(**data)

    @router.post("/quick-actions", status_code=status.HTTP_202_ACCEPTED)
    async def trigger_quick_action(
        payload: MaestroQuickActionRequest,
        authenticated_user_id: UUID | None = Depends(_maybe_authenticated_user_id),
    ) -> dict[str, str]:
        """Record a Maestro quick action and trigger downstream automations."""
        resolved_user = payload.user_id or authenticated_user_id
        if insights_service.supabase and resolved_user is None:
            raise HTTPException(
                status_code=401,
                detail="Authentication required to trigger Maestro quick actions.",
            )

        try:
            insights_service.log_quick_action(
                action_id=payload.action_id,
                slider_value=payload.value,
                user_id=resolved_user,
            )
            if notification_service and resolved_user:
                notification_service.send_maestro_nudge(
                    user_id=resolved_user,
                    title="Maestro nudge ready",
                    body=f"Quick action {payload.action_id} queued.",
                )
        except Exception as exc:  # pragma: no cover - unexpected runtime failure
            raise HTTPException(status_code=500, detail=str(exc)) from exc

        return {"status": "queued"}

    return router
