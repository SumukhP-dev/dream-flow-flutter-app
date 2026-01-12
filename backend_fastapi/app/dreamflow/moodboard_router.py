"""Moodboard inspiration endpoints."""

from __future__ import annotations

import base64
import hashlib
import logging
from typing import List

from fastapi import APIRouter, HTTPException, status

from ..core.guardrails import ContentGuard, GuardrailError, MoodboardInputInspector
from ..core.prompting import PromptBuilder, PromptBuilderMode, PromptContext
from ..core.services import VisualGenerator
from ..shared.config import Settings, get_settings
from ..shared.supabase_client import SupabaseClient
from .schemas import MoodboardInspirationRequest, MoodboardUploadResponse


logger = logging.getLogger(__name__)


class MoodboardGenerator:
    """AI-assisted pipeline that turns caregiver inspiration into gentle loops."""

    def __init__(
        self, supabase_client: SupabaseClient | None, settings: Settings | None = None
    ):
        self.supabase = supabase_client
        self.settings = settings or get_settings()
        self.prompt_builder = PromptBuilder(mode=PromptBuilderMode.BEDTIME_STORY)
        self.visual_generator = VisualGenerator(prompt_builder=self.prompt_builder)
        self.content_guard = ContentGuard()
        self.inspector = MoodboardInputInspector(
            max_upload_bytes=self.settings.moodboard_max_upload_mb * 1024 * 1024,
            guard=self.content_guard
            if self.settings.moodboard_guardrails_enabled
            else None,
            coppa_face_filter=self.settings.coppa_face_filter_enabled,
        )

    async def process(
        self, payload: MoodboardInspirationRequest
    ) -> MoodboardUploadResponse:
        try:
            inspection = self.inspector.inspect(payload)
        except GuardrailError as exc:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=[violation.detail for violation in exc.violations],
            ) from exc
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc

        preview = self._resolve_preview(payload)
        requires_moderation = (
            inspection.requires_moderation or self._requires_moderation(payload)
        )

        frames = await self._generate_frames(payload, fallback_seed=preview)

        if self.supabase and payload.session_id:
            self._persist_frames(
                payload.session_id, frames, preview, requires_moderation
            )

        return MoodboardUploadResponse(
            preview_url=preview,
            frames=frames,
            requires_moderation=requires_moderation,
        )

    def _resolve_preview(self, payload: MoodboardInspirationRequest) -> str:
        if payload.data:
            # Ensure base64 payload is valid
            try:
                base64.b64decode(payload.data, validate=True)
            except Exception as exc:
                raise HTTPException(
                    status_code=400, detail="Invalid base64 payload"
                ) from exc
            return f"data:image/png;base64,{payload.data}"

        caption = (payload.caption or "Moodboard").strip() or "Moodboard"
        return self._placeholder_url(caption, index=0)

    async def _generate_frames(
        self, payload: MoodboardInspirationRequest, fallback_seed: str
    ) -> List[str]:
        script = self._compose_script(payload)
        context = PromptContext(
            prompt=payload.caption or "Dreamy caregiver inspiration",
            theme=payload.caption or "soothing ritual",
            target_length=180,
            profile=None,
        )
        storage_prefix = None
        if payload.session_id:
            storage_prefix = f"moodboard/{payload.session_id}"

        try:
            model_frames = await self.visual_generator.create_frames(
                story=script,
                context=context,
                num_scenes=3,
                supabase_client=self.supabase,
                storage_prefix=storage_prefix,
            )
            if model_frames:
                return model_frames
        except Exception as exc:  # pragma: no cover - defensive fallback
            logger.warning("Moodboard model fallback triggered: %s", exc)

        return self._create_frames(payload, seed=fallback_seed)

    def _compose_script(self, payload: MoodboardInspirationRequest) -> str:
        caption = (payload.caption or "soft lantern walk").strip()
        palette = self._derive_palette(caption)
        palette_line = ", ".join(palette)
        stroke_notes = self._stroke_notes(payload)
        inspiration_type = (
            "caregiver photo" if payload.type == "photo" else "gentle sketch"
        )

        paragraphs = [
            f"{caption} is interpreted as a {inspiration_type} that leans into hues of {palette_line}.",
            f"The caregiver provided strokes suggest {stroke_notes or 'calm arcs and sleepy comets'}, which we translate into looping ambient frames.",
            "Keep lines rounded, avoid harsh contrast, and favor kid-friendly textures that drift slowly like lantern light.",
        ]
        return "\n".join(paragraphs)

    def _stroke_notes(self, payload: MoodboardInspirationRequest) -> str:
        if not payload.strokes:
            return ""
        colors = {stroke.color for stroke in payload.strokes if stroke.color}
        if not colors:
            return ""
        if len(colors) == 1:
            # Get the single color safely without using next()
            single_color = list(colors)[0]
            return f"a monochrome wash of #{single_color}"
        return "layered tones of " + ", ".join(
            f"#{color}" for color in list(colors)[:4]
        )

    def _create_frames(
        self, payload: MoodboardInspirationRequest, seed: str
    ) -> List[str]:
        caption = (payload.caption or "cozy night").lower()
        palette = self._derive_palette(seed + caption)
        frames = []
        for idx, color in enumerate(palette):
            label = caption.replace(" ", "+")[:32] or "dream"
            frames.append(
                f"https://placehold.co/600x400/{color}/f1f5f9.png?text={label}+{idx + 1}"
            )
        return frames

    def _derive_palette(self, seed: str) -> List[str]:
        digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()
        palette = []
        for idx in range(0, 18, 6):
            chunk = digest[idx : idx + 6]
            palette.append(chunk)
        return palette[:3]

    def _requires_moderation(self, payload: MoodboardInspirationRequest) -> bool:
        text = (payload.caption or "").lower()
        unsafe_keywords = {"weapon", "blood", "battle"}
        return any(keyword in text for keyword in unsafe_keywords)

    def _persist_frames(
        self,
        session_id,
        frames: List[str],
        preview: str,
        requires_moderation: bool,
    ) -> None:
        if not self.supabase:
            return
        try:
            payload = {
                "session_id": str(session_id),
                "preview_url": preview,
                "frames": frames,
                "requires_moderation": requires_moderation,
            }
            self.supabase.client.table("moodboard_loops").upsert(
                payload, on_conflict="session_id"
            ).execute()
        except Exception:
            # Non-fatal: cache locally only
            pass

    def _placeholder_url(self, label: str, index: int) -> str:
        clean = label.replace(" ", "+")[:30] or "mood"
        return (
            f"https://placehold.co/400x240/312e81/ffffff.png?text={clean}+{index + 1}"
        )


def create_moodboard_router(supabase_client: SupabaseClient | None) -> APIRouter:
    router = APIRouter(prefix="/api/v1/moodboard", tags=["moodboard"])
    generator = MoodboardGenerator(supabase_client)

    @router.post(
        "/inspiration",
        response_model=MoodboardUploadResponse,
        status_code=status.HTTP_201_CREATED,
    )
    async def upload_inspiration(
        payload: MoodboardInspirationRequest,
    ) -> MoodboardUploadResponse:
        """Capture an inspiration asset and return generated frames."""
        return await generator.process(payload)

    return router
