from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Any, Optional
from uuid import UUID, uuid4

from ..dreamflow.schemas import StoryRequest
from ..shared.supabase_client import SupabaseClient


logger = logging.getLogger(__name__)


class BatchJobStatus(str, Enum):
    """Status of a batch job."""

    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class BatchJobItem:
    """Single item in a batch job."""

    id: UUID
    prompt: str
    theme: str
    target_length: int
    num_scenes: int
    voice: Optional[str] = None
    status: BatchJobStatus = BatchJobStatus.PENDING
    error_message: Optional[str] = None
    session_id: Optional[UUID] = None
    created_at: datetime = None
    completed_at: Optional[datetime] = None


@dataclass
class BatchJob:
    """A batch job containing multiple story generation requests."""

    id: UUID
    user_id: UUID
    items: list[BatchJobItem]
    status: BatchJobStatus
    email_notifications: bool = True
    created_at: datetime = None
    updated_at: datetime = None
    completed_at: Optional[datetime] = None


class BatchProcessor:
    """Service for processing batch story generation jobs."""

    def __init__(self, supabase_client: SupabaseClient):
        """
        Initialize BatchProcessor.

        Args:
            supabase_client: SupabaseClient for database operations
        """
        self.supabase_client = supabase_client
        self._processing_queue: asyncio.Queue = asyncio.Queue()
        self._is_processing = False

    async def create_batch_job(
        self,
        user_id: UUID,
        requests: list[StoryRequest],
        email_notifications: bool = True,
    ) -> BatchJob:
        """
        Create a new batch job from multiple story requests.

        Args:
            user_id: User ID creating the batch job
            requests: List of story generation requests
            email_notifications: Whether to send email when job completes

        Returns:
            Created BatchJob
        """
        job_id = uuid4()
        now = datetime.utcnow()

        # Create batch job items
        items = []
        for req in requests:
            item = BatchJobItem(
                id=uuid4(),
                prompt=req.prompt,
                theme=req.theme,
                target_length=req.target_length,
                num_scenes=req.num_scenes,
                voice=req.voice,
                status=BatchJobStatus.PENDING,
                created_at=now,
            )
            items.append(item)

        job = BatchJob(
            id=job_id,
            user_id=user_id,
            items=items,
            status=BatchJobStatus.PENDING,
            email_notifications=email_notifications,
            created_at=now,
            updated_at=now,
        )

        # Save to database
        await self._save_batch_job(job)

        # Queue for processing
        await self._processing_queue.put(job)

        # Start processing if not already running
        if not self._is_processing:
            asyncio.create_task(self._process_queue())

        return job

    async def get_batch_job(self, job_id: UUID, user_id: UUID) -> Optional[BatchJob]:
        """
        Get a batch job by ID.

        Args:
            job_id: Batch job ID
            user_id: User ID (for authorization)

        Returns:
            BatchJob or None if not found
        """
        # Query database
        response = (
            self.supabase_client.client.table("batch_jobs")
            .select("*")
            .eq("id", str(job_id))
            .eq("user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if not response.data:
            return None

        return self._job_from_dict(response.data)

    async def list_batch_jobs(
        self,
        user_id: UUID,
        status: Optional[BatchJobStatus] = None,
        limit: int = 20,
        offset: int = 0,
    ) -> list[BatchJob]:
        """
        List batch jobs for a user.

        Args:
            user_id: User ID
            status: Optional status filter
            limit: Maximum number of jobs to return
            offset: Number of jobs to skip

        Returns:
            List of BatchJob
        """
        query = (
            self.supabase_client.client.table("batch_jobs")
            .select("*")
            .eq("user_id", str(user_id))
            .order("created_at", desc=True)
        )

        if status:
            query = query.eq("status", status.value)

        query = query.range(offset, offset + limit - 1)
        response = query.execute()

        return [self._job_from_dict(job_data) for job_data in (response.data or [])]

    async def cancel_batch_job(self, job_id: UUID, user_id: UUID) -> bool:
        """
        Cancel a pending or processing batch job.

        Args:
            job_id: Batch job ID
            user_id: User ID (for authorization)

        Returns:
            True if cancelled, False if not found or cannot be cancelled
        """
        job = await self.get_batch_job(job_id, user_id)
        if not job:
            return False

        if job.status in (
            BatchJobStatus.COMPLETED,
            BatchJobStatus.FAILED,
            BatchJobStatus.CANCELLED,
        ):
            return False

        # Update status
        job.status = BatchJobStatus.CANCELLED
        job.updated_at = datetime.utcnow()
        await self._save_batch_job(job)

        return True

    async def _process_queue(self):
        """Process batch jobs from the queue."""
        self._is_processing = True

        try:
            while True:
                try:
                    # Get job from queue (with timeout to allow checking if queue is empty)
                    job = await asyncio.wait_for(
                        self._processing_queue.get(), timeout=1.0
                    )
                except asyncio.TimeoutError:
                    # Queue is empty, check if we should continue
                    if self._processing_queue.empty():
                        break
                    continue

                try:
                    await self._process_batch_job(job)
                except Exception as e:
                    logger.error(
                        f"Error processing batch job {job.id}: {e}", exc_info=True
                    )
                    job.status = BatchJobStatus.FAILED
                    job.updated_at = datetime.utcnow()
                    await self._save_batch_job(job)
        finally:
            self._is_processing = False

    async def _process_batch_job(self, job: BatchJob):
        """
        Process a single batch job.

        This method should be called with the actual story generation logic.
        For now, it's a placeholder that updates status.
        """
        job.status = BatchJobStatus.PROCESSING
        job.updated_at = datetime.utcnow()
        await self._save_batch_job(job)

        # TODO: Integrate with actual story generation pipeline
        # For each item in job.items:
        #   1. Generate story using StoryGenerator
        #   2. Generate assets (audio, frames, video)
        #   3. Update item status and session_id
        #   4. Save progress

        # Placeholder: mark all items as completed
        for item in job.items:
            item.status = BatchJobStatus.COMPLETED
            item.completed_at = datetime.utcnow()

        job.status = BatchJobStatus.COMPLETED
        job.completed_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        await self._save_batch_job(job)

        # Send email notification if enabled
        if job.email_notifications:
            await self._send_completion_email(job)

    async def _save_batch_job(self, job: BatchJob):
        """Save batch job to database."""
        job_data = {
            "id": str(job.id),
            "user_id": str(job.user_id),
            "status": job.status.value,
            "email_notifications": job.email_notifications,
            "items": [
                {
                    "id": str(item.id),
                    "prompt": item.prompt,
                    "theme": item.theme,
                    "target_length": item.target_length,
                    "num_scenes": item.num_scenes,
                    "voice": item.voice,
                    "status": item.status.value,
                    "error_message": item.error_message,
                    "session_id": str(item.session_id) if item.session_id else None,
                    "created_at": item.created_at.isoformat()
                    if item.created_at
                    else None,
                    "completed_at": item.completed_at.isoformat()
                    if item.completed_at
                    else None,
                }
                for item in job.items
            ],
            "created_at": job.created_at.isoformat() if job.created_at else None,
            "updated_at": job.updated_at.isoformat() if job.updated_at else None,
            "completed_at": job.completed_at.isoformat() if job.completed_at else None,
        }

        # Upsert batch job
        (self.supabase_client.client.table("batch_jobs").upsert(job_data).execute())

    def _job_from_dict(self, data: dict[str, Any]) -> BatchJob:
        """Create BatchJob from database dict."""
        items = []
        for item_data in data.get("items", []):
            item = BatchJobItem(
                id=UUID(item_data["id"]),
                prompt=item_data["prompt"],
                theme=item_data["theme"],
                target_length=item_data["target_length"],
                num_scenes=item_data["num_scenes"],
                voice=item_data.get("voice"),
                status=BatchJobStatus(item_data["status"]),
                error_message=item_data.get("error_message"),
                session_id=UUID(item_data["session_id"])
                if item_data.get("session_id")
                else None,
                created_at=datetime.fromisoformat(
                    item_data["created_at"].replace("Z", "+00:00")
                )
                if item_data.get("created_at")
                else None,
                completed_at=datetime.fromisoformat(
                    item_data["completed_at"].replace("Z", "+00:00")
                )
                if item_data.get("completed_at")
                else None,
            )
            items.append(item)

        return BatchJob(
            id=UUID(data["id"]),
            user_id=UUID(data["user_id"]),
            items=items,
            status=BatchJobStatus(data["status"]),
            email_notifications=data.get("email_notifications", True),
            created_at=datetime.fromisoformat(data["created_at"].replace("Z", "+00:00"))
            if data.get("created_at")
            else None,
            updated_at=datetime.fromisoformat(data["updated_at"].replace("Z", "+00:00"))
            if data.get("updated_at")
            else None,
            completed_at=datetime.fromisoformat(
                data["completed_at"].replace("Z", "+00:00")
            )
            if data.get("completed_at")
            else None,
        )

    async def _send_completion_email(self, job: BatchJob):
        """Send email notification when batch job completes."""
        # TODO: Implement email sending
        # This would integrate with an email service (SendGrid, AWS SES, etc.)
        logger.info(
            f"Would send completion email for batch job {job.id} to user {job.user_id}"
        )
