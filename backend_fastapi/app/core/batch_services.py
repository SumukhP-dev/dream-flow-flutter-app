"""
Batch processing services for content generation.

This module provides optimized batch processing for generating multiple
stories sequentially with higher quality settings.
"""

from __future__ import annotations

import asyncio
import json
import os
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Optional

from ..shared.config import get_settings
from .prompting import PromptBuilder, PromptContext, PromptBuilderMode
from .guardrails import PromptSanitizer
from .local_services import (
    LocalStoryGenerator,
    LocalNarrationGenerator,
    LocalVisualGenerator,
)

settings = get_settings()


class BatchJobStatus(str, Enum):
    """Status of a batch job."""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class BatchQuality(str, Enum):
    """Quality presets for batch processing."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


# Quality preset configurations
QUALITY_PRESETS = {
    BatchQuality.LOW: {
        "max_tokens": 512,
        "num_scenes": 3,
        "temperature": 0.9,
    },
    BatchQuality.MEDIUM: {
        "max_tokens": 768,
        "num_scenes": 4,
        "temperature": 0.85,
    },
    BatchQuality.HIGH: {
        "max_tokens": 1024,
        "num_scenes": 5,
        "temperature": 0.8,
    },
}


@dataclass
class BatchJob:
    """Represents a single batch job for story generation."""
    
    id: str
    prompt: str
    theme: str
    status: BatchJobStatus = BatchJobStatus.PENDING
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    error: Optional[str] = None
    result: Optional[dict] = None
    
    # Content metadata
    title: Optional[str] = None
    description: Optional[str] = None
    tags: list[str] = field(default_factory=list)
    
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "prompt": self.prompt,
            "theme": self.theme,
            "status": self.status.value,
            "created_at": self.created_at,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "error": self.error,
            "result": self.result,
            "title": self.title,
            "description": self.description,
            "tags": self.tags,
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> "BatchJob":
        return cls(
            id=data["id"],
            prompt=data["prompt"],
            theme=data["theme"],
            status=BatchJobStatus(data.get("status", "pending")),
            created_at=data.get("created_at", datetime.utcnow().isoformat()),
            started_at=data.get("started_at"),
            completed_at=data.get("completed_at"),
            error=data.get("error"),
            result=data.get("result"),
            title=data.get("title"),
            description=data.get("description"),
            tags=data.get("tags", []),
        )


@dataclass
class BatchProgress:
    """Tracks progress of batch processing."""
    
    total_jobs: int
    completed_jobs: int = 0
    failed_jobs: int = 0
    current_job_id: Optional[str] = None
    start_time: Optional[str] = None
    estimated_completion: Optional[str] = None
    
    @property
    def progress_percent(self) -> float:
        if self.total_jobs == 0:
            return 100.0
        return (self.completed_jobs / self.total_jobs) * 100
    
    @property
    def remaining_jobs(self) -> int:
        return self.total_jobs - self.completed_jobs - self.failed_jobs
    
    def to_dict(self) -> dict:
        return {
            "total_jobs": self.total_jobs,
            "completed_jobs": self.completed_jobs,
            "failed_jobs": self.failed_jobs,
            "current_job_id": self.current_job_id,
            "progress_percent": self.progress_percent,
            "remaining_jobs": self.remaining_jobs,
            "start_time": self.start_time,
            "estimated_completion": self.estimated_completion,
        }


class BatchStoryProcessor:
    """
    Processes multiple story generation jobs sequentially.
    
    Optimized for batch processing with:
    - Progress tracking and checkpointing
    - Resume capability
    - Memory-efficient sequential processing
    - Higher quality settings for content generation
    """
    
    def __init__(
        self,
        quality: BatchQuality = BatchQuality.HIGH,
        queue_path: Optional[Path] = None,
    ):
        self.quality = quality
        self.quality_config = QUALITY_PRESETS[quality]
        self.queue_path = queue_path or Path(settings.batch_queue_path)
        self.queue_path.mkdir(parents=True, exist_ok=True)
        
        # Initialize generators
        self.prompt_builder = PromptBuilder(mode=PromptBuilderMode.BEDTIME_STORY)
        self.story_generator = LocalStoryGenerator(prompt_builder=self.prompt_builder)
        self.narration_generator = LocalNarrationGenerator(prompt_builder=self.prompt_builder)
        self.visual_generator = LocalVisualGenerator(prompt_builder=self.prompt_builder)
        
        # Job queue and progress
        self.jobs: list[BatchJob] = []
        self.progress = BatchProgress(total_jobs=0)
        
        # Checkpoint file
        self.checkpoint_file = self.queue_path / "checkpoint.json"
    
    def add_job(
        self,
        prompt: str,
        theme: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        tags: Optional[list[str]] = None,
    ) -> BatchJob:
        """Add a new job to the queue."""
        job = BatchJob(
            id=str(uuid.uuid4()),
            prompt=prompt,
            theme=theme,
            title=title,
            description=description,
            tags=tags or [],
        )
        self.jobs.append(job)
        self.progress.total_jobs = len(self.jobs)
        self._save_checkpoint()
        return job
    
    def add_jobs_from_presets(self, count: int) -> list[BatchJob]:
        """Add multiple jobs using predefined story presets."""
        from .prompting import PromptBuilder
        
        builder = PromptBuilder()
        themes = builder.get_all_themes()
        
        if not themes:
            # Fallback themes if none configured
            themes = [
                {"title": "Starlight Dreams", "prompt": "A journey through the stars"},
                {"title": "Forest Friends", "prompt": "Woodland creatures having an adventure"},
                {"title": "Ocean Lullaby", "prompt": "Gentle waves and sea creatures"},
                {"title": "Cloud Kingdom", "prompt": "Floating on fluffy clouds"},
                {"title": "Moonbeam Magic", "prompt": "Magical moonlight adventure"},
            ]
        
        jobs = []
        for i in range(count):
            theme_data = themes[i % len(themes)]
            title = theme_data.get("title", f"Dream Story {i + 1}")
            prompt = theme_data.get("prompt", theme_data.get("description", title))
            
            job = self.add_job(
                prompt=prompt,
                theme=title,
                title=f"{title} | Dream Flow Bedtime Story",
                description=self._generate_description(title, prompt),
                tags=self._generate_tags(title),
            )
            jobs.append(job)
        
        return jobs
    
    def _generate_description(self, title: str, prompt: str) -> str:
        """Generate content description."""
        return f"""🌙 {title} - A Soothing Bedtime Story for Kids

{prompt}

This gentle bedtime story is designed to help children relax and drift off to sleep with calming narration and soft visuals.

✨ Features:
• Soothing narration
• Gentle background imagery
• Perfect for bedtime routine
• Safe, age-appropriate content

#BedtimeStory #KidsStories #SleepStories #DreamFlow #ChildrensSleep #RelaxingStories
"""
    
    def _generate_tags(self, title: str) -> list[str]:
        """Generate content tags."""
        base_tags = [
            "bedtime story",
            "kids stories",
            "sleep stories",
            "children's stories",
            "relaxing stories",
            "dream flow",
            "bedtime routine",
            "kids sleep",
            "calming stories",
            "gentle stories",
        ]
        
        # Add title-specific tags
        title_words = title.lower().split()
        title_tags = [word for word in title_words if len(word) > 3]
        
        return base_tags + title_tags[:5]
    
    async def process_job(self, job: BatchJob) -> BatchJob:
        """Process a single batch job."""
        job.status = BatchJobStatus.IN_PROGRESS
        job.started_at = datetime.utcnow().isoformat()
        self.progress.current_job_id = job.id
        self._save_checkpoint()
        
        try:
            print(f"\n{'='*60}")
            print(f"Processing Job: {job.id}")
            print(f"Theme: {job.theme}")
            print(f"Prompt: {job.prompt[:50]}...")
            print(f"{'='*60}")
            
            # Create context
            from ..dreamflow.schemas import UserProfile
            
            context = PromptContext(
                prompt=job.prompt,
                theme=job.theme,
                target_length=self.quality_config["max_tokens"],
                profile=UserProfile(
                    mood="Sleepy and peaceful",
                    routine="Bedtime story time",
                    preferences=["gentle adventures", "nature", "friendship"],
                    favorite_characters=[],
                    calming_elements=["soft light", "quiet sounds", "cozy warmth"],
                ),
            )
            
            # Generate story
            print("  [1/4] Generating story...")
            story = await self.story_generator.generate(context)
            print(f"  Story generated: {len(story)} characters")
            
            # Generate narration
            print("  [2/4] Generating narration...")
            audio_path = await self.narration_generator.synthesize(
                story=story,
                context=context,
                voice=None,  # Use default voice
            )
            print(f"  Audio saved: {audio_path}")
            
            # Update job with results
            job.status = BatchJobStatus.COMPLETED
            job.completed_at = datetime.utcnow().isoformat()
            job.result = {
                "story_text": story,
                "audio_path": audio_path,
                "video_path": video_path,
            }
            
            self.progress.completed_jobs += 1
            print(f"\n✓ Job completed successfully!")
            
        except Exception as e:
            job.status = BatchJobStatus.FAILED
            job.completed_at = datetime.utcnow().isoformat()
            job.error = str(e)
            self.progress.failed_jobs += 1
            print(f"\n✗ Job failed: {e}")
        
        finally:
            self.progress.current_job_id = None
            self._save_checkpoint()
        
        return job
    
    async def process_all(self, resume: bool = False) -> list[BatchJob]:
        """Process all jobs in the queue."""
        if resume:
            self._load_checkpoint()
        
        self.progress.start_time = datetime.utcnow().isoformat()
        
        print(f"\n{'#'*60}")
        print(f"# Starting Batch Processing")
        print(f"# Total Jobs: {len(self.jobs)}")
        print(f"# Quality: {self.quality.value}")
        print(f"# Max Tokens: {self.quality_config['max_tokens']}")
        print(f"{'#'*60}\n")
        
        pending_jobs = [j for j in self.jobs if j.status == BatchJobStatus.PENDING]
        
        for i, job in enumerate(pending_jobs):
            print(f"\n[{i + 1}/{len(pending_jobs)}] Processing job...")
            await self.process_job(job)
            
            # Brief pause between jobs to prevent memory issues
            if i < len(pending_jobs) - 1:
                print("  Pausing before next job...")
                await asyncio.sleep(2)
        
        # Final summary
        print(f"\n{'#'*60}")
        print(f"# Batch Processing Complete!")
        print(f"# Completed: {self.progress.completed_jobs}")
        print(f"# Failed: {self.progress.failed_jobs}")
        print(f"# Total Time: {self._calculate_elapsed_time()}")
        print(f"{'#'*60}\n")
        
        return self.jobs
    
    def _calculate_elapsed_time(self) -> str:
        """Calculate elapsed time since start."""
        if not self.progress.start_time:
            return "N/A"
        
        start = datetime.fromisoformat(self.progress.start_time)
        elapsed = datetime.utcnow() - start
        
        hours, remainder = divmod(int(elapsed.total_seconds()), 3600)
        minutes, seconds = divmod(remainder, 60)
        
        return f"{hours}h {minutes}m {seconds}s"
    
    def _save_checkpoint(self) -> None:
        """Save current state to checkpoint file."""
        checkpoint = {
            "jobs": [job.to_dict() for job in self.jobs],
            "progress": self.progress.to_dict(),
            "quality": self.quality.value,
            "saved_at": datetime.utcnow().isoformat(),
        }
        
        with open(self.checkpoint_file, "w") as f:
            json.dump(checkpoint, f, indent=2)
    
    def _load_checkpoint(self) -> bool:
        """Load state from checkpoint file."""
        if not self.checkpoint_file.exists():
            return False
        
        try:
            with open(self.checkpoint_file, "r") as f:
                checkpoint = json.load(f)
            
            self.jobs = [BatchJob.from_dict(j) for j in checkpoint.get("jobs", [])]
            
            progress_data = checkpoint.get("progress", {})
            self.progress = BatchProgress(
                total_jobs=progress_data.get("total_jobs", len(self.jobs)),
                completed_jobs=progress_data.get("completed_jobs", 0),
                failed_jobs=progress_data.get("failed_jobs", 0),
                start_time=progress_data.get("start_time"),
            )
            
            if checkpoint.get("quality"):
                self.quality = BatchQuality(checkpoint["quality"])
                self.quality_config = QUALITY_PRESETS[self.quality]
            
            print(f"Loaded checkpoint: {len(self.jobs)} jobs, {self.progress.completed_jobs} completed")
            return True
            
        except Exception as e:
            print(f"Warning: Failed to load checkpoint: {e}")
            return False
    
    def get_status(self) -> dict:
        """Get current batch processing status."""
        return {
            "jobs": [job.to_dict() for job in self.jobs],
            "progress": self.progress.to_dict(),
            "quality": self.quality.value,
        }


