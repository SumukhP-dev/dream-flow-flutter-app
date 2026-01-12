"""
Co-Viewing Service for Parent-Child Bedtime Stories

Provides endpoints for synchronized parent-child viewing, family story sharing,
and parent voice narration features.
"""

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Header, status
from pydantic import BaseModel, Field

from ..shared.auth import get_authenticated_user_id
from ..shared.supabase_client import SupabaseClient
from ..shared.config import get_settings


def create_co_viewing_router(supabase_client: SupabaseClient | None) -> APIRouter:
    """Factory that wires dependencies into the Co-Viewing router."""
    router = APIRouter(prefix="/api/v1/co-viewing", tags=["co-viewing"])
    
    if not supabase_client:
        # Gracefully degrade if Supabase is not available
        @router.post("/join")
        async def _degraded():
            raise HTTPException(status_code=503, detail="Co-viewing unavailable")
        return router

    # Pydantic Models
    class JoinCoViewRequest(BaseModel):
        session_id: UUID
        child_profile_id: UUID

    class CoViewSessionResponse(BaseModel):
        id: UUID
        session_id: UUID
        parent_user_id: UUID
        child_profile_id: Optional[UUID]
        co_view_mode: bool
        parent_joined_at: Optional[datetime]
        synchronized_playback: bool
        parent_controls_enabled: bool
        interaction_prompts_enabled: bool
        created_at: datetime

    class ParentVoiceRecordingRequest(BaseModel):
        recording_name: str
        child_profile_id: Optional[UUID] = None
        audio_url: str
        duration_seconds: Optional[int] = None
        language: str = "en"

    class ParentVoiceRecordingResponse(BaseModel):
        id: UUID
        parent_user_id: UUID
        child_profile_id: Optional[UUID]
        recording_name: str
        audio_url: str
        duration_seconds: Optional[int]
        language: str
        is_active: bool
        created_at: datetime
        updated_at: datetime

    class FamilyStoryItem(BaseModel):
        session_id: UUID
        story_text: str
        theme: str
        added_at: datetime
        is_family_favorite: bool

    class AddToFamilyLibraryRequest(BaseModel):
        session_id: UUID
        shared_with_siblings: bool = True
        is_family_favorite: bool = False

    @router.post("/join", response_model=CoViewSessionResponse)
    async def join_co_view_session(
        request: JoinCoViewRequest,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Parent joins a child's story session for co-viewing."""
        if not authorization:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
        
        user_id = get_authenticated_user_id(authorization, get_settings())
        
        # Verify parent owns this child profile
        child_check = (
            supabase_client.client.table("family_profiles")
            .select("id, parent_user_id")
            .eq("id", str(request.child_profile_id))
            .eq("parent_user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if not child_check.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Child profile not found or access denied",
            )

        # Create or update co-view session
        co_view_data = {
            "session_id": str(request.session_id),
            "parent_user_id": str(user_id),
            "child_profile_id": str(request.child_profile_id),
            "co_view_mode": True,
            "parent_joined_at": datetime.now().isoformat(),
            "synchronized_playback": True,
            "parent_controls_enabled": True,
        }

        result = (
            supabase_client.client.table("family_sessions")
            .upsert(
                co_view_data,
                on_conflict="session_id,parent_user_id",
            )
            .execute()
        )

        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to join co-view session",
            )

        # Fetch updated session
        updated = (
            supabase_client.client.table("family_sessions")
            .select("*")
            .eq("session_id", str(request.session_id))
            .eq("parent_user_id", str(user_id))
            .single()
            .execute()
        )

        return CoViewSessionResponse(**updated.data)

    @router.get("/sessions/{session_id}", response_model=CoViewSessionResponse)
    async def get_co_view_session(
        session_id: UUID,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Get co-view session details."""
        if not authorization:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
        
        user_id = get_authenticated_user_id(authorization, get_settings())

        result = (
            supabase_client.client.table("family_sessions")
            .select("*")
            .eq("session_id", str(session_id))
            .eq("parent_user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Co-view session not found",
            )

        return CoViewSessionResponse(**result.data)

    @router.post("/voice-recordings", response_model=ParentVoiceRecordingResponse)
    async def create_voice_recording(
        recording: ParentVoiceRecordingRequest,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Create a parent voice recording for story narration."""
        if not authorization:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
        
        user_id = get_authenticated_user_id(authorization, get_settings())

        if recording.child_profile_id:
            # Verify parent owns this child profile
            child_check = (
                supabase_client.client.table("family_profiles")
                .select("id")
                .eq("id", str(recording.child_profile_id))
                .eq("parent_user_id", str(user_id))
                .execute()
            )

            if not child_check.data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Child profile not found or access denied",
                )

        recording_data = {
            "parent_user_id": str(user_id),
            "child_profile_id": str(recording.child_profile_id) if recording.child_profile_id else None,
            "recording_name": recording.recording_name,
            "audio_url": recording.audio_url,
            "duration_seconds": recording.duration_seconds,
            "language": recording.language,
        }

        result = supabase_client.client.table("parent_voice_recordings").insert(recording_data).execute()

        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create voice recording",
            )

        return ParentVoiceRecordingResponse(**result.data[0])

    @router.get("/voice-recordings", response_model=List[ParentVoiceRecordingResponse])
    async def get_voice_recordings(
        child_profile_id: Optional[UUID] = None,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Get parent voice recordings."""
        if not authorization:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
        
        user_id = get_authenticated_user_id(authorization, get_settings())

        query = (
            supabase_client.client.table("parent_voice_recordings")
            .select("*")
            .eq("parent_user_id", str(user_id))
            .eq("is_active", True)
            .order("created_at", desc=True)
        )

        if child_profile_id:
            query = query.eq("child_profile_id", str(child_profile_id))

        result = query.execute()

        return [ParentVoiceRecordingResponse(**item) for item in result.data]

    @router.post("/family-library", response_model=dict)
    async def add_to_family_library(
        request: AddToFamilyLibraryRequest,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Add a story to the family story library."""
        if not authorization:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
        
        user_id = get_authenticated_user_id(authorization, get_settings())

        # Get family_id from any child profile (or use parent_user_id)
        family_id = user_id  # For now, use parent_user_id as family_id

        library_data = {
            "family_id": str(family_id),
            "session_id": str(request.session_id),
            "added_by_user_id": str(user_id),
            "shared_with_siblings": request.shared_with_siblings,
            "is_family_favorite": request.is_family_favorite,
        }

        result = supabase_client.client.table("family_story_library").insert(library_data).execute()

        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to add story to family library",
            )

        return {"success": True, "id": result.data[0]["id"]}

    @router.get("/family-library/{child_profile_id}", response_model=List[FamilyStoryItem])
    async def get_family_library(
        child_profile_id: UUID,
        authorization: Optional[str] = Header(None, alias="Authorization"),
    ):
        """Get family story library for a child."""
        if not authorization:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
        
        user_id = get_authenticated_user_id(authorization, get_settings())

        # Verify parent owns this child profile
        child_check = (
            supabase_client.client.table("family_profiles")
            .select("id, parent_user_id")
            .eq("id", str(child_profile_id))
            .eq("parent_user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if not child_check.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Child profile not found or access denied",
            )

        # Get family library using the function
        result = supabase_client.client.rpc(
            "get_family_story_library",
            {"p_child_profile_id": str(child_profile_id)}
        ).execute()

        return [FamilyStoryItem(**item) for item in result.data]

    return router

