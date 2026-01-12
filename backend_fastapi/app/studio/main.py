"""
Studio API endpoints for Dreamflow AI Studio.

Provides endpoints for batch processing, templates, analytics, and multi-format output.
"""

import logging
from fastapi import Depends, FastAPI, HTTPException, Query, UploadFile
from typing import Optional
from uuid import UUID

from ..shared.config import Settings
from ..shared.auth import get_authenticated_user_id
from ..shared.supabase_client import SupabaseClient
from ..core.prompting import PromptBuilderMode
from .batch_processor import BatchProcessor, BatchJobStatus
from .template_service import TemplateService
from .analytics_service import AnalyticsService
from .output_formats import OutputFormatService, OutputFormat
from .story_service import StoryService
from .asset_service import AssetService
from .export_service import ExportService
from .media_service import MediaService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("dreamflow_studio")


def create_studio_app(settings: Settings) -> FastAPI:
    """Create and configure Studio FastAPI app."""
    app = FastAPI(title="Dreamflow AI Studio API", version="1.0.0")

    # Initialize Supabase client
    supabase_client: SupabaseClient | None = None
    try:
        supabase_client = SupabaseClient(settings)
    except (ValueError, Exception):
        logger.warning("Supabase not configured, Studio features may be limited")

    # Initialize services
    batch_processor = BatchProcessor(supabase_client) if supabase_client else None
    template_service = TemplateService(supabase_client) if supabase_client else None
    analytics_service = AnalyticsService(supabase_client) if supabase_client else None
    output_format_service = OutputFormatService(supabase_client)
    story_service = StoryService(supabase_client) if supabase_client else None
    asset_service = AssetService(supabase_client) if supabase_client else None
    export_service = ExportService(supabase_client) if supabase_client else None
    media_service = MediaService(supabase_client) if supabase_client else None

    # Batch Processing Endpoints
    @app.post("/batch")
    async def create_batch_job(
        requests: list[dict],
        email_notifications: bool = True,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Create a new batch job."""
        if not batch_processor:
            raise HTTPException(
                status_code=503, detail="Batch processing not available"
            )

        # Convert dicts to StoryRequest objects
        from ..dreamflow.schemas import StoryRequest

        story_requests = [StoryRequest(**req) for req in requests]

        job = await batch_processor.create_batch_job(
            user_id=user_id,
            requests=story_requests,
            email_notifications=email_notifications,
        )
        return job

    @app.get("/batch/{job_id}")
    async def get_batch_job(
        job_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get a batch job by ID."""
        if not batch_processor:
            raise HTTPException(
                status_code=503, detail="Batch processing not available"
            )

        job = await batch_processor.get_batch_job(job_id, user_id)
        if not job:
            raise HTTPException(status_code=404, detail="Batch job not found")
        return job

    @app.get("/batch")
    async def list_batch_jobs(
        status: Optional[str] = None,
        limit: int = 20,
        offset: int = 0,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """List batch jobs for the user."""
        if not batch_processor:
            raise HTTPException(
                status_code=503, detail="Batch processing not available"
            )

        status_enum = BatchJobStatus(status) if status else None
        jobs = await batch_processor.list_batch_jobs(
            user_id=user_id,
            status=status_enum,
            limit=limit,
            offset=offset,
        )
        return {"jobs": jobs, "total": len(jobs)}

    @app.post("/batch/{job_id}/cancel")
    async def cancel_batch_job(
        job_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Cancel a batch job."""
        if not batch_processor:
            raise HTTPException(
                status_code=503, detail="Batch processing not available"
            )

        success = await batch_processor.cancel_batch_job(job_id, user_id)
        if not success:
            raise HTTPException(
                status_code=404, detail="Batch job not found or cannot be cancelled"
            )
        return {"status": "cancelled"}

    # Template Endpoints
    @app.post("/templates")
    async def create_template(
        name: str,
        prompt: str,
        theme: str,
        target_length: int = 400,
        num_scenes: int = 4,
        voice: Optional[str] = None,
        mode: str = "branded_wellness",
        description: Optional[str] = None,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Create a new template."""
        if not template_service:
            raise HTTPException(
                status_code=503, detail="Template service not available"
            )

        mode_enum = PromptBuilderMode(mode)
        template = template_service.create_template(
            user_id=user_id,
            name=name,
            prompt=prompt,
            theme=theme,
            target_length=target_length,
            num_scenes=num_scenes,
            voice=voice,
            mode=mode_enum,
            description=description,
        )
        return template

    @app.get("/templates")
    async def list_templates(
        limit: int = 20,
        offset: int = 0,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """List templates for the user."""
        if not template_service:
            raise HTTPException(
                status_code=503, detail="Template service not available"
            )

        templates = template_service.list_templates(
            user_id=user_id, limit=limit, offset=offset
        )
        return {"templates": templates}

    @app.get("/templates/{template_id}")
    async def get_template(
        template_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get a template by ID."""
        if not template_service:
            raise HTTPException(
                status_code=503, detail="Template service not available"
            )

        template = template_service.get_template(template_id, user_id)
        if not template:
            raise HTTPException(status_code=404, detail="Template not found")
        return template

    # Analytics Endpoints
    @app.get("/analytics/overview")
    async def get_analytics_overview(
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get overview analytics for the creator."""
        if not analytics_service:
            raise HTTPException(
                status_code=503, detail="Analytics service not available"
            )

        stats = analytics_service.get_overview_stats(user_id)
        return stats

    @app.get("/analytics/renders")
    async def get_render_stats(
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get render statistics."""
        if not analytics_service:
            raise HTTPException(
                status_code=503, detail="Analytics service not available"
            )

        from datetime import datetime

        start = datetime.fromisoformat(start_date) if start_date else None
        end = datetime.fromisoformat(end_date) if end_date else None

        stats = analytics_service.get_render_stats(user_id, start, end)
        return stats

    @app.get("/analytics/templates/{template_id}")
    async def get_template_performance(
        template_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get template performance statistics."""
        if not analytics_service:
            raise HTTPException(
                status_code=503, detail="Analytics service not available"
            )

        stats = analytics_service.get_template_performance(user_id, template_id)
        return stats

    # Output Format Endpoints
    @app.post("/formats/generate")
    async def generate_formats(
        frame_urls: list[str],
        audio_url: str,
        story_text: str,
        theme: str,
        formats: Optional[list[str]] = None,
    ):
        """Generate multiple output formats from story assets."""
        format_enums = [OutputFormat(f) for f in (formats or [])] if formats else None
        result = await output_format_service.generate_all_formats(
            frame_urls=frame_urls,
            audio_url=audio_url,
            story_text=story_text,
            theme=theme,
            formats=format_enums,
        )
        return result


    # Story CRUD Endpoints
    @app.post("/story")
    async def create_story(
        prompt: str,
        theme: str,
        title: Optional[str] = None,
        content: Optional[str] = None,
        parameters: Optional[dict] = None,
        generate_video: bool = False,
        generate_audio: bool = False,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Create a new story."""
        if not story_service:
            raise HTTPException(status_code=503, detail="Story service not available")

        story = story_service.create_story(
            user_id=user_id,
            prompt=prompt,
            theme=theme,
            title=title,
            content=content,
            parameters=parameters,
            generate_video=generate_video,
            generate_audio=generate_audio,
        )
        return {"success": True, "story": story}

    @app.get("/story/{story_id}")
    async def get_story(
        story_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get a story by ID."""
        if not story_service:
            raise HTTPException(status_code=503, detail="Story service not available")

        story = story_service.get_story(story_id, user_id)
        if not story:
            raise HTTPException(status_code=404, detail="Story not found")
        return {"success": True, "story": story}

    @app.put("/story/{story_id}")
    async def update_story(
        story_id: UUID,
        title: Optional[str] = None,
        content: Optional[str] = None,
        theme: Optional[str] = None,
        parameters: Optional[dict] = None,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Update a story."""
        if not story_service:
            raise HTTPException(status_code=503, detail="Story service not available")

        story = story_service.update_story(
            story_id=story_id,
            user_id=user_id,
            title=title,
            content=content,
            theme=theme,
            parameters=parameters,
        )
        return {"success": True, "story": story}

    @app.delete("/story/{story_id}")
    async def delete_story(
        story_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Delete a story."""
        if not story_service:
            raise HTTPException(status_code=503, detail="Story service not available")

        success = story_service.delete_story(story_id, user_id)
        if not success:
            raise HTTPException(status_code=404, detail="Story not found")
        return {"success": True}

    @app.get("/story/history")
    async def get_story_history(
        page: int = Query(1, ge=1),
        limit: int = Query(20, ge=1, le=100),
        theme: Optional[str] = None,
        search: Optional[str] = None,
        sort_by: str = Query("created_at", pattern="^(created_at|updated_at|title)$"),
        sort_order: str = Query("desc", pattern="^(asc|desc)$"),
        has_video: Optional[bool] = None,
        has_audio: Optional[bool] = None,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get story history with pagination and filters."""
        if not story_service:
            raise HTTPException(status_code=503, detail="Story service not available")

        result = story_service.list_stories(
            user_id=user_id,
            page=page,
            limit=limit,
            theme=theme,
            search=search,
            sort_by=sort_by,
            sort_order=sort_order,
            has_video=has_video,
            has_audio=has_audio,
        )
        return {"success": True, **result}

    # Asset Management Endpoints
    @app.get("/assets")
    async def list_assets(
        page: int = Query(1, ge=1),
        limit: int = Query(20, ge=1, le=100),
        type: Optional[str] = Query(None, pattern="^(video|audio|image)$"),
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """List assets with pagination."""
        if not asset_service:
            raise HTTPException(status_code=503, detail="Asset service not available")

        result = asset_service.list_assets(
            user_id=user_id,
            page=page,
            limit=limit,
            asset_type=type,
        )
        return {"success": True, **result}

    @app.post("/assets/upload")
    async def upload_asset(
        file: UploadFile,
        type: str = Query(..., pattern="^(video|audio|image)$"),
        name: Optional[str] = None,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Upload a custom asset."""
        if not asset_service:
            raise HTTPException(status_code=503, detail="Asset service not available")

        asset = asset_service.upload_asset(
            user_id=user_id,
            file=file,
            asset_type=type,
            name=name,
        )
        return {"success": True, "asset": asset}

    @app.get("/assets/{asset_id}")
    async def get_asset(
        asset_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get an asset by ID."""
        if not asset_service:
            raise HTTPException(status_code=503, detail="Asset service not available")

        asset = asset_service.get_asset(asset_id, user_id)
        if not asset:
            raise HTTPException(status_code=404, detail="Asset not found")
        return {"success": True, "asset": asset}

    @app.delete("/assets/{asset_id}")
    async def delete_asset(
        asset_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Delete an asset."""
        if not asset_service:
            raise HTTPException(status_code=503, detail="Asset service not available")

        success = asset_service.delete_asset(asset_id, user_id)
        if not success:
            raise HTTPException(status_code=404, detail="Asset not found")
        return {"success": True}

    # Export Endpoints
    @app.get("/story/{story_id}/export")
    async def export_story(
        story_id: UUID,
        format: str = Query(..., pattern="^(pdf|markdown|json)$"),
        include_metadata: bool = Query(True),
        include_media_links: bool = Query(True),
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Export a story in the specified format."""
        if not export_service:
            raise HTTPException(status_code=503, detail="Export service not available")

        return export_service.export_story(
            story_id=story_id,
            user_id=user_id,
            format=format,
            include_metadata=include_metadata,
            include_media_links=include_media_links,
        )

    # Media Status Endpoints
    @app.get("/story/{story_id}/media/status")
    async def get_media_status(
        story_id: UUID,
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get media generation status for a story."""
        if not media_service:
            raise HTTPException(status_code=503, detail="Media service not available")

        status = media_service.get_media_status(story_id, user_id)
        return {"success": True, "status": status}

    @app.post("/story/{story_id}/media/regenerate")
    async def regenerate_media(
        story_id: UUID,
        type: str = Query(..., pattern="^(video|audio)$"),
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Regenerate media for a story."""
        if not media_service:
            raise HTTPException(status_code=503, detail="Media service not available")

        result = media_service.regenerate_media(story_id, user_id, type)
        return {"success": True, **result}

    @app.get("/story/media/usage")
    async def get_media_usage(
        user_id: UUID = Depends(get_authenticated_user_id),
    ):
        """Get media usage statistics for the user."""
        if not media_service:
            raise HTTPException(status_code=503, detail="Media service not available")

        usage = media_service.get_media_usage(user_id)
        return {"success": True, "usage": usage}

    return app
