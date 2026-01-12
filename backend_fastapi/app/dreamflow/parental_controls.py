"""
Parental Controls Service for Kids Bedtime Stories

Provides endpoints for parents to manage child safety settings, review content,
track usage, and manage bedtime routines.
"""

from datetime import date, datetime, time
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Header, status
from pydantic import BaseModel, Field
from typing import Optional

from ..shared.auth import get_authenticated_user_id
from ..shared.supabase_client import SupabaseClient
from ..shared.config import get_settings
from .subscription_service import SubscriptionService

# Pydantic Models
class ParentalSettingsRequest(BaseModel):
    child_profile_id: UUID
    bedtime_hour: Optional[int] = Field(None, ge=0, le=23)
    bedtime_minute: Optional[int] = Field(None, ge=0, le=59)
    bedtime_enabled: Optional[bool] = None
    daily_screen_time_minutes: Optional[int] = Field(None, gt=0)
    screen_time_enabled: Optional[bool] = None
    require_story_approval: Optional[bool] = None
    blocked_themes: Optional[List[str]] = None
    blocked_characters: Optional[List[str]] = None
    max_story_length_minutes: Optional[int] = Field(None, gt=0)
    emergency_notification_enabled: Optional[bool] = None
    emergency_contact_email: Optional[str] = None
    track_usage: Optional[bool] = None


class ParentalSettingsResponse(BaseModel):
    id: UUID
    child_profile_id: UUID
    bedtime_hour: Optional[int]
    bedtime_minute: Optional[int]
    bedtime_enabled: bool
    daily_screen_time_minutes: Optional[int]
    screen_time_enabled: bool
    require_story_approval: bool
    blocked_themes: List[str]
    blocked_characters: List[str]
    max_story_length_minutes: Optional[int]
    emergency_notification_enabled: bool
    emergency_contact_email: Optional[str]
    track_usage: bool
    created_at: datetime
    updated_at: datetime


class ContentReviewItem(BaseModel):
    id: UUID
    session_id: UUID
    child_profile_id: UUID
    story_text: str
    theme: str
    content_rating: Optional[str]
    suggested_age_min: Optional[int]
    suggested_age_max: Optional[int]
    status: str
    rejection_reason: Optional[str]
    created_at: datetime


class ContentReviewAction(BaseModel):
    review_id: UUID
    action: str = Field(..., pattern="^(approve|reject)$")
    rejection_reason: Optional[str] = None


class ChildUsageReport(BaseModel):
    id: UUID
    child_profile_id: UUID
    report_date: date
    stories_viewed: int
    total_viewing_time_minutes: int
    favorite_themes: List[str]
    favorite_characters: List[str]
    bedtime_compliance: Optional[bool]
    stories_after_bedtime: int
    screen_time_used_minutes: int
    screen_time_limit_minutes: Optional[int]
    screen_time_exceeded: bool
    created_at: datetime
    updated_at: datetime


class BedtimeRoutineStep(BaseModel):
    step: str
    order: int
    duration_minutes: Optional[int] = None


class BedtimeRoutineRequest(BaseModel):
    routine_name: str
    child_profile_id: Optional[UUID] = None
    routine_steps: List[BedtimeRoutineStep]
    is_family_routine: bool = False


class BedtimeRoutineResponse(BaseModel):
    id: UUID
    parent_user_id: UUID
    child_profile_id: Optional[UUID]
    routine_name: str
    routine_steps: List[dict]
    is_active: bool
    is_family_routine: bool
    created_at: datetime
    updated_at: datetime


def create_parental_controls_router(supabase_client: SupabaseClient | None) -> APIRouter:
    """Factory that wires dependencies into the Parental Controls router."""
    router = APIRouter(prefix="/api/v1/parental-controls", tags=["parental-controls"])
    
    if not supabase_client:
        # Gracefully degrade if Supabase is not available
        @router.get("/settings/{child_profile_id}")
        async def _degraded():
            raise HTTPException(status_code=503, detail="Parental controls unavailable")
        return router

    subscription_service = SubscriptionService(supabase_client.client)
    settings_obj = get_settings()

    def _get_authorized_parent(authorization: Optional[str]) -> UUID:
        if not authorization:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required"
            )

        user_id = get_authenticated_user_id(authorization, settings_obj)
        if not subscription_service.is_family_plan(user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Family plan subscription required for parental controls",
            )
        return user_id

    @router.get("/settings/{child_profile_id}", response_model=ParentalSettingsResponse)
    async def get_parental_settings(
        child_profile_id: UUID,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Get parental settings for a specific child profile."""
        user_id = _get_authorized_parent(authorization)
        
        # Verify parent owns this child profile
        child_check = (
            supabase_client.client.table("family_profiles")
            .select("id")
            .eq("id", str(child_profile_id))
            .eq("parent_user_id", str(user_id))
            .execute()
        )

        if not child_check.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Child profile not found or access denied",
            )

        # Get parental settings
        result = (
            supabase_client.client.table("parental_settings")
            .select("*")
            .eq("child_profile_id", str(child_profile_id))
            .eq("parent_user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if not result.data:
            # Return default settings if none exist
            return ParentalSettingsResponse(
                id=UUID("00000000-0000-0000-0000-000000000000"),
                child_profile_id=child_profile_id,
                bedtime_hour=None,
                bedtime_minute=None,
                bedtime_enabled=False,
                daily_screen_time_minutes=None,
                screen_time_enabled=False,
                require_story_approval=False,
                blocked_themes=[],
                blocked_characters=[],
                max_story_length_minutes=None,
                emergency_notification_enabled=True,
                emergency_contact_email=None,
                track_usage=True,
                created_at=datetime.now(),
                updated_at=datetime.now(),
            )

        data = result.data
        return ParentalSettingsResponse(**data)

    @router.put("/settings", response_model=ParentalSettingsResponse)
    async def update_parental_settings(
        settings: ParentalSettingsRequest,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Create or update parental settings for a child profile."""
        user_id = _get_authorized_parent(authorization)
        
        # Verify parent owns this child profile
        child_check = (
            supabase_client.client.table("family_profiles")
            .select("id")
            .eq("id", str(settings.child_profile_id))
            .eq("parent_user_id", str(user_id))
            .execute()
        )

        if not child_check.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Child profile not found or access denied",
            )

        # Prepare update data
        update_data = {
            "parent_user_id": str(user_id),
            "child_profile_id": str(settings.child_profile_id),
        }

        if settings.bedtime_hour is not None:
            update_data["bedtime_hour"] = settings.bedtime_hour
        if settings.bedtime_minute is not None:
            update_data["bedtime_minute"] = settings.bedtime_minute
        if settings.bedtime_enabled is not None:
            update_data["bedtime_enabled"] = settings.bedtime_enabled
        if settings.daily_screen_time_minutes is not None:
            update_data["daily_screen_time_minutes"] = settings.daily_screen_time_minutes
        if settings.screen_time_enabled is not None:
            update_data["screen_time_enabled"] = settings.screen_time_enabled
        if settings.require_story_approval is not None:
            update_data["require_story_approval"] = settings.require_story_approval
        if settings.blocked_themes is not None:
            update_data["blocked_themes"] = settings.blocked_themes
        if settings.blocked_characters is not None:
            update_data["blocked_characters"] = settings.blocked_characters
        if settings.max_story_length_minutes is not None:
            update_data["max_story_length_minutes"] = settings.max_story_length_minutes
        if settings.emergency_notification_enabled is not None:
            update_data["emergency_notification_enabled"] = settings.emergency_notification_enabled
        if settings.emergency_contact_email is not None:
            update_data["emergency_contact_email"] = settings.emergency_contact_email
        if settings.track_usage is not None:
            update_data["track_usage"] = settings.track_usage

        # Upsert settings
        result = (
            supabase_client.client.table("parental_settings")
            .upsert(
                update_data,
                on_conflict="parent_user_id,child_profile_id",
            )
            .execute()
        )

        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update parental settings",
            )

        # Fetch updated settings
        updated = (
            supabase_client.client.table("parental_settings")
            .select("*")
            .eq("child_profile_id", str(settings.child_profile_id))
            .eq("parent_user_id", str(user_id))
            .single()
            .execute()
        )

        return ParentalSettingsResponse(**updated.data)

    @router.get("/review-queue", response_model=List[ContentReviewItem])
    async def get_review_queue(
        child_profile_id: Optional[UUID] = None,
        status_filter: Optional[str] = None,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Get content review queue for parent approval."""
        user_id = _get_authorized_parent(authorization)
        
        query = (
            supabase_client.client.table("content_review_queue")
            .select("*")
            .eq("parent_user_id", str(user_id))
            .order("created_at", desc=True)
        )

        if child_profile_id:
            query = query.eq("child_profile_id", str(child_profile_id))

        if status_filter:
            query = query.eq("status", status_filter)

        result = query.execute()

        return [ContentReviewItem(**item) for item in result.data]

    @router.post("/review-queue/action")
    async def review_content_action(
        action: ContentReviewAction,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Approve or reject content in review queue."""
        user_id = _get_authorized_parent(authorization)
        
        # Verify parent owns this review item
        review_check = (
            supabase_client.client.table("content_review_queue")
            .select("*")
            .eq("id", str(action.review_id))
            .eq("parent_user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if not review_check.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Review item not found or access denied",
            )

        update_data = {
            "status": "approved" if action.action == "approve" else "rejected",
            "reviewed_at": datetime.now().isoformat(),
            "reviewed_by": str(user_id),
        }

        if action.action == "reject" and action.rejection_reason:
            update_data["rejection_reason"] = action.rejection_reason

        result = (
            supabase_client.client.table("content_review_queue")
            .update(update_data)
            .eq("id", str(action.review_id))
            .execute()
        )

        return {"success": True, "status": update_data["status"]}

    @router.get("/usage-reports/{child_profile_id}", response_model=List[ChildUsageReport])
    async def get_usage_reports(
        child_profile_id: UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Get usage reports for a child profile."""
        user_id = _get_authorized_parent(authorization)
        
        # Verify parent owns this child profile
        child_check = (
            supabase_client.client.table("family_profiles")
            .select("id")
            .eq("id", str(child_profile_id))
            .eq("parent_user_id", str(user_id))
            .execute()
        )

        if not child_check.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Child profile not found or access denied",
            )

        query = (
            supabase_client.client.table("child_usage_reports")
            .select("*")
            .eq("child_profile_id", str(child_profile_id))
            .eq("parent_user_id", str(user_id))
            .order("report_date", desc=True)
        )

        if start_date:
            query = query.gte("report_date", start_date.isoformat())
        if end_date:
            query = query.lte("report_date", end_date.isoformat())

        result = query.execute()

        return [ChildUsageReport(**item) for item in result.data]

    @router.post("/bedtime-routines", response_model=BedtimeRoutineResponse)
    async def create_bedtime_routine(
        routine: BedtimeRoutineRequest,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Create a bedtime routine."""
        user_id = _get_authorized_parent(authorization)
        
        if routine.child_profile_id:
            # Verify parent owns this child profile
            child_check = (
                supabase_client.client.table("family_profiles")
                .select("id")
                .eq("id", str(routine.child_profile_id))
                .eq("parent_user_id", str(user_id))
                .execute()
            )

            if not child_check.data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Child profile not found or access denied",
                )

        routine_data = {
            "parent_user_id": str(user_id),
            "child_profile_id": str(routine.child_profile_id) if routine.child_profile_id else None,
            "routine_name": routine.routine_name,
            "routine_steps": [step.dict() for step in routine.routine_steps],
            "is_family_routine": routine.is_family_routine,
        }

        result = supabase_client.client.table("bedtime_routines").insert(routine_data).execute()

        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create bedtime routine",
            )

        return BedtimeRoutineResponse(**result.data[0])

    @router.get("/bedtime-routines", response_model=List[BedtimeRoutineResponse])
    async def get_bedtime_routines(
        child_profile_id: Optional[UUID] = None,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Get bedtime routines for a parent."""
        user_id = _get_authorized_parent(authorization)
        
        query = (
            supabase_client.client.table("bedtime_routines")
            .select("*")
            .eq("parent_user_id", str(user_id))
            .eq("is_active", True)
            .order("created_at", desc=True)
        )

        if child_profile_id:
            query = query.or_(
                f"child_profile_id.eq.{child_profile_id},is_family_routine.eq.true"
            )

        result = query.execute()

        return [BedtimeRoutineResponse(**item) for item in result.data]

    return router

