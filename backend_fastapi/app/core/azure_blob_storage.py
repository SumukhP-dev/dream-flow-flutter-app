"""
Azure Blob Storage integration for asset storage.

This module provides Azure Blob Storage functionality as an alternative to Supabase Storage
for storing generated assets (videos, audio, images).
"""

import logging
from typing import Optional
from io import BytesIO

logger = logging.getLogger(__name__)

# Try to import Azure Blob Storage client
try:
    from azure.storage.blob import BlobServiceClient, BlobClient, generate_container_sas, ContainerSasPermissions
    from azure.core.exceptions import AzureError
    from datetime import datetime, timedelta
    AZURE_BLOB_STORAGE_AVAILABLE = True
except ImportError:
    AZURE_BLOB_STORAGE_AVAILABLE = False
    logger.warning(
        "Azure Blob Storage SDK not installed. "
        "Install with: pip install azure-storage-blob"
    )


class AzureBlobStorageClient:
    """Client for Azure Blob Storage operations."""

    def __init__(self, connection_string: str, container_name: str = "dream-flow-assets"):
        """
        Initialize Azure Blob Storage client.

        Args:
            connection_string: Azure Storage account connection string
            container_name: Name of the blob container to use
        """
        if not AZURE_BLOB_STORAGE_AVAILABLE:
            raise ImportError(
                "Azure Blob Storage SDK not installed. "
                "Install with: pip install azure-storage-blob"
            )

        self.blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        self.container_name = container_name
        
        # Ensure container exists
        try:
            self.container_client = self.blob_service_client.get_container_client(container_name)
            if not self.container_client.exists():
                self.container_client.create_container()
                logger.info(f"Created Azure Blob Storage container: {container_name}")
        except AzureError as e:
            logger.error(f"Failed to initialize Azure Blob Storage container: {e}")
            raise

    def upload_blob(
        self,
        blob_name: str,
        data: bytes,
        content_type: Optional[str] = None,
        overwrite: bool = True,
    ) -> str:
        """
        Upload data to Azure Blob Storage.

        Args:
            blob_name: Name/path of the blob (e.g., "audio/file.mp3")
            data: Data to upload as bytes
            content_type: MIME type of the data
            overwrite: Whether to overwrite if blob exists

        Returns:
            Blob URL
        """
        if not AZURE_BLOB_STORAGE_AVAILABLE:
            logger.warning("Azure Blob Storage not available")
            return ""

        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            
            # Set content type if provided
            content_settings = None
            if content_type:
                from azure.storage.blob import ContentSettings
                content_settings = ContentSettings(content_type=content_type)
            
            blob_client.upload_blob(
                data,
                overwrite=overwrite,
                content_settings=content_settings,
            )
            
            # Return blob URL
            blob_url = blob_client.url
            logger.debug(f"Uploaded blob to Azure Storage: {blob_name}")
            return blob_url

        except AzureError as e:
            logger.error(f"Failed to upload blob to Azure Storage: {e}")
            raise

    def get_blob_url(self, blob_name: str, expires_in: int = 3600) -> str:
        """
        Get a signed URL for a blob.

        Args:
            blob_name: Name/path of the blob
            expires_in: URL expiration time in seconds (default: 1 hour)

        Returns:
            Signed URL for the blob
        """
        if not AZURE_BLOB_STORAGE_AVAILABLE:
            logger.warning("Azure Blob Storage not available")
            return ""

        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            
            # Generate SAS token
            sas_token = generate_container_sas(
                account_name=self.blob_service_client.account_name,
                container_name=self.container_name,
                account_key=self.blob_service_client.credential.account_key,
                permission=ContainerSasPermissions(read=True),
                expiry=datetime.utcnow() + timedelta(seconds=expires_in),
            )
            
            # Return blob URL with SAS token
            return f"{blob_client.url}?{sas_token}"

        except AzureError as e:
            logger.error(f"Failed to generate signed URL for blob: {e}")
            # Fallback to public URL if container is public
            blob_client = self.container_client.get_blob_client(blob_name)
            return blob_client.url

    def delete_blob(self, blob_name: str) -> bool:
        """
        Delete a blob from Azure Blob Storage.

        Args:
            blob_name: Name/path of the blob to delete

        Returns:
            True if deleted successfully, False otherwise
        """
        if not AZURE_BLOB_STORAGE_AVAILABLE:
            logger.warning("Azure Blob Storage not available")
            return False

        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            blob_client.delete_blob()
            logger.debug(f"Deleted blob from Azure Storage: {blob_name}")
            return True

        except AzureError as e:
            logger.error(f"Failed to delete blob from Azure Storage: {e}")
            return False

    def upload_audio(self, file_data: bytes, filename: str) -> str:
        """
        Upload audio file to Azure Blob Storage.

        Args:
            file_data: Audio file content as bytes
            filename: Name of the file

        Returns:
            URL to the uploaded audio file
        """
        blob_name = f"audio/{filename}"
        return self.upload_blob(blob_name, file_data, content_type="audio/wav")

    def upload_video(self, file_data: bytes, filename: str) -> str:
        """
        Upload video file to Azure Blob Storage.

        Args:
            file_data: Video file content as bytes
            filename: Name of the file

        Returns:
            URL to the uploaded video file
        """
        blob_name = f"video/{filename}"
        return self.upload_blob(blob_name, file_data, content_type="video/mp4")

    def upload_frame(self, file_data: bytes, filename: str) -> str:
        """
        Upload image/frame file to Azure Blob Storage.

        Args:
            file_data: Image file content as bytes
            filename: Name of the file

        Returns:
            URL to the uploaded frame file
        """
        blob_name = f"frames/{filename}"
        return self.upload_blob(blob_name, file_data, content_type="image/png")


def get_blob_storage_client():
    """
    Get Azure Blob Storage client instance from settings.

    Returns:
        AzureBlobStorageClient instance or None if not configured
    """
    from ..shared.config import get_settings
    
    settings = get_settings()

    if not settings.azure_blob_storage_enabled:
        return None

    connection_string = settings.azure_blob_storage_connection_string
    container_name = settings.azure_blob_storage_container_name

    if not connection_string:
        logger.warning("Azure Blob Storage connection string not configured")
        return None

    try:
        return AzureBlobStorageClient(
            connection_string=connection_string,
            container_name=container_name,
        )
    except Exception as e:
        logger.error(f"Failed to initialize Azure Blob Storage client: {e}")
        return None

