from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from typing import Any, Optional


@dataclass
class StoryJob:
    """
    Represents a queued story generation job.

    The payload is stored as a plain dict so we don't introduce a hard
    dependency on Pydantic models here; the route can reconstruct
    StoryRequest/StoryResponse as needed.
    """

    id: str
    user_id: Optional[str]
    tier: str  # "paid" or "free"
    payload: dict[str, Any]
    created_at: float = field(default_factory=lambda: time.time())
    status: str = "queued"  # queued | processing | completed | failed
    result: Optional[dict[str, Any]] = None
    error: Optional[str] = None


class PriorityJobQueue:
    """
    Simple in-memory priority queue for story jobs.

    - Paid jobs are always dequeued before free jobs.
    - Within each tier, jobs are processed FIFO by creation time.
    - Designed for a single-process deployment (your 8GB laptop).
    """

    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._not_empty = asyncio.Condition(self._lock)
        self._jobs_by_id: dict[str, StoryJob] = {}
        self._paid_queue: list[str] = []
        self._free_queue: list[str] = []

    async def enqueue(self, job: StoryJob) -> str:
        async with self._lock:
            self._jobs_by_id[job.id] = job
            if job.tier == "paid":
                self._paid_queue.append(job.id)
            else:
                self._free_queue.append(job.id)
            self._not_empty.notify()
            return job.id

    async def dequeue(self) -> StoryJob:
        async with self._not_empty:
            while not self._paid_queue and not self._free_queue:
                await self._not_empty.wait()

            if self._paid_queue:
                job_id = self._paid_queue.pop(0)
            else:
                job_id = self._free_queue.pop(0)

            job = self._jobs_by_id[job_id]
            job.status = "processing"
            return job

    async def update(self, job: StoryJob) -> None:
        async with self._lock:
            self._jobs_by_id[job.id] = job

    async def get(self, job_id: str) -> Optional[StoryJob]:
        async with self._lock:
            return self._jobs_by_id.get(job_id)

    async def queue_position(self, job_id: str) -> Optional[int]:
        """
        Return the 0-based position of a job in the overall queue
        (paid jobs first, then free). None if not queued.
        """
        async with self._lock:
            if job_id in self._paid_queue:
                return self._paid_queue.index(job_id)
            if job_id in self._free_queue:
                return len(self._paid_queue) + self._free_queue.index(job_id)
            return None

    async def queued_count(self) -> int:
        async with self._lock:
            return len(self._paid_queue) + len(self._free_queue)


# Global in-memory queue instance
queue = PriorityJobQueue()


