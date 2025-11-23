import asyncio
import hashlib
import json
import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from uuid import UUID, uuid4

import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.logging import LoggingIntegration
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from fastapi import Depends, FastAPI, HTTPException, Query, Request
from typing import Optional, Any
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from .auth import get_authenticated_user_id, get_admin_user_id
from .config import Settings, get_settings
from .exceptions import HuggingFaceError
from .guardrails import ContentGuard, GuardrailError, PromptSanitizer
from .prompting import PromptBuilder
from .schemas import (
    StoryRequest,
    StoryResponse,
    AssetUrls,
    StoryHistoryItem,
    StoryHistoryResponse,
    SessionAsset,
    SessionHistoryItem,
    SessionHistoryResponse,
    StoryPresetsResponse,
    ThemePreset,
    FeedbackRequest,
    FeedbackResponse,
    ModerationQueueItem,
    ModerationQueueListResponse,
    ResolveModerationRequest,
    GuardrailViolationSchema,
    SubscriptionResponse,
    UsageQuotaResponse,
    CreateSubscriptionRequest,
    CancelSubscriptionRequest,
    RegisterNotificationTokenRequest,
    NotificationPreferencesResponse,
    UpdateNotificationPreferencesRequest,
)
from .services import NarrationGenerator, StoryGenerator, VisualGenerator
from . import services as services_module

stitch_video = services_module.stitch_video
from .supabase_client import SupabaseClient
from .subscription_service import SubscriptionService
from .notification_service import NotificationService
from .recommendation_engine import RecommendationEngine


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("dream_flow")


def log_event(level: int, event: str, **kwargs) -> None:
    payload = {"event": event}
    payload.update({k: v for k, v in kwargs.items() if v is not None})
    logger.log(level, json.dumps(payload, default=str))


def derive_prompt_id(current_prompt_id: str | None, prompt: str | None) -> str:
    if current_prompt_id:
        return current_prompt_id
    if not prompt:
        return uuid4().hex
    digest = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
    return digest[:16]


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or str(uuid4())
        prompt_id = request.headers.get("X-Prompt-ID")
        request.state.request_id = request_id
        request.state.prompt_id = prompt_id
        request.state.session_id = None  # Will be set when session is created
        
        # Set basic Sentry context for all requests
        with sentry_sdk.push_scope() as scope:
            scope.set_tag("request_id", request_id)
            if prompt_id:
                scope.set_tag("prompt_id", prompt_id)
            scope.set_tag("path", request.url.path)
            scope.set_tag("method", request.method)
            
            start_time = time.perf_counter()
            log_event(
                logging.INFO,
                "request.start",
                request_id=request_id,
                prompt_id=prompt_id,
                path=request.url.path,
                method=request.method,
            )
            try:
                response = await call_next(request)
            except Exception as exc:
                duration_ms = (time.perf_counter() - start_time) * 1000
                session_id = getattr(request.state, "session_id", None)
                log_event(
                    logging.ERROR,
                    "request.error",
                    request_id=request_id,
                    prompt_id=prompt_id,
                    session_id=str(session_id) if session_id else None,
                    path=request.url.path,
                    method=request.method,
                    duration_ms=round(duration_ms, 2),
                    error=str(exc),
                )
                # Add session_id to scope if available
                if session_id:
                    scope.set_tag("session_id", str(session_id))
                    scope.set_context("session", {"id": str(session_id)})
                # Capture exception in Sentry
                sentry_sdk.capture_exception(exc)
                raise

            duration_ms = (time.perf_counter() - start_time) * 1000
            session_id = getattr(request.state, "session_id", None)
            response.headers["X-Request-ID"] = request_id
            if prompt_id:
                response.headers["X-Prompt-ID"] = prompt_id

            log_event(
                logging.INFO,
                "request.complete",
                request_id=request_id,
                prompt_id=prompt_id,
                session_id=str(session_id) if session_id else None,
                path=request.url.path,
                method=request.method,
                status_code=response.status_code,
                duration_ms=round(duration_ms, 2),
            )
            return response


# Global scheduler instance
scheduler: Optional[AsyncIOScheduler] = None


async def purge_expired_assets_job(settings: Settings, supabase_client: Optional[SupabaseClient]) -> None:
    """
    Scheduled job to purge expired media assets.
    
    This job runs daily to delete storage objects and database rows
    for assets older than the configured retention period.
    """
    if not supabase_client:
        logger.warning("Purge job skipped: Supabase client not configured")
        return
    
    try:
        log_event(
            logging.INFO,
            "purge.job.start",
            retention_days=settings.asset_retention_days,
        )
        
        stats = supabase_client.purge_expired_assets(days_old=settings.asset_retention_days)
        
        log_event(
            logging.INFO,
            "purge.job.complete",
            retention_days=settings.asset_retention_days,
            assets_found=stats["assets_found"],
            assets_deleted=stats["assets_deleted"],
            storage_deleted=stats["storage_deleted"],
            storage_errors=stats["storage_errors"],
            error_count=len(stats["errors"]),
        )
        
        # Log errors if any
        if stats["errors"]:
            for error in stats["errors"][:10]:  # Limit to first 10 errors
                log_event(logging.WARNING, "purge.job.error", error=error)
            if len(stats["errors"]) > 10:
                log_event(
                    logging.WARNING,
                    "purge.job.errors_truncated",
                    total_errors=len(stats["errors"]),
                    shown=10,
                )
        
        # Capture in Sentry if there were significant errors
        if stats["storage_errors"] > 0:
            with sentry_sdk.push_scope() as scope:
                scope.set_tag("purge_job", "true")
                scope.set_context("purge_stats", stats)
                sentry_sdk.capture_message(
                    f"Asset purge job completed with {stats['storage_errors']} storage errors",
                    level="warning",
                )
    
    except Exception as e:
        log_event(
            logging.ERROR,
            "purge.job.failed",
            retention_days=settings.asset_retention_days,
            error=str(e),
        )
        # Capture exception in Sentry
        with sentry_sdk.push_scope() as scope:
            scope.set_tag("purge_job", "true")
            sentry_sdk.capture_exception(e)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for FastAPI app.
    Handles startup and shutdown events for the scheduler.
    """
    global scheduler
    
    # Startup: Initialize and start scheduler
    settings = get_settings()
    supabase_client: Optional[SupabaseClient] = None
    try:
        supabase_client = SupabaseClient(settings)
    except (ValueError, Exception):
        # Supabase not configured, scheduler will skip jobs
        pass
    
    if supabase_client:
        scheduler = AsyncIOScheduler()
        
        # Schedule purge job to run daily at 2:00 AM UTC
        scheduler.add_job(
            purge_expired_assets_job,
            trigger=CronTrigger(hour=2, minute=0, timezone="UTC"),
            args=[settings, supabase_client],
            id="purge_expired_assets",
            name="Purge Expired Media Assets",
            replace_existing=True,
        )
        
        scheduler.start()
        logger.info(
            f"Scheduled asset purge job: daily at 2:00 AM UTC "
            f"(retention: {settings.asset_retention_days} days)"
        )
    else:
        logger.info("Asset purge job not scheduled: Supabase not configured")
    
    yield
    
    # Shutdown: Stop scheduler
    if scheduler:
        scheduler.shutdown()
        logger.info("Scheduler stopped")


def create_app(settings: Settings) -> FastAPI:
    # Initialize Sentry if DSN is provided
    if settings.sentry_dsn:
        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.sentry_environment,
            traces_sample_rate=settings.sentry_traces_sample_rate,
            integrations=[
                FastApiIntegration(transaction_style="endpoint"),
                LoggingIntegration(level=logging.INFO, event_level=logging.ERROR),
            ],
            # Capture unhandled exceptions
            before_send=lambda event, hint: event,
        )
        logger.info(f"Sentry initialized for environment: {settings.sentry_environment}")
    else:
        logger.info("Sentry DSN not provided, error tracking disabled")
    
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(RequestContextMiddleware)

    # Static mounts removed - files are now served via Supabase Storage signed URLs

    prompt_builder = PromptBuilder()
    prompt_sanitizer = PromptSanitizer()
    story_gen = StoryGenerator(prompt_builder=prompt_builder)
    narration_gen = NarrationGenerator(prompt_builder=prompt_builder, prompt_sanitizer=prompt_sanitizer)
    visual_gen = VisualGenerator(prompt_builder=prompt_builder, prompt_sanitizer=prompt_sanitizer)
    guard = ContentGuard()
    
    # Initialize Supabase client if configured
    supabase_client: SupabaseClient | None = None
    subscription_service: SubscriptionService | None = None
    notification_service: NotificationService | None = None
    recommendation_engine: RecommendationEngine | None = None
    try:
        supabase_client = SupabaseClient(settings)
        subscription_service = SubscriptionService(supabase_client.client)
        notification_service = NotificationService(supabase_client.client)
        recommendation_engine = RecommendationEngine(supabase_client.client)
    except (ValueError, Exception):
        # Supabase not configured, continue without persistence
        pass

    @app.post("/api/v1/story", response_model=StoryResponse)
    async def generate_story(payload: StoryRequest, request: Request) -> StoryResponse:
        if not settings.hf_token:
            raise HTTPException(status_code=500, detail="Missing HUGGINGFACE_API_TOKEN environment variable")

        try:
            pipeline_start = time.perf_counter()
            request_id = getattr(request.state, "request_id", None)
            prompt_id = derive_prompt_id(getattr(request.state, "prompt_id", None), payload.prompt)
            request.state.prompt_id = prompt_id
            log_event(
                logging.INFO,
                "story.generate.start",
                request_id=request_id,
                prompt_id=prompt_id,
                theme=payload.theme,
                num_scenes=payload.num_scenes,
                user_id=str(payload.user_id) if payload.user_id else None,
            )

            # Check subscription quota if user_id is provided
            if payload.user_id and subscription_service:
                can_generate, error_message = subscription_service.can_generate_story(payload.user_id)
                if not can_generate:
                    log_event(
                        logging.WARNING,
                        "story.generate.quota_exceeded",
                        request_id=request_id,
                        prompt_id=prompt_id,
                        user_id=str(payload.user_id),
                    )
                    raise HTTPException(
                        status_code=429,
                        detail={
                            "error": "Quota exceeded",
                            "message": error_message,
                            "upgrade_required": True,
                        },
                    )

            context = prompt_builder.to_context(payload)
            
            # Generate story with async timeout and retries
            story_start = time.perf_counter()
            story_text = await story_gen.generate(context)
            story_duration_ms = (time.perf_counter() - story_start) * 1000
            log_event(
                logging.INFO,
                "story.generate.model_complete",
                request_id=request_id,
                prompt_id=prompt_id,
                duration_ms=round(story_duration_ms, 2),
            )
            
            # Get content filter level if child mode is enabled
            content_filter_level = "standard"
            child_mode = payload.child_mode
            child_profile_id = payload.child_profile_id
            if child_mode and child_profile_id and supabase_client:
                try:
                    # Fetch child profile to get filter level
                    child_profile = (
                        supabase_client.client.table("family_profiles")
                        .select("content_filter_level, age")
                        .eq("id", str(child_profile_id))
                        .maybe_single()
                        .execute()
                    )
                    if child_profile.data:
                        content_filter_level = child_profile.data.get("content_filter_level", "standard")
                except Exception:
                    # Default to standard if fetch fails
                    pass

            violations = guard.check_story(
                story_text,
                profile=payload.profile,
                child_mode=child_mode,
                content_filter_level=content_filter_level,
            )
            if violations:
                log_event(
                    logging.WARNING,
                    "story.generate.guardrail_violation",
                    request_id=request_id,
                    prompt_id=prompt_id,
                    violations=len(violations),
                )
                
                # Capture guardrail violation in Sentry with session context
                # Note: session_id may not be available yet if violations occur before session creation
                with sentry_sdk.push_scope() as scope:
                    scope.set_tag("guardrail_violation", "true")
                    scope.set_tag("violation_count", str(len(violations)))
                    scope.set_tag("content_type", "story")
                    scope.set_context("violations", {
                        "count": len(violations),
                        "categories": [v.category for v in violations],
                        "details": [v.detail for v in violations],
                    })
                    if payload.user_id:
                        scope.set_tag("user_id", str(payload.user_id))
                    # Session ID not available yet, but we have request_id and prompt_id
                    scope.level = "warning"
                    sentry_sdk.capture_message(
                        f"Guardrail violation detected: {len(violations)} violation(s) in story generation",
                        level="warning",
                    )
                
                # Enqueue violations to moderation queue if Supabase is configured
                if supabase_client:
                    try:
                        violations_dict = [{"category": v.category, "detail": v.detail} for v in violations]
                        supabase_client.create_moderation_item(
                            violations=violations_dict,
                            content=story_text,
                            content_type="story",
                            user_id=payload.user_id,
                            session_id=None,  # Session not created yet if violations occur
                        )
                        log_event(
                            logging.INFO,
                            "moderation.enqueued",
                            request_id=request_id,
                            prompt_id=prompt_id,
                            violations=len(violations),
                        )
                    except Exception as e:
                        # Log error but don't fail the request
                        log_event(
                            logging.ERROR,
                            "moderation.enqueue.error",
                            request_id=request_id,
                            prompt_id=prompt_id,
                            error=str(e),
                        )
                
                raise HTTPException(
                    status_code=422,
                    detail=[violation.__dict__ for violation in violations],
                )

            # Generate assets and upload to Supabase Storage if available
            audio_task = narration_gen.synthesize(story_text, context, payload.voice, supabase_client)
            frames_task = visual_gen.create_frames(story_text, context, payload.num_scenes, supabase_client)
            
            assets_start = time.perf_counter()
            audio_url, frame_urls = await asyncio.gather(audio_task, frames_task)
            assets_duration_ms = (time.perf_counter() - assets_start) * 1000
            log_event(
                logging.INFO,
                "story.generate.assets_complete",
                request_id=request_id,
                prompt_id=prompt_id,
                duration_ms=round(assets_duration_ms, 2),
                frames=len(frame_urls),
            )
            
            # Stitch video (now async and handles URLs)
            video_url = await stitch_video(frame_urls, audio_url, supabase_client)

            # Use signed URLs directly from Supabase Storage
            assets = AssetUrls(
                audio=audio_url,
                video=video_url,
                frames=frame_urls,
            )
            
            # Persist to Supabase if user_id is provided and client is available
            session_id: UUID | None = None
            if payload.user_id and supabase_client:
                try:
                    # Upsert profile if profile context is provided
                    if payload.profile:
                        supabase_client.upsert_profile(
                            user_id=payload.user_id,
                            mood=payload.profile.mood,
                            routine=payload.profile.routine,
                            preferences=payload.profile.preferences,
                            favorite_characters=payload.profile.favorite_characters,
                            calming_elements=payload.profile.calming_elements,
                        )
                    
                    # Create session
                    session = supabase_client.create_session(
                        user_id=payload.user_id,
                        prompt=payload.prompt,
                        theme=payload.theme,
                        story_text=story_text,
                        target_length=payload.target_length,
                        num_scenes=payload.num_scenes,
                        voice=payload.voice,
                    )
                    session_id = UUID(session["id"])
                    # Store session_id in request state for Sentry context
                    request.state.session_id = session_id
                    
                    # Assets are already signed URLs from Supabase Storage
                    # Create session assets
                    session_assets = [
                        {"asset_type": "audio", "asset_url": assets.audio, "display_order": 0},
                        {"asset_type": "video", "asset_url": assets.video, "display_order": 1},
                    ]
                    # Add frame assets with sequential display order
                    for idx, frame_url in enumerate(assets.frames):
                        session_assets.append({
                            "asset_type": "frame",
                            "asset_url": frame_url,
                            "display_order": idx + 2,
                        })
                    
                    supabase_client.create_session_assets_batch(
                        session_id=session_id,
                        assets=session_assets,
                    )
                    
                    # Increment story count after successful generation
                    if subscription_service:
                        try:
                            subscription_service.increment_story_count(payload.user_id, "weekly")
                            log_event(
                                logging.INFO,
                                "subscription.increment_count.success",
                                request_id=request_id,
                                user_id=str(payload.user_id),
                            )
                        except Exception as e:
                            # Log error but don't fail the request
                            log_event(
                                logging.WARNING,
                                "subscription.increment_count.error",
                                request_id=request_id,
                                user_id=str(payload.user_id),
                                error=str(e),
                            )
                except Exception as e:
                    # Log error but don't fail the request - story was already generated
                    # In production, you might want to log this to a monitoring service
                    log_event(
                        logging.WARNING,
                        "story.persist.warning",
                        request_id=request_id,
                        prompt_id=prompt_id,
                        error=str(e),
                    )
            
            total_duration_ms = (time.perf_counter() - pipeline_start) * 1000
            log_event(
                logging.INFO,
                "story.generate.success",
                request_id=request_id,
                prompt_id=prompt_id,
                session_id=str(session_id) if session_id else None,
                duration_ms=round(total_duration_ms, 2),
                theme=payload.theme,
            )
            
            return StoryResponse(
                story_text=story_text,
                theme=payload.theme,
                assets=assets,
                session_id=session_id,
            )
        
        except HTTPException as exc:
            # Propagate HTTPExceptions (e.g., guardrail violations) without wrapping
            log_event(
                logging.WARNING,
                "story.generate.http_error",
                request_id=getattr(request.state, "request_id", None),
                prompt_id=getattr(request.state, "prompt_id", None),
                status_code=exc.status_code,
                detail=exc.detail,
            )
            raise
        except GuardrailError as e:
            # Capture guardrail violation in Sentry with session context
            request_id_attr = getattr(request.state, "request_id", None)
            prompt_id_attr = getattr(request.state, "prompt_id", None)
            session_id_attr = getattr(request.state, "session_id", None)
            
            with sentry_sdk.push_scope() as scope:
                scope.set_tag("guardrail_violation", "true")
                scope.set_tag("violation_count", str(len(e.violations)))
                scope.set_tag("content_type", e.prompt_type)
                scope.set_context("violations", {
                    "count": len(e.violations),
                    "categories": [v.category for v in e.violations],
                    "details": [v.detail for v in e.violations],
                    "prompt_type": e.prompt_type,
                })
                if session_id_attr:
                    scope.set_tag("session_id", str(session_id_attr))
                    scope.set_context("session", {"id": str(session_id_attr)})
                if request_id_attr:
                    scope.set_tag("request_id", request_id_attr)
                if prompt_id_attr:
                    scope.set_tag("prompt_id", prompt_id_attr)
                if payload.user_id if hasattr(payload, "user_id") else None:
                    scope.set_tag("user_id", str(payload.user_id))
                scope.level = "warning"
                sentry_sdk.capture_message(
                    f"Guardrail violation detected: {len(e.violations)} violation(s) in {e.prompt_type} prompt",
                    level="warning",
                )
            
            # Enqueue violations to moderation queue if Supabase is configured
            if supabase_client:
                try:
                    violations_dict = [{"category": v.category, "detail": v.detail} for v in e.violations]
                    # Map prompt_type to content_type for moderation queue
                    content_type_map = {
                        "narration": "narration",
                        "visual": "visual",
                    }
                    content_type = content_type_map.get(e.prompt_type, "prompt")
                    
                    supabase_client.create_moderation_item(
                        violations=violations_dict,
                        content=e.content,
                        content_type=content_type,
                        user_id=payload.user_id if hasattr(payload, "user_id") else None,
                        session_id=session_id_attr,
                    )
                    log_event(
                        logging.INFO,
                        "moderation.enqueued",
                        request_id=request_id_attr,
                        prompt_id=prompt_id_attr,
                        violations=len(e.violations),
                        content_type=content_type,
                    )
                except Exception as enqueue_error:
                    # Log error but don't fail the request
                    log_event(
                        logging.ERROR,
                        "moderation.enqueue.error",
                        request_id=request_id_attr,
                        prompt_id=prompt_id_attr,
                        error=str(enqueue_error),
                    )
            
            raise HTTPException(
                status_code=422,
                detail=[violation.__dict__ for violation in e.violations],
            )
        except HuggingFaceError as e:
            # Convert structured HuggingFace errors to HTTP exceptions
            status_code = e.status_code or 503
            detail = {
                "error": e.message,
                "model_id": e.model_id,
                "details": e.details,
            }
            log_event(
                logging.ERROR,
                "story.generate.huggingface_error",
                request_id=getattr(request.state, "request_id", None),
                prompt_id=getattr(request.state, "prompt_id", None),
                status_code=status_code,
                model_id=e.model_id,
            )
            raise HTTPException(status_code=status_code, detail=detail)
        
        except Exception as e:
            # Catch any other unexpected errors
            log_event(
                logging.ERROR,
                "story.generate.unexpected_error",
                request_id=getattr(request.state, "request_id", None),
                prompt_id=getattr(request.state, "prompt_id", None),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail={
                    "error": "Internal server error during story generation",
                    "message": str(e),
                },
            )

    @app.get("/api/v1/history", response_model=SessionHistoryResponse)
    async def get_history(
        request: Request,
        user_id: UUID,
        limit: int = 10,
        settings: Settings = Depends(get_settings),
    ) -> SessionHistoryResponse:
        """
        Get recent sessions for a user with thumbnails.
        
        Args:
            user_id: UUID of the user
            limit: Maximum number of sessions to return (default: 10)
        
        Returns:
            List of recent sessions with thumbnails
        """
        if not supabase_client:
            return SessionHistoryResponse(sessions=[])
        
        try:
            # Get user sessions
            sessions = supabase_client.get_user_sessions(
                user_id=user_id,
                limit=limit,
                offset=0,
                order_by="created_at",
                ascending=False,
            )
            
            # For each session, get the first frame as thumbnail
            history_items = []
            for session in sessions:
                session_id = UUID(session["id"])
                assets = supabase_client.get_session_assets(
                    session_id=session_id,
                    asset_type="frame",
                )
                
                # Get the first frame as thumbnail, or None if no frames
                thumbnail_url = assets[0]["asset_url"] if assets else None
                
                history_items.append(
                    SessionHistoryItem(
                        session_id=session_id,
                        theme=session["theme"],
                        prompt=session["prompt"],
                        thumbnail_url=thumbnail_url,
                        created_at=session["created_at"],
                    )
                )
            
            return SessionHistoryResponse(sessions=history_items)
        
        except Exception as e:
            # Log error but return empty list instead of failing
            log_event(
                logging.WARNING,
                "history.fetch.warning",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            return SessionHistoryResponse(sessions=[])

    @app.get("/api/v1/stories/history", response_model=StoryHistoryResponse)
    async def get_stories_history(
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
        limit: int = Query(10, ge=1, le=100, description="Number of stories to return per page"),
        offset: int = Query(0, ge=0, description="Number of stories to skip"),
    ) -> StoryHistoryResponse:
        """
        Get paginated history of stories for the authenticated user.
        
        Args:
            user_id: Authenticated user ID (from JWT token)
            limit: Maximum number of stories to return (1-100, default: 10)
            offset: Number of stories to skip for pagination (default: 0)
            
        Returns:
            Paginated list of story history items with assets
        """
        if not supabase_client:
            raise HTTPException(
                status_code=503,
                detail="Supabase not configured. Story history is unavailable.",
            )
        
        try:
            # Get user sessions with pagination (fetch limit+1 to check if there are more)
            sessions = supabase_client.get_user_sessions(
                user_id=user_id,
                limit=limit + 1,  # Fetch one extra to check if there are more
                offset=offset,
                order_by="created_at",
                ascending=False,
            )
            
            # Check if there are more items
            has_more = len(sessions) > limit
            if has_more:
                sessions = sessions[:limit]  # Remove the extra item
            
            # For total count, we'll estimate based on current page
            # In production, you might want to use a count query for accuracy
            # For now, we'll set total to offset + len(sessions) + (1 if has_more else 0)
            # This is an estimate; for exact count, use a separate count query
            total_estimate = offset + len(sessions) + (1 if has_more else 0)
            
            # Build history items with assets
            history_items = []
            for session in sessions:
                session_id = UUID(session["id"])
                
                # Get all assets for this session
                assets_data = supabase_client.get_session_assets(session_id=session_id)
                
                # Convert to SessionAsset models
                assets = [
                    SessionAsset(
                        id=UUID(asset["id"]),
                        asset_type=asset["asset_type"],
                        asset_url=asset["asset_url"],
                        display_order=asset["display_order"],
                    )
                    for asset in assets_data
                ]
                
                history_items.append(
                    StoryHistoryItem(
                        id=session_id,
                        prompt=session["prompt"],
                        theme=session["theme"],
                        story_text=session["story_text"],
                        target_length=session.get("target_length", 400),
                        num_scenes=session.get("num_scenes", 4),
                        voice=session.get("voice"),
                        created_at=session["created_at"],
                        updated_at=session.get("updated_at", session["created_at"]),
                        assets=assets,
                    )
                )
            
            return StoryHistoryResponse(
                stories=history_items,
                total=total_estimate,
                limit=limit,
                offset=offset,
                has_more=has_more,
            )
        
        except HTTPException:
            raise
        except Exception as e:
            log_event(
                logging.ERROR,
                "story.history.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to fetch story history: {str(e)}",
            )

    @app.get("/api/v1/presets", response_model=StoryPresetsResponse)
    async def get_story_presets() -> StoryPresetsResponse:
        """
        Get all available story themes and featured worlds.
        
        Returns:
            StoryPresetsResponse with all themes and featured worlds
        """
        all_themes = prompt_builder.get_all_themes()
        featured_worlds = prompt_builder.get_featured_worlds()
        
        # Convert dict themes to ThemePreset models
        theme_presets = [ThemePreset(**theme) for theme in all_themes]
        featured_presets = [ThemePreset(**world) for world in featured_worlds]
        
        return StoryPresetsResponse(
            themes=theme_presets,
            featured=featured_presets,
        )

    @app.post("/api/v1/feedback", response_model=FeedbackResponse)
    async def submit_feedback(
        payload: FeedbackRequest,
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
        settings: Settings = Depends(get_settings),
    ) -> FeedbackResponse:
        """
        Submit post-session feedback including rating and mood delta.
        
        Args:
            payload: Feedback data with session_id, rating, and mood_delta
            user_id: Authenticated user ID (from JWT token)
            
        Returns:
            Created feedback response
        """
        if not supabase_client:
            raise HTTPException(
                status_code=503,
                detail="Supabase not configured. Feedback submission is unavailable.",
            )
        
        try:
            # Set session_id in request state and Sentry context
            request.state.session_id = payload.session_id
            with sentry_sdk.push_scope() as scope:
                scope.set_tag("session_id", str(payload.session_id))
                scope.set_context("session", {"id": str(payload.session_id)})
            
            request_id = getattr(request.state, "request_id", None)
            
            # Verify session belongs to user
            session = supabase_client.get_session(payload.session_id)
            if not session:
                raise HTTPException(
                    status_code=404,
                    detail=f"Session {payload.session_id} not found",
                )
            if UUID(session["user_id"]) != user_id:
                raise HTTPException(
                    status_code=403,
                    detail="You can only submit feedback for your own sessions",
                )
            
            # Log guardrail context before storing feedback
            log_event(
                logging.INFO,
                "feedback.guardrail_context",
                request_id=request_id,
                session_id=str(payload.session_id),
                user_id=str(user_id),
                rating=payload.rating,
                mood_delta=payload.mood_delta,
                theme=session.get("theme"),
                prompt=session.get("prompt"),
            )
            
            # Create or update feedback
            feedback = supabase_client.create_feedback(
                session_id=payload.session_id,
                user_id=user_id,
                rating=payload.rating,
                mood_delta=payload.mood_delta,
            )
            
            log_event(
                logging.INFO,
                "feedback.submit.success",
                request_id=request_id,
                session_id=str(payload.session_id),
                user_id=str(user_id),
                rating=payload.rating,
                mood_delta=payload.mood_delta,
            )
            
            return FeedbackResponse(
                id=UUID(feedback["id"]),
                session_id=UUID(feedback["session_id"]),
                rating=feedback["rating"],
                mood_delta=feedback["mood_delta"],
                created_at=datetime.fromisoformat(feedback["created_at"].replace("Z", "+00:00")),
            )
        
        except HTTPException:
            raise
        except Exception as e:
            log_event(
                logging.ERROR,
                "feedback.submit.error",
                request_id=getattr(request.state, "request_id", None),
                session_id=str(payload.session_id),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to submit feedback: {str(e)}",
            )

    @app.get("/health")
    async def health(settings: Settings = Depends(get_settings)) -> dict[str, str]:
        return {"status": "ok", "story_model": settings.story_model}

    # ============================================================================
    # Admin Endpoints - Moderation Queue
    # ============================================================================

    @app.get("/api/v1/admin/moderation", response_model=ModerationQueueListResponse)
    async def list_moderation_queue(
        request: Request,
        status: Optional[str] = Query(None, description="Filter by status: pending, resolved, rejected"),
        content_type: Optional[str] = Query(None, description="Filter by content type: story, prompt, narration, visual"),
        limit: int = Query(20, ge=1, le=100, description="Number of items to return per page"),
        offset: int = Query(0, ge=0, description="Number of items to skip"),
        admin_user_id: UUID = Depends(get_admin_user_id),
    ) -> ModerationQueueListResponse:
        """
        List moderation queue items (admin only).
        
        Args:
            status: Optional filter by status
            content_type: Optional filter by content type
            limit: Maximum number of items to return (1-100, default: 20)
            offset: Number of items to skip for pagination (default: 0)
            admin_user_id: Authenticated admin user ID (from JWT token)
            
        Returns:
            Paginated list of moderation queue items
        """
        if not supabase_client:
            raise HTTPException(
                status_code=503,
                detail="Supabase not configured. Moderation queue is unavailable.",
            )
        
        try:
            # Get moderation items with pagination (fetch limit+1 to check if there are more)
            items = supabase_client.get_moderation_items(
                status=status,
                content_type=content_type,
                limit=limit + 1,  # Fetch one extra to check if there are more
                offset=offset,
                order_by="created_at",
                ascending=False,
            )
            
            # Check if there are more items
            has_more = len(items) > limit
            if has_more:
                items = items[:limit]  # Remove the extra item
            
            # Convert to response models
            moderation_items = []
            for item in items:
                violations = [
                    GuardrailViolationSchema(category=v.get("category", ""), detail=v.get("detail", ""))
                    for v in item.get("violations", [])
                ]
                moderation_items.append(
                    ModerationQueueItem(
                        id=UUID(item["id"]),
                        status=item["status"],
                        violations=violations,
                        content=item["content"],
                        content_type=item["content_type"],
                        user_id=UUID(item["user_id"]) if item.get("user_id") else None,
                        session_id=UUID(item["session_id"]) if item.get("session_id") else None,
                        resolved_by=UUID(item["resolved_by"]) if item.get("resolved_by") else None,
                        resolved_at=datetime.fromisoformat(item["resolved_at"].replace("Z", "+00:00")) if item.get("resolved_at") else None,
                        resolution_notes=item.get("resolution_notes"),
                        audit_log=item.get("audit_log", []),
                        created_at=datetime.fromisoformat(item["created_at"].replace("Z", "+00:00")),
                        updated_at=datetime.fromisoformat(item["updated_at"].replace("Z", "+00:00")),
                    )
                )
            
            # For total count, we'll estimate based on current page
            total_estimate = offset + len(moderation_items) + (1 if has_more else 0)
            
            log_event(
                logging.INFO,
                "moderation.list",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                status=status,
                content_type=content_type,
                count=len(moderation_items),
            )
            
            return ModerationQueueListResponse(
                items=moderation_items,
                total=total_estimate,
                limit=limit,
                offset=offset,
                has_more=has_more,
            )
        
        except HTTPException:
            raise
        except Exception as e:
            log_event(
                logging.ERROR,
                "moderation.list.error",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to fetch moderation queue: {str(e)}",
            )

    @app.get("/api/v1/admin/moderation/{item_id}", response_model=ModerationQueueItem)
    async def get_moderation_item(
        request: Request,
        item_id: UUID,
        admin_user_id: UUID = Depends(get_admin_user_id),
    ) -> ModerationQueueItem:
        """
        Get a specific moderation queue item (admin only).
        
        Args:
            item_id: UUID of the moderation queue item
            admin_user_id: Authenticated admin user ID (from JWT token)
            
        Returns:
            Moderation queue item
        """
        if not supabase_client:
            raise HTTPException(
                status_code=503,
                detail="Supabase not configured. Moderation queue is unavailable.",
            )
        
        try:
            item = supabase_client.get_moderation_item(item_id)
            if not item:
                raise HTTPException(
                    status_code=404,
                    detail=f"Moderation item {item_id} not found",
                )
            
            violations = [
                GuardrailViolationSchema(category=v.get("category", ""), detail=v.get("detail", ""))
                for v in item.get("violations", [])
            ]
            
            return ModerationQueueItem(
                id=UUID(item["id"]),
                status=item["status"],
                violations=violations,
                content=item["content"],
                content_type=item["content_type"],
                user_id=UUID(item["user_id"]) if item.get("user_id") else None,
                session_id=UUID(item["session_id"]) if item.get("session_id") else None,
                resolved_by=UUID(item["resolved_by"]) if item.get("resolved_by") else None,
                resolved_at=datetime.fromisoformat(item["resolved_at"].replace("Z", "+00:00")) if item.get("resolved_at") else None,
                resolution_notes=item.get("resolution_notes"),
                audit_log=item.get("audit_log", []),
                created_at=datetime.fromisoformat(item["created_at"].replace("Z", "+00:00")),
                updated_at=datetime.fromisoformat(item["updated_at"].replace("Z", "+00:00")),
            )
        
        except HTTPException:
            raise
        except Exception as e:
            log_event(
                logging.ERROR,
                "moderation.get.error",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                item_id=str(item_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to fetch moderation item: {str(e)}",
            )

    @app.post("/api/v1/admin/moderation/{item_id}/resolve", response_model=ModerationQueueItem)
    async def resolve_moderation_item(
        request: Request,
        item_id: UUID,
        payload: ResolveModerationRequest,
        admin_user_id: UUID = Depends(get_admin_user_id),
    ) -> ModerationQueueItem:
        """
        Resolve a moderation queue item (admin only).
        
        Args:
            item_id: UUID of the moderation queue item
            payload: Resolution request with resolution status and optional notes
            admin_user_id: Authenticated admin user ID (from JWT token)
            
        Returns:
            Updated moderation queue item
        """
        if not supabase_client:
            raise HTTPException(
                status_code=503,
                detail="Supabase not configured. Moderation queue is unavailable.",
            )
        
        try:
            # Resolve the item
            updated_item = supabase_client.resolve_moderation_item(
                item_id=item_id,
                resolved_by=admin_user_id,
                resolution=payload.resolution,
                notes=payload.notes,
            )
            
            violations = [
                GuardrailViolationSchema(category=v.get("category", ""), detail=v.get("detail", ""))
                for v in updated_item.get("violations", [])
            ]
            
            log_event(
                logging.INFO,
                "moderation.resolve",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                item_id=str(item_id),
                resolution=payload.resolution,
            )
            
            return ModerationQueueItem(
                id=UUID(updated_item["id"]),
                status=updated_item["status"],
                violations=violations,
                content=updated_item["content"],
                content_type=updated_item["content_type"],
                user_id=UUID(updated_item["user_id"]) if updated_item.get("user_id") else None,
                session_id=UUID(updated_item["session_id"]) if updated_item.get("session_id") else None,
                resolved_by=UUID(updated_item["resolved_by"]) if updated_item.get("resolved_by") else None,
                resolved_at=datetime.fromisoformat(updated_item["resolved_at"].replace("Z", "+00:00")) if updated_item.get("resolved_at") else None,
                resolution_notes=updated_item.get("resolution_notes"),
                audit_log=updated_item.get("audit_log", []),
                created_at=datetime.fromisoformat(updated_item["created_at"].replace("Z", "+00:00")),
                updated_at=datetime.fromisoformat(updated_item["updated_at"].replace("Z", "+00:00")),
            )
        
        except ValueError as e:
            raise HTTPException(
                status_code=400,
                detail=str(e),
            )
        except HTTPException:
            raise
        except Exception as e:
            log_event(
                logging.ERROR,
                "moderation.resolve.error",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                item_id=str(item_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to resolve moderation item: {str(e)}",
            )

    # ============================================================================
    # Admin Endpoints - Asset Management
    # ============================================================================

    @app.post("/api/v1/admin/purge-assets")
    async def manual_purge_assets(
        request: Request,
        days_old: int = Query(7, ge=1, le=365, description="Number of days after which assets are considered expired"),
        admin_user_id: UUID = Depends(get_admin_user_id),
    ) -> dict[str, Any]:
        """
        Manually trigger asset purge job (admin only).
        
        This endpoint allows admins to manually trigger the asset purge process
        for testing or immediate cleanup.
        
        Args:
            days_old: Number of days after which assets are considered expired (default: 7)
            admin_user_id: Authenticated admin user ID (from JWT token)
            
        Returns:
            Dictionary with purge statistics
        """
        if not supabase_client:
            raise HTTPException(
                status_code=503,
                detail="Supabase not configured. Asset purge is unavailable.",
            )
        
        try:
            log_event(
                logging.INFO,
                "purge.manual.start",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                days_old=days_old,
            )
            
            stats = supabase_client.purge_expired_assets(days_old=days_old)
            
            log_event(
                logging.INFO,
                "purge.manual.complete",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                days_old=days_old,
                assets_found=stats["assets_found"],
                assets_deleted=stats["assets_deleted"],
                storage_deleted=stats["storage_deleted"],
                storage_errors=stats["storage_errors"],
            )
            
            return {
                "status": "success",
                "retention_days": days_old,
                "stats": stats,
            }
        
        except Exception as e:
            log_event(
                logging.ERROR,
                "purge.manual.error",
                request_id=getattr(request.state, "request_id", None),
                admin_user_id=str(admin_user_id),
                days_old=days_old,
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to purge assets: {str(e)}",
            )

    # ============================================================================
    # Subscription Endpoints
    # ============================================================================

    @app.get("/api/v1/subscription", response_model=SubscriptionResponse)
    async def get_subscription(
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
    ) -> SubscriptionResponse:
        """
        Get user's current subscription.

        Args:
            user_id: Authenticated user ID (from JWT token)

        Returns:
            User's subscription information
        """
        if not subscription_service:
            raise HTTPException(
                status_code=503,
                detail="Subscription service not configured.",
            )

        try:
            subscription = subscription_service.get_user_subscription(user_id)
            if not subscription:
                # Return default free tier subscription
                return SubscriptionResponse(
                    id=uuid4(),
                    user_id=user_id,
                    tier="free",
                    status="active",
                    current_period_start=datetime.utcnow(),
                    current_period_end=datetime.utcnow() + timedelta(days=365),
                    cancel_at_period_end=False,
                    cancelled_at=None,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )

            return SubscriptionResponse(
                id=UUID(subscription["id"]),
                user_id=UUID(subscription["user_id"]),
                tier=subscription["tier"],
                status=subscription["status"],
                current_period_start=datetime.fromisoformat(
                    subscription["current_period_start"].replace("Z", "+00:00")
                ),
                current_period_end=datetime.fromisoformat(
                    subscription["current_period_end"].replace("Z", "+00:00")
                ),
                cancel_at_period_end=subscription.get("cancel_at_period_end", False),
                cancelled_at=datetime.fromisoformat(subscription["cancelled_at"].replace("Z", "+00:00"))
                if subscription.get("cancelled_at")
                else None,
                created_at=datetime.fromisoformat(subscription["created_at"].replace("Z", "+00:00")),
                updated_at=datetime.fromisoformat(subscription["updated_at"].replace("Z", "+00:00")),
            )
        except Exception as e:
            log_event(
                logging.ERROR,
                "subscription.get.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to fetch subscription: {str(e)}",
            )

    @app.get("/api/v1/subscription/quota", response_model=UsageQuotaResponse)
    async def get_usage_quota(
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
    ) -> UsageQuotaResponse:
        """
        Get user's usage quota and current count.

        Args:
            user_id: Authenticated user ID (from JWT token)

        Returns:
            Usage quota information
        """
        if not subscription_service:
            raise HTTPException(
                status_code=503,
                detail="Subscription service not configured.",
            )

        try:
            tier = subscription_service.get_user_tier(user_id)
            quota = subscription_service.get_user_quota(user_id)
            current_count = subscription_service.get_user_story_count(user_id, "weekly")
            can_generate, error_message = subscription_service.can_generate_story(user_id)

            return UsageQuotaResponse(
                tier=tier,
                quota=quota,
                current_count=current_count,
                period_type="weekly",
                can_generate=can_generate,
                error_message=error_message,
            )
        except Exception as e:
            log_event(
                logging.ERROR,
                "subscription.quota.get.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to fetch usage quota: {str(e)}",
            )

    @app.post("/api/v1/subscription", response_model=SubscriptionResponse)
    async def create_subscription(
        payload: CreateSubscriptionRequest,
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
    ) -> SubscriptionResponse:
        """
        Create or update user subscription.

        Args:
            payload: Subscription creation request
            user_id: Authenticated user ID (from JWT token)

        Returns:
            Created or updated subscription
        """
        if not subscription_service:
            raise HTTPException(
                status_code=503,
                detail="Subscription service not configured.",
            )

        try:
            subscription = subscription_service.create_or_update_subscription(
                user_id=user_id,
                tier=payload.tier,
                stripe_subscription_id=payload.stripe_subscription_id,
                stripe_customer_id=payload.stripe_customer_id,
                revenuecat_user_id=payload.revenuecat_user_id,
                revenuecat_entitlement_id=payload.revenuecat_entitlement_id,
            )

            return SubscriptionResponse(
                id=UUID(subscription["id"]),
                user_id=UUID(subscription["user_id"]),
                tier=subscription["tier"],
                status=subscription["status"],
                current_period_start=datetime.fromisoformat(
                    subscription["current_period_start"].replace("Z", "+00:00")
                ),
                current_period_end=datetime.fromisoformat(
                    subscription["current_period_end"].replace("Z", "+00:00")
                ),
                cancel_at_period_end=subscription.get("cancel_at_period_end", False),
                cancelled_at=datetime.fromisoformat(subscription["cancelled_at"].replace("Z", "+00:00"))
                if subscription.get("cancelled_at")
                else None,
                created_at=datetime.fromisoformat(subscription["created_at"].replace("Z", "+00:00")),
                updated_at=datetime.fromisoformat(subscription["updated_at"].replace("Z", "+00:00")),
            )
        except Exception as e:
            log_event(
                logging.ERROR,
                "subscription.create.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to create subscription: {str(e)}",
            )

    @app.post("/api/v1/subscription/cancel", response_model=SubscriptionResponse)
    async def cancel_subscription(
        payload: CancelSubscriptionRequest,
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
    ) -> SubscriptionResponse:
        """
        Cancel user subscription.

        Args:
            payload: Cancellation request
            user_id: Authenticated user ID (from JWT token)

        Returns:
            Updated subscription
        """
        if not subscription_service:
            raise HTTPException(
                status_code=503,
                detail="Subscription service not configured.",
            )

        try:
            subscription = subscription_service.cancel_subscription(
                user_id=user_id,
                cancel_at_period_end=payload.cancel_at_period_end,
            )

            return SubscriptionResponse(
                id=UUID(subscription["id"]),
                user_id=UUID(subscription["user_id"]),
                tier=subscription["tier"],
                status=subscription["status"],
                current_period_start=datetime.fromisoformat(
                    subscription["current_period_start"].replace("Z", "+00:00")
                ),
                current_period_end=datetime.fromisoformat(
                    subscription["current_period_end"].replace("Z", "+00:00")
                ),
                cancel_at_period_end=subscription.get("cancel_at_period_end", False),
                cancelled_at=datetime.fromisoformat(subscription["cancelled_at"].replace("Z", "+00:00"))
                if subscription.get("cancelled_at")
                else None,
                created_at=datetime.fromisoformat(subscription["created_at"].replace("Z", "+00:00")),
                updated_at=datetime.fromisoformat(subscription["updated_at"].replace("Z", "+00:00")),
            )
        except Exception as e:
            log_event(
                logging.ERROR,
                "subscription.cancel.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to cancel subscription: {str(e)}",
            )

    # ============================================================================
    # Notification Endpoints
    # ============================================================================

    @app.post("/api/v1/notifications/register")
    async def register_notification_token(
        payload: RegisterNotificationTokenRequest,
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
    ) -> dict:
        """
        Register a notification token for push notifications.

        Args:
            payload: Token registration request
            user_id: Authenticated user ID (from JWT token)

        Returns:
            Success message
        """
        if not notification_service:
            raise HTTPException(
                status_code=503,
                detail="Notification service not configured.",
            )

        try:
            notification_service.register_token(
                user_id=user_id,
                token=payload.token,
                platform=payload.platform,
                device_id=payload.device_id,
            )
            return {"status": "success", "message": "Token registered"}
        except Exception as e:
            log_event(
                logging.ERROR,
                "notification.register.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to register token: {str(e)}",
            )

    @app.get("/api/v1/notifications/preferences", response_model=NotificationPreferencesResponse)
    async def get_notification_preferences(
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
    ) -> NotificationPreferencesResponse:
        """
        Get user's notification preferences.

        Args:
            user_id: Authenticated user ID (from JWT token)

        Returns:
            Notification preferences
        """
        if not notification_service:
            raise HTTPException(
                status_code=503,
                detail="Notification service not configured.",
            )

        try:
            preferences = notification_service.get_notification_preferences(user_id)
            if not preferences:
                # Return defaults
                return NotificationPreferencesResponse(
                    id=uuid4(),
                    user_id=user_id,
                    bedtime_reminders_enabled=True,
                    bedtime_reminder_time=None,
                    streak_notifications_enabled=True,
                    story_recommendations_enabled=True,
                    weekly_summary_enabled=True,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )

            return NotificationPreferencesResponse(
                id=UUID(preferences["id"]),
                user_id=UUID(preferences["user_id"]),
                bedtime_reminders_enabled=preferences.get("bedtime_reminders_enabled", True),
                bedtime_reminder_time=preferences.get("bedtime_reminder_time"),
                streak_notifications_enabled=preferences.get("streak_notifications_enabled", True),
                story_recommendations_enabled=preferences.get("story_recommendations_enabled", True),
                weekly_summary_enabled=preferences.get("weekly_summary_enabled", True),
                created_at=datetime.fromisoformat(preferences["created_at"].replace("Z", "+00:00")),
                updated_at=datetime.fromisoformat(preferences["updated_at"].replace("Z", "+00:00")),
            )
        except Exception as e:
            log_event(
                logging.ERROR,
                "notification.preferences.get.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to fetch preferences: {str(e)}",
            )

    @app.put("/api/v1/notifications/preferences", response_model=NotificationPreferencesResponse)
    async def update_notification_preferences(
        payload: UpdateNotificationPreferencesRequest,
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
    ) -> NotificationPreferencesResponse:
        """
        Update user's notification preferences.

        Args:
            payload: Updated preferences
            user_id: Authenticated user ID (from JWT token)

        Returns:
            Updated notification preferences
        """
        if not notification_service:
            raise HTTPException(
                status_code=503,
                detail="Notification service not configured.",
            )

        try:
            from datetime import time as dt_time

            bedtime_time = None
            if payload.bedtime_reminder_time:
                try:
                    bedtime_time = dt_time.fromisoformat(payload.bedtime_reminder_time)
                except ValueError:
                    raise HTTPException(
                        status_code=400,
                        detail="Invalid bedtime_reminder_time format. Use HH:MM format.",
                    )

            preferences = notification_service.update_notification_preferences(
                user_id=user_id,
                bedtime_reminders_enabled=payload.bedtime_reminders_enabled,
                bedtime_reminder_time=bedtime_time,
                streak_notifications_enabled=payload.streak_notifications_enabled,
                story_recommendations_enabled=payload.story_recommendations_enabled,
                weekly_summary_enabled=payload.weekly_summary_enabled,
            )

            return NotificationPreferencesResponse(
                id=UUID(preferences["id"]),
                user_id=UUID(preferences["user_id"]),
                bedtime_reminders_enabled=preferences.get("bedtime_reminders_enabled", True),
                bedtime_reminder_time=preferences.get("bedtime_reminder_time"),
                streak_notifications_enabled=preferences.get("streak_notifications_enabled", True),
                story_recommendations_enabled=preferences.get("story_recommendations_enabled", True),
                weekly_summary_enabled=preferences.get("weekly_summary_enabled", True),
                created_at=datetime.fromisoformat(preferences["created_at"].replace("Z", "+00:00")),
                updated_at=datetime.fromisoformat(preferences["updated_at"].replace("Z", "+00:00")),
            )
        except HTTPException:
            raise
        except Exception as e:
            log_event(
                logging.ERROR,
                "notification.preferences.update.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to update preferences: {str(e)}",
            )

    # ============================================================================
    # Recommendation Endpoints
    # ============================================================================

    @app.get("/api/v1/recommendations")
    async def get_recommendations(
        request: Request,
        user_id: UUID = Depends(get_authenticated_user_id),
        limit: int = Query(5, ge=1, le=20, description="Maximum number of recommendations"),
        time_of_day: Optional[str] = Query(None, description="Time context: morning, afternoon, evening, night"),
    ) -> dict:
        """
        Get personalized theme recommendations based on user feedback.

        Args:
            user_id: Authenticated user ID (from JWT token)
            limit: Maximum number of recommendations (1-20, default: 5)
            time_of_day: Optional time context for recommendations

        Returns:
            Dictionary with recommendations list
        """
        if not recommendation_engine:
            raise HTTPException(
                status_code=503,
                detail="Recommendation service not configured.",
            )

        try:
            recommendations = recommendation_engine.get_recommended_themes(
                user_id=user_id,
                limit=limit,
                time_of_day=time_of_day,
            )

            log_event(
                logging.INFO,
                "recommendations.get.success",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                count=len(recommendations),
            )

            return {"recommendations": recommendations}
        except Exception as e:
            log_event(
                logging.ERROR,
                "recommendations.get.error",
                request_id=getattr(request.state, "request_id", None),
                user_id=str(user_id),
                error=str(e),
            )
            raise HTTPException(
                status_code=500,
                detail=f"Failed to fetch recommendations: {str(e)}",
            )

    return app


settings = get_settings()
app = create_app(settings)


