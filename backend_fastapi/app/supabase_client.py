"""
Supabase client helper for FastAPI backend.

This module provides a wrapper around supabase-py with service-role authentication
and convenient CRUD helpers for profiles, sessions, and session assets.
"""

import warnings
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from uuid import UUID

# Silence upstream warning emitted by supabase-py when importing gotrue.
warnings.filterwarnings(
    "ignore",
    message="The `gotrue` package is deprecated",
    category=DeprecationWarning,
)

from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions

from .config import Settings, get_settings


class SupabaseClient:
    """Wrapper around Supabase client with service-role authentication and CRUD helpers."""

    def __init__(self, settings: Optional[Settings] = None):
        """
        Initialize Supabase client with service-role key.

        Args:
            settings: Optional Settings instance. If not provided, will fetch from get_settings().

        Raises:
            ValueError: If Supabase configuration is missing.
        """
        if settings is None:
            settings = get_settings()

        if not settings.supabase_url:
            raise ValueError("SUPABASE_URL environment variable is required")
        if not settings.supabase_service_role_key:
            raise ValueError("SUPABASE_SERVICE_ROLE_KEY environment variable is required")

        # Use service-role key for admin access (bypasses RLS)
        self.client: Client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key,
            options=ClientOptions(
                auto_refresh_token=False,
                persist_session=False,
            ),
        )
        self.settings = settings

    # ============================================================================
    # Profile CRUD Operations
    # ============================================================================

    def get_profile(self, user_id: UUID) -> Optional[dict[str, Any]]:
        """
        Get a user's profile by user ID.

        Args:
            user_id: UUID of the user

        Returns:
            Profile dictionary or None if not found
        """
        response = (
            self.client.table("profiles")
            .select("*")
            .eq("id", str(user_id))
            .maybe_single()
            .execute()
        )
        return response.data if response.data else None

    def create_profile(
        self,
        user_id: UUID,
        mood: Optional[str] = None,
        routine: Optional[str] = None,
        preferences: Optional[list[str]] = None,
        favorite_characters: Optional[list[str]] = None,
        calming_elements: Optional[list[str]] = None,
    ) -> dict[str, Any]:
        """
        Create a new user profile.

        Args:
            user_id: UUID of the user
            mood: Current emotional tone
            routine: Bedtime routine or activity context
            preferences: General likes and interests
            favorite_characters: List of favorite characters
            calming_elements: Anchors such as sounds, locations, or colors

        Returns:
            Created profile dictionary

        Raises:
            Exception: If profile creation fails
        """
        profile_data = {
            "id": str(user_id),
            "mood": mood,
            "routine": routine,
            "preferences": preferences or [],
            "favorite_characters": favorite_characters or [],
            "calming_elements": calming_elements or [],
        }
        response = (
            self.client.table("profiles")
            .insert(profile_data)
            .execute()
        )
        return response.data[0] if response.data else profile_data

    def update_profile(
        self,
        user_id: UUID,
        mood: Optional[str] = None,
        routine: Optional[str] = None,
        preferences: Optional[list[str]] = None,
        favorite_characters: Optional[list[str]] = None,
        calming_elements: Optional[list[str]] = None,
    ) -> dict[str, Any]:
        """
        Update an existing user profile.

        Args:
            user_id: UUID of the user
            mood: Current emotional tone (optional)
            routine: Bedtime routine or activity context (optional)
            preferences: General likes and interests (optional)
            favorite_characters: List of favorite characters (optional)
            calming_elements: Anchors such as sounds, locations, or colors (optional)

        Returns:
            Updated profile dictionary

        Raises:
            Exception: If profile update fails
        """
        update_data: dict[str, Any] = {}
        if mood is not None:
            update_data["mood"] = mood
        if routine is not None:
            update_data["routine"] = routine
        if preferences is not None:
            update_data["preferences"] = preferences
        if favorite_characters is not None:
            update_data["favorite_characters"] = favorite_characters
        if calming_elements is not None:
            update_data["calming_elements"] = calming_elements

        if not update_data:
            # No updates provided, return existing profile
            return self.get_profile(user_id) or {}

        response = (
            self.client.table("profiles")
            .update(update_data)
            .eq("id", str(user_id))
            .execute()
        )
        return response.data[0] if response.data else {}

    def delete_profile(self, user_id: UUID) -> bool:
        """
        Delete a user's profile.

        Args:
            user_id: UUID of the user

        Returns:
            True if deleted successfully, False otherwise
        """
        response = (
            self.client.table("profiles")
            .delete()
            .eq("id", str(user_id))
            .execute()
        )
        return len(response.data) > 0 if response.data else False

    def upsert_profile(
        self,
        user_id: UUID,
        mood: Optional[str] = None,
        routine: Optional[str] = None,
        preferences: Optional[list[str]] = None,
        favorite_characters: Optional[list[str]] = None,
        calming_elements: Optional[list[str]] = None,
    ) -> dict[str, Any]:
        """
        Upsert (insert or update) a user profile.

        Args:
            user_id: UUID of the user
            mood: Current emotional tone
            routine: Bedtime routine or activity context
            preferences: General likes and interests
            favorite_characters: List of favorite characters
            calming_elements: Anchors such as sounds, locations, or colors

        Returns:
            Profile dictionary
        """
        profile_data = {
            "id": str(user_id),
            "mood": mood,
            "routine": routine,
            "preferences": preferences or [],
            "favorite_characters": favorite_characters or [],
            "calming_elements": calming_elements or [],
        }
        response = (
            self.client.table("profiles")
            .upsert(profile_data)
            .execute()
        )
        return response.data[0] if response.data else profile_data

    # ============================================================================
    # Session CRUD Operations
    # ============================================================================

    def get_session(self, session_id: UUID) -> Optional[dict[str, Any]]:
        """
        Get a session by session ID.

        Args:
            session_id: UUID of the session

        Returns:
            Session dictionary or None if not found
        """
        query = (
            self.client.table("sessions")
            .select("*")
            .eq("id", str(session_id))
        )
        response = query.single().execute()
        if not response.data:
            return None
        if isinstance(response.data, list):
            return response.data[0]
        return response.data

    def get_user_sessions(
        self,
        user_id: UUID,
        limit: Optional[int] = None,
        offset: int = 0,
        order_by: str = "created_at",
        ascending: bool = False,
    ) -> list[dict[str, Any]]:
        """
        Get all sessions for a user.

        Args:
            user_id: UUID of the user
            limit: Maximum number of sessions to return
            offset: Number of sessions to skip
            order_by: Column to order by (default: created_at)
            ascending: Whether to order ascending (default: False, newest first)

        Returns:
            List of session dictionaries
        """
        query = (
            self.client.table("sessions")
            .select("*")
            .eq("user_id", str(user_id))
            .order(order_by, desc=not ascending)
        )
        # Apply pagination: use a large number if limit is None to get all records
        end = (offset + limit - 1) if limit is not None else (offset + 9999)
        query = query.range(offset, end)
        response = query.execute()
        return response.data if response.data else []

    def create_session(
        self,
        user_id: UUID,
        prompt: str,
        theme: str,
        story_text: str,
        target_length: int = 400,
        num_scenes: int = 4,
        voice: Optional[str] = None,
    ) -> dict[str, Any]:
        """
        Create a new session.

        Args:
            user_id: UUID of the user
            prompt: Seed prompt from the user
            theme: Theme that shapes narrative, visuals, and narration
            story_text: Generated story text
            target_length: Approximate number of words for the story
            num_scenes: Number of visual scenes generated
            voice: Voice preset for narration if supported

        Returns:
            Created session dictionary

        Raises:
            Exception: If session creation fails
        """
        session_data = {
            "user_id": str(user_id),
            "prompt": prompt,
            "theme": theme,
            "story_text": story_text,
            "target_length": target_length,
            "num_scenes": num_scenes,
            "voice": voice,
        }
        response = (
            self.client.table("sessions")
            .insert(session_data)
            .execute()
        )
        return response.data[0] if response.data else session_data

    def update_session(
        self,
        session_id: UUID,
        prompt: Optional[str] = None,
        theme: Optional[str] = None,
        story_text: Optional[str] = None,
        target_length: Optional[int] = None,
        num_scenes: Optional[int] = None,
        voice: Optional[str] = None,
    ) -> dict[str, Any]:
        """
        Update an existing session.

        Args:
            session_id: UUID of the session
            prompt: Seed prompt from the user (optional)
            theme: Theme that shapes narrative, visuals, and narration (optional)
            story_text: Generated story text (optional)
            target_length: Approximate number of words for the story (optional)
            num_scenes: Number of visual scenes generated (optional)
            voice: Voice preset for narration if supported (optional)

        Returns:
            Updated session dictionary

        Raises:
            Exception: If session update fails
        """
        update_data: dict[str, Any] = {}
        if prompt is not None:
            update_data["prompt"] = prompt
        if theme is not None:
            update_data["theme"] = theme
        if story_text is not None:
            update_data["story_text"] = story_text
        if target_length is not None:
            update_data["target_length"] = target_length
        if num_scenes is not None:
            update_data["num_scenes"] = num_scenes
        if voice is not None:
            update_data["voice"] = voice

        if not update_data:
            # No updates provided, return existing session
            return self.get_session(session_id) or {}

        response = (
            self.client.table("sessions")
            .update(update_data)
            .eq("id", str(session_id))
            .execute()
        )
        return response.data[0] if response.data else {}

    def delete_session(self, session_id: UUID) -> bool:
        """
        Delete a session (cascades to session_assets).

        Args:
            session_id: UUID of the session

        Returns:
            True if deleted successfully, False otherwise
        """
        response = (
            self.client.table("sessions")
            .delete()
            .eq("id", str(session_id))
            .execute()
        )
        return len(response.data) > 0 if response.data else False

    # ============================================================================
    # Session Assets CRUD Operations
    # ============================================================================

    def get_session_assets(
        self,
        session_id: UUID,
        asset_type: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        """
        Get all assets for a session.

        Args:
            session_id: UUID of the session
            asset_type: Optional filter by asset type ('audio', 'video', 'frame')

        Returns:
            List of asset dictionaries
        """
        query = (
            self.client.table("session_assets")
            .select("*")
            .eq("session_id", str(session_id))
            .order("display_order")
        )
        if asset_type:
            query = query.eq("asset_type", asset_type)

        response = query.execute()
        return response.data if response.data else []

    def create_session_asset(
        self,
        session_id: UUID,
        asset_type: str,
        asset_url: str,
        display_order: int = 0,
    ) -> dict[str, Any]:
        """
        Create a new session asset.

        Args:
            session_id: UUID of the session
            asset_type: Type of asset ('audio', 'video', 'frame')
            asset_url: URL or path to the asset
            display_order: Order for display (default: 0)

        Returns:
            Created asset dictionary

        Raises:
            ValueError: If asset_type is not valid
            Exception: If asset creation fails
        """
        if asset_type not in ("audio", "video", "frame"):
            raise ValueError(f"asset_type must be 'audio', 'video', or 'frame', got '{asset_type}'")

        asset_data = {
            "session_id": str(session_id),
            "asset_type": asset_type,
            "asset_url": asset_url,
            "display_order": display_order,
        }
        response = (
            self.client.table("session_assets")
            .insert(asset_data)
            .execute()
        )
        return response.data[0] if response.data else asset_data

    def create_session_assets_batch(
        self,
        session_id: UUID,
        assets: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        """
        Create multiple session assets in a single batch operation.

        Args:
            session_id: UUID of the session
            assets: List of asset dictionaries with keys: asset_type, asset_url, display_order

        Returns:
            List of created asset dictionaries

        Raises:
            Exception: If asset creation fails
        """
        asset_data = [
            {
                "session_id": str(session_id),
                "asset_type": asset["asset_type"],
                "asset_url": asset["asset_url"],
                "display_order": asset.get("display_order", 0),
            }
            for asset in assets
        ]
        response = (
            self.client.table("session_assets")
            .insert(asset_data)
            .execute()
        )
        return response.data if response.data else []

    def delete_session_asset(self, asset_id: UUID) -> bool:
        """
        Delete a session asset.

        Args:
            asset_id: UUID of the asset

        Returns:
            True if deleted successfully, False otherwise
        """
        response = (
            self.client.table("session_assets")
            .delete()
            .eq("id", str(asset_id))
            .execute()
        )
        return len(response.data) > 0 if response.data else False

    def delete_session_assets(self, session_id: UUID, asset_type: Optional[str] = None) -> int:
        """
        Delete all assets for a session, optionally filtered by type.

        Args:
            session_id: UUID of the session
            asset_type: Optional filter by asset type ('audio', 'video', 'frame')

        Returns:
            Number of assets deleted
        """
        query = (
            self.client.table("session_assets")
            .delete()
            .eq("session_id", str(session_id))
        )
        if asset_type:
            query = query.eq("asset_type", asset_type)

        response = query.execute()
        return len(response.data) if response.data else 0

    # ============================================================================
    # Storage Operations
    # ============================================================================

    def upload_file(
        self,
        bucket_name: str,
        file_path: str,
        file_data: bytes,
        content_type: Optional[str] = None,
        upsert: bool = True,
    ) -> str:
        """
        Upload a file to Supabase Storage.

        Args:
            bucket_name: Name of the storage bucket
            file_path: Path within the bucket (e.g., "audio/file.wav")
            file_data: File content as bytes
            content_type: MIME type of the file (optional)
            upsert: Whether to overwrite if file exists (default: True)

        Returns:
            Path to the uploaded file in storage

        Raises:
            Exception: If upload fails
        """
        storage = self.client.storage.from_(bucket_name)
        
        # Upload file
        options: dict[str, Any] = {"upsert": upsert}
        if content_type:
            options["content_type"] = content_type
        
        response = storage.upload(file_path, file_data, file_options=options)
        
        # Handle response - could be dict with error or response object with error attribute
        if hasattr(response, "error") and response.error:
            raise Exception(f"Failed to upload file to {bucket_name}/{file_path}: {response.error}")
        elif isinstance(response, dict) and response.get("error"):
            raise Exception(f"Failed to upload file to {bucket_name}/{file_path}: {response['error']}")
        
        return file_path

    def get_signed_url(
        self,
        bucket_name: str,
        file_path: str,
        expires_in: int = 3600,
    ) -> str:
        """
        Get a signed URL for a file in Supabase Storage.

        Args:
            bucket_name: Name of the storage bucket
            file_path: Path to the file within the bucket
            expires_in: Expiration time in seconds (default: 3600 = 1 hour)

        Returns:
            Signed URL string

        Raises:
            Exception: If URL generation fails
        """
        storage = self.client.storage.from_(bucket_name)
        response = storage.create_signed_url(file_path, expires_in)
        
        # Handle response - could be dict with error/data or response object
        if hasattr(response, "error") and response.error:
            raise Exception(f"Failed to create signed URL for {bucket_name}/{file_path}: {response.error}")
        elif isinstance(response, dict) and response.get("error"):
            raise Exception(f"Failed to create signed URL for {bucket_name}/{file_path}: {response['error']}")
        
        # Extract signed URL from response
        if hasattr(response, "data") and isinstance(response.data, dict):
            return response.data.get("signedURL", "")
        elif isinstance(response, dict):
            return response.get("signedURL", response.get("data", {}).get("signedURL", ""))
        elif isinstance(response, str):
            return response
        
        raise Exception(f"Unexpected response format from create_signed_url: {type(response)}")

    def upload_audio(self, file_data: bytes, filename: str) -> str:
        """
        Upload an audio file to the 'audio' bucket and return a signed URL.

        Args:
            file_data: Audio file content as bytes
            filename: Name of the file (will be stored as audio/{filename})

        Returns:
            Signed URL for the uploaded audio file
        """
        file_path = f"audio/{filename}"
        self.upload_file("audio", file_path, file_data, content_type="audio/wav")
        return self.get_signed_url("audio", file_path)

    def upload_video(self, file_data: bytes, filename: str) -> str:
        """
        Upload a video file to the 'video' bucket and return a signed URL.

        Args:
            file_data: Video file content as bytes
            filename: Name of the file (will be stored as video/{filename})

        Returns:
            Signed URL for the uploaded video file
        """
        file_path = f"video/{filename}"
        self.upload_file("video", file_path, file_data, content_type="video/mp4")
        return self.get_signed_url("video", file_path)

    def upload_frame(self, file_data: bytes, filename: str) -> str:
        """
        Upload a frame/image file to the 'frames' bucket and return a signed URL.

        Args:
            file_data: Image file content as bytes
            filename: Name of the file (will be stored as frames/{filename})

        Returns:
            Signed URL for the uploaded frame file
        """
        file_path = f"frames/{filename}"
        self.upload_file("frames", file_path, file_data, content_type="image/png")
        return self.get_signed_url("frames", file_path)

    def delete_file(
        self,
        bucket_name: str,
        file_path: str,
    ) -> bool:
        """
        Delete a file from Supabase Storage.

        Args:
            bucket_name: Name of the storage bucket
            file_path: Path to the file within the bucket

        Returns:
            True if deleted successfully, False otherwise

        Raises:
            Exception: If deletion fails
        """
        storage = self.client.storage.from_(bucket_name)
        response = storage.remove([file_path])
        
        # Handle response - could be dict with error/data or response object
        if hasattr(response, "error") and response.error:
            raise Exception(f"Failed to delete file from {bucket_name}/{file_path}: {response.error}")
        elif isinstance(response, dict) and response.get("error"):
            raise Exception(f"Failed to delete file from {bucket_name}/{file_path}: {response['error']}")
        
        return True

    def get_expired_session_assets(
        self,
        days_old: int = 7,
        limit: Optional[int] = None,
    ) -> list[dict[str, Any]]:
        """
        Get session assets older than the specified number of days.

        Args:
            days_old: Number of days after which assets are considered expired (default: 7)
            limit: Maximum number of assets to return (None for all)

        Returns:
            List of expired asset dictionaries
        """
        cutoff_date = datetime.now(timezone.utc) - timedelta(days=days_old)
        
        query = (
            self.client.table("session_assets")
            .select("*")
            .lt("created_at", cutoff_date.isoformat())
            .order("created_at", desc=False)
        )
        
        if limit is not None:
            query = query.limit(limit)
        
        response = query.execute()
        return response.data if response.data else []

    def purge_expired_assets(
        self,
        days_old: int = 7,
        batch_size: int = 100,
    ) -> dict[str, Any]:
        """
        Purge expired media assets by deleting storage files and database rows.

        This method:
        1. Finds assets older than the specified number of days
        2. Deletes the storage files from Supabase Storage buckets
        3. Deletes the database rows

        Args:
            days_old: Number of days after which assets are considered expired (default: 7)
            batch_size: Number of assets to process in each batch (default: 100)

        Returns:
            Dictionary with purge statistics:
            {
                "assets_found": int,
                "assets_deleted": int,
                "storage_deleted": int,
                "storage_errors": int,
                "errors": list[str]
            }
        """
        import re
        from urllib.parse import urlparse
        
        stats = {
            "assets_found": 0,
            "assets_deleted": 0,
            "storage_deleted": 0,
            "storage_errors": 0,
            "errors": [],
        }
        
        # Get expired assets in batches
        offset = 0
        while True:
            # Get a batch of expired assets
            cutoff_date = datetime.now(timezone.utc) - timedelta(days=days_old)
            query = (
                self.client.table("session_assets")
                .select("*")
                .lt("created_at", cutoff_date.isoformat())
                .order("created_at", desc=False)
                .range(offset, offset + batch_size - 1)
            )
            
            response = query.execute()
            assets = response.data if response.data else []
            
            if not assets:
                break
            
            stats["assets_found"] += len(assets)
            
            # Process each asset
            for asset in assets:
                asset_id = asset["id"]
                asset_url = asset["asset_url"]
                asset_type = asset["asset_type"]
                
                # Try to delete storage file if it's a Supabase Storage URL
                if asset_url.startswith("http"):
                    try:
                        # Parse the URL to extract bucket and file path
                        # Supabase Storage URLs typically look like:
                        # https://<project>.supabase.co/storage/v1/object/sign/<bucket>/<path>?token=...
                        # or https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
                        parsed = urlparse(asset_url)
                        path_parts = parsed.path.split("/")
                        
                        # Try to find bucket name and file path
                        bucket_name = None
                        file_path = None
                        
                        # Check for signed URL pattern: /storage/v1/object/sign/<bucket>/<path>
                        if "/object/sign/" in parsed.path:
                            sign_idx = path_parts.index("sign")
                            if len(path_parts) > sign_idx + 2:
                                bucket_name = path_parts[sign_idx + 1]
                                file_path = "/".join(path_parts[sign_idx + 2:])
                        # Check for public URL pattern: /storage/v1/object/public/<bucket>/<path>
                        elif "/object/public/" in parsed.path:
                            public_idx = path_parts.index("public")
                            if len(path_parts) > public_idx + 2:
                                bucket_name = path_parts[public_idx + 1]
                                file_path = "/".join(path_parts[public_idx + 2:])
                        
                        # If we couldn't parse the URL, try to infer from asset_type
                        if not bucket_name or not file_path:
                            # Map asset_type to bucket name (buckets are: audio, video, frames)
                            bucket_map = {
                                "audio": "audio",
                                "video": "video",
                                "frame": "frames",  # Note: bucket is "frames" not "frame"
                            }
                            bucket_name = bucket_map.get(asset_type)
                            if not bucket_name:
                                raise Exception(f"Unknown asset_type: {asset_type}")
                            
                            # Try to extract filename from URL
                            if "/" in parsed.path:
                                file_path = parsed.path.split("/")[-1].split("?")[0]
                                # Prepend the asset_type folder if it's not already there
                                # For frames bucket, the folder is "frames", not "frame"
                                folder_name = asset_type if asset_type != "frame" else "frames"
                                if not file_path.startswith(f"{folder_name}/"):
                                    file_path = f"{folder_name}/{file_path}"
                            else:
                                # Can't determine file path, skip storage deletion
                                raise Exception(f"Could not parse file path from URL: {asset_url}")
                        
                        # Delete from storage
                        self.delete_file(bucket_name, file_path)
                        stats["storage_deleted"] += 1
                    except Exception as e:
                        # Log error but continue with database deletion
                        error_msg = f"Failed to delete storage for asset {asset_id}: {str(e)}"
                        stats["errors"].append(error_msg)
                        stats["storage_errors"] += 1
                
                # Delete database row
                try:
                    self.delete_session_asset(UUID(asset_id))
                    stats["assets_deleted"] += 1
                except Exception as e:
                    error_msg = f"Failed to delete database row for asset {asset_id}: {str(e)}"
                    stats["errors"].append(error_msg)
            
            # Check if there are more assets to process
            if len(assets) < batch_size:
                break
            
            offset += batch_size
        
        return stats

    # ============================================================================
    # Session Feedback CRUD Operations
    # ============================================================================

    def create_feedback(
        self,
        session_id: UUID,
        user_id: UUID,
        rating: int,
        mood_delta: int,
    ) -> dict[str, Any]:
        """
        Create or update feedback for a session.

        Args:
            session_id: UUID of the session
            user_id: UUID of the user
            rating: Rating from 1 to 5
            mood_delta: Mood change from -5 to 5

        Returns:
            Created or updated feedback dictionary

        Raises:
            Exception: If feedback creation fails
        """
        feedback_data = {
            "session_id": str(session_id),
            "user_id": str(user_id),
            "rating": rating,
            "mood_delta": mood_delta,
        }
        # Use upsert to handle the unique constraint on session_id
        response = (
            self.client.table("session_feedback")
            .upsert(feedback_data, on_conflict="session_id")
            .execute()
        )
        return response.data[0] if response.data else feedback_data

    def get_feedback(self, session_id: UUID) -> Optional[dict[str, Any]]:
        """
        Get feedback for a session.

        Args:
            session_id: UUID of the session

        Returns:
            Feedback dictionary or None if not found
        """
        response = (
            self.client.table("session_feedback")
            .select("*")
            .eq("session_id", str(session_id))
            .maybe_single()
            .execute()
        )
        return response.data if response.data else None

    # ============================================================================
    # Moderation Queue CRUD Operations
    # ============================================================================

    def create_moderation_item(
        self,
        violations: list[dict[str, Any]],
        content: str,
        content_type: str,
        user_id: Optional[UUID] = None,
        session_id: Optional[UUID] = None,
    ) -> dict[str, Any]:
        """
        Create a new moderation queue item.

        Args:
            violations: List of violation dictionaries with 'category' and 'detail'
            content: The content that violated guardrails
            content_type: Type of content ('story', 'prompt', 'narration', 'visual')
            user_id: Optional UUID of the user who generated the content
            session_id: Optional UUID of the session

        Returns:
            Created moderation queue item dictionary
        """
        moderation_data = {
            "violations": violations,
            "content": content,
            "content_type": content_type,
            "status": "pending",
            "audit_log": [],
        }
        if user_id:
            moderation_data["user_id"] = str(user_id)
        if session_id:
            moderation_data["session_id"] = str(session_id)

        response = (
            self.client.table("moderation_queue")
            .insert(moderation_data)
            .execute()
        )
        return response.data[0] if response.data else moderation_data

    def get_moderation_items(
        self,
        status: Optional[str] = None,
        content_type: Optional[str] = None,
        limit: Optional[int] = None,
        offset: int = 0,
        order_by: str = "created_at",
        ascending: bool = False,
    ) -> list[dict[str, Any]]:
        """
        Get moderation queue items with optional filters.

        Args:
            status: Optional filter by status ('pending', 'resolved', 'rejected')
            content_type: Optional filter by content type
            limit: Maximum number of items to return
            offset: Number of items to skip
            order_by: Column to order by (default: created_at)
            ascending: Whether to order ascending (default: False, newest first)

        Returns:
            List of moderation queue item dictionaries
        """
        query = self.client.table("moderation_queue").select("*")
        
        if status:
            query = query.eq("status", status)
        if content_type:
            query = query.eq("content_type", content_type)
        
        query = query.order(order_by, desc=not ascending)
        
        # Apply pagination
        if limit is not None:
            end = offset + limit - 1
            query = query.range(offset, end)
        else:
            end = offset + 9999
            query = query.range(offset, end)
        
        response = query.execute()
        return response.data if response.data else []

    def get_moderation_item(self, item_id: UUID) -> Optional[dict[str, Any]]:
        """
        Get a moderation queue item by ID.

        Args:
            item_id: UUID of the moderation queue item

        Returns:
            Moderation queue item dictionary or None if not found
        """
        response = (
            self.client.table("moderation_queue")
            .select("*")
            .eq("id", str(item_id))
            .maybe_single()
            .execute()
        )
        return response.data if response.data else None

    def resolve_moderation_item(
        self,
        item_id: UUID,
        resolved_by: UUID,
        resolution: str,
        notes: Optional[str] = None,
    ) -> dict[str, Any]:
        """
        Resolve a moderation queue item.

        Args:
            item_id: UUID of the moderation queue item
            resolved_by: UUID of the admin resolving the item
            resolution: Resolution status ('resolved' or 'rejected')
            notes: Optional notes about the resolution

        Returns:
            Updated moderation queue item dictionary

        Raises:
            ValueError: If resolution is not 'resolved' or 'rejected'
        """
        if resolution not in ("resolved", "rejected"):
            raise ValueError(f"resolution must be 'resolved' or 'rejected', got '{resolution}'")

        # Get existing item to update audit log
        existing = self.get_moderation_item(item_id)
        if not existing:
            raise ValueError(f"Moderation item {item_id} not found")

        # Update audit log
        audit_log = existing.get("audit_log", [])
        audit_log.append({
            "action": "resolved",
            "resolved_by": str(resolved_by),
            "resolution": resolution,
            "notes": notes,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

        update_data = {
            "status": resolution,
            "resolved_by": str(resolved_by),
            "resolved_at": datetime.now(timezone.utc).isoformat(),
            "resolution_notes": notes,
            "audit_log": audit_log,
        }

        response = (
            self.client.table("moderation_queue")
            .update(update_data)
            .eq("id", str(item_id))
            .execute()
        )
        return response.data[0] if response.data else {}


# ============================================================================
# Dependency Injection Helper
# ============================================================================

def get_supabase_client(settings: Optional[Settings] = None) -> SupabaseClient:
    """
    Get a SupabaseClient instance (useful for FastAPI dependency injection).

    Args:
        settings: Optional Settings instance. If not provided, will fetch from get_settings().

    Returns:
        SupabaseClient instance
    """
    return SupabaseClient(settings)

