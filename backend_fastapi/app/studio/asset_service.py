"""
Asset service for Studio Website.

Handles CRUD operations for custom assets (video, audio, images) uploaded by users.
"""

import logging
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, UploadFile

from ..shared.supabase_client import SupabaseClient

logger = logging.getLogger("dreamflow_studio.asset_service")


class AssetService:
    """Service for managing Studio assets."""

    def __init__(self, supabase_client: SupabaseClient):
        """Initialize asset service with Supabase client."""
        self.supabase = supabase_client

    def create_asset(
        self,
        user_id: UUID,
        asset_type: str,
        url: str,
        name: str,
        size: int,
        thumbnail_url: Optional[str] = None,
    ) -> dict[str, any]:
        """
        Create a new asset record.

        Args:
            user_id: UUID of the user
            asset_type: Type of asset ('video', 'audio', 'image')
            url: URL to the asset
            name: Name of the asset
            size: Size of the asset in bytes
            thumbnail_url: Optional thumbnail URL

        Returns:
            Created asset dictionary
        """
        if asset_type not in ("video", "audio", "image"):
            raise HTTPException(
                status_code=400, detail=f"Invalid asset type: {asset_type}"
            )

        asset_data = {
            "user_id": str(user_id),
            "type": asset_type,
            "url": url,
            "name": name,
            "size": size,
            "thumbnail_url": thumbnail_url,
        }

        try:
            response = self.supabase.client.table("assets").insert(asset_data).execute()
            return response.data[0] if response.data else asset_data
        except Exception as e:
            logger.error(f"Failed to create asset: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to create asset: {str(e)}"
            )

    def upload_asset(
        self,
        user_id: UUID,
        file: UploadFile,
        asset_type: str,
        name: Optional[str] = None,
    ) -> dict[str, any]:
        """
        Upload an asset file and create asset record.

        Args:
            user_id: UUID of the user
            file: Uploaded file
            asset_type: Type of asset ('video', 'audio', 'image')
            name: Optional name for the asset (defaults to filename)

        Returns:
            Created asset dictionary with URL
        """
        if asset_type not in ("video", "audio", "image"):
            raise HTTPException(
                status_code=400, detail=f"Invalid asset type: {asset_type}"
            )

        # Read file content
        file_content = file.file.read()
        file_size = len(file_content)

        # Determine bucket based on asset type
        bucket_map = {
            "video": "video",
            "audio": "audio",
            "image": "frames",  # Images go to frames bucket
        }
        bucket_name = bucket_map[asset_type]

        # Generate file path
        filename = (
            name
            or file.filename
            or f"asset_{UUID()}.{file.filename.split('.')[-1] if file.filename else 'bin'}"
        )
        file_path = f"{asset_type}/{filename}"

        # Upload to Supabase Storage
        try:
            self.supabase.upload_file(
                bucket_name=bucket_name,
                file_path=file_path,
                file_data=file_content,
                content_type=file.content_type,
            )

            # Get signed URL
            url = self.supabase.get_signed_url(bucket_name, file_path)

            # Generate thumbnail if image
            thumbnail_url = None
            if asset_type == "image":
                # For now, use the same URL as thumbnail
                # In production, you might want to generate a thumbnail
                thumbnail_url = url

            # Create asset record
            return self.create_asset(
                user_id=user_id,
                asset_type=asset_type,
                url=url,
                name=name or file.filename or filename,
                size=file_size,
                thumbnail_url=thumbnail_url,
            )
        except Exception as e:
            logger.error(f"Failed to upload asset: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to upload asset: {str(e)}"
            )

    def get_asset(self, asset_id: UUID, user_id: UUID) -> Optional[dict[str, any]]:
        """
        Get an asset by ID.

        Args:
            asset_id: UUID of the asset
            user_id: UUID of the user (for authorization)

        Returns:
            Asset dictionary or None if not found
        """
        try:
            response = (
                self.supabase.client.table("assets")
                .select("*")
                .eq("id", str(asset_id))
                .eq("user_id", str(user_id))
                .maybe_single()
                .execute()
            )
            return response.data if response.data else None
        except Exception as e:
            logger.error(f"Failed to get asset: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to get asset: {str(e)}"
            )

    def list_assets(
        self,
        user_id: UUID,
        page: int = 1,
        limit: int = 20,
        asset_type: Optional[str] = None,
    ) -> dict[str, any]:
        """
        List assets with pagination.

        Args:
            user_id: UUID of the user
            page: Page number (1-indexed)
            limit: Number of items per page
            asset_type: Optional filter by asset type

        Returns:
            Dictionary with assets, pagination info
        """
        offset = (page - 1) * limit

        try:
            query = (
                self.supabase.client.table("assets")
                .select("*")
                .eq("user_id", str(user_id))
            )

            if asset_type:
                query = query.eq("type", asset_type)

            query = query.order("created_at", desc=True).range(
                offset, offset + limit - 1
            )

            response = query.execute()
            assets = response.data if response.data else []

            # Get total count
            count_query = (
                self.supabase.client.table("assets")
                .select("id", count="exact")
                .eq("user_id", str(user_id))
            )
            if asset_type:
                count_query = count_query.eq("type", asset_type)

            count_response = count_query.execute()
            total = (
                count_response.count
                if hasattr(count_response, "count")
                else len(assets)
            )

            return {
                "assets": assets,
                "pagination": {
                    "page": page,
                    "limit": limit,
                    "total": total,
                    "total_pages": (total + limit - 1) // limit,
                },
            }
        except Exception as e:
            logger.error(f"Failed to list assets: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to list assets: {str(e)}"
            )

    def delete_asset(self, asset_id: UUID, user_id: UUID) -> bool:
        """
        Delete an asset.

        Args:
            asset_id: UUID of the asset
            user_id: UUID of the user (for authorization)

        Returns:
            True if deleted successfully, False otherwise
        """
        # Get asset first to get URL for storage deletion
        asset = self.get_asset(asset_id, user_id)
        if not asset:
            return False

        # Delete from storage if URL is a Supabase Storage URL
        try:
            if asset["url"].startswith("http"):
                # Parse URL to extract bucket and path
                # This is a simplified version - in production, you'd want more robust parsing
                from urllib.parse import urlparse

                parsed = urlparse(asset["url"])
                path_parts = parsed.path.split("/")

                # Try to find bucket name
                bucket_name = None
                file_path = None

                if "/object/sign/" in parsed.path or "/object/public/" in parsed.path:
                    # Extract bucket and path from Supabase Storage URL
                    if "/object/sign/" in parsed.path:
                        sign_idx = path_parts.index("sign")
                        if len(path_parts) > sign_idx + 2:
                            bucket_name = path_parts[sign_idx + 1]
                            file_path = "/".join(path_parts[sign_idx + 2 :])
                    elif "/object/public/" in parsed.path:
                        public_idx = path_parts.index("public")
                        if len(path_parts) > public_idx + 2:
                            bucket_name = path_parts[public_idx + 1]
                            file_path = "/".join(path_parts[public_idx + 2 :])

                    if bucket_name and file_path:
                        try:
                            self.supabase.delete_file(bucket_name, file_path)
                        except Exception as e:
                            logger.warning(f"Failed to delete storage file: {e}")
        except Exception as e:
            logger.warning(f"Failed to delete asset from storage: {e}")

        # Delete from database
        try:
            response = (
                self.supabase.client.table("assets")
                .delete()
                .eq("id", str(asset_id))
                .eq("user_id", str(user_id))
                .execute()
            )
            return len(response.data) > 0 if response.data else False
        except Exception as e:
            logger.error(f"Failed to delete asset: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to delete asset: {str(e)}"
            )
