"""Smart speaker orchestration endpoints."""

from __future__ import annotations

import logging
from typing import Dict, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, HTTPException, status

from .schemas import SmartSceneRunRequest
from ..shared.supabase_client import SupabaseClient

logger = logging.getLogger("dream_flow.smart_home")


class SmartSceneOrchestrator:
    """Dispatch smart home scenes across Alexa, Google Home, and HomeKit."""

    DEFAULT_SCENES: Dict[str, dict] = {
        "scene_family": {
            "name": "Family Hearth",
            "actions": [
                {"device_type": "lights", "value": "40%"},
                {"device_type": "diffuser", "value": "lavender_low"},
                {"device_type": "sound", "value": "gentle_chimes"},
            ],
        },
        "scene_travel": {
            "name": "Travel Comfort",
            "actions": [
                {"device_type": "lights", "value": "warm_glow"},
                {"device_type": "sound", "value": "voyager_lullaby"},
            ],
        },
    }

    def __init__(self, supabase_client: SupabaseClient | None):
        self.supabase = supabase_client

    def trigger(
        self, scene_id: str, user_id: Optional[UUID], source: str
    ) -> dict[str, str]:
        scene = self._load_scene(scene_id, user_id)
        if not scene:
            raise HTTPException(status_code=404, detail=f"Scene {scene_id} not found")

        self._log_activity(scene_id, user_id, source)
        # Integrations with vendor APIs would be invoked here. For now we log + acknowledge.
        logger.info(
            "smart_scene.triggered %s source=%s user=%s", scene_id, source, user_id
        )
        return {"status": "queued", "scene": scene.get("name", scene_id)}

    def _load_scene(self, scene_id: str, user_id: Optional[UUID]):
        if not self.supabase:
            return self.DEFAULT_SCENES.get(scene_id)
        try:
            query = (
                self.supabase.client.table("smart_scene_presets")
                .select("*")
                .eq("id", scene_id)
                .limit(1)
            )
            if user_id:
                query = query.eq("user_id", str(user_id))
            response = query.execute()
            if response.data:
                return response.data[0]
        except Exception as exc:
            logger.debug("Unable to fetch smart scene %s: %s", scene_id, exc)
        return self.DEFAULT_SCENES.get(scene_id)

    def _log_activity(
        self, scene_id: str, user_id: Optional[UUID], source: str
    ) -> None:
        if not self.supabase:
            return
        payload = {
            "id": str(uuid4()),
            "scene_id": scene_id,
            "user_id": str(user_id) if user_id else None,
            "trigger_source": source,
        }
        try:
            self.supabase.client.table("smart_scene_activity").insert(payload).execute()
        except Exception as exc:
            logger.warning("Failed to log smart scene activity: %s", exc)


def create_smart_home_router(supabase_client: SupabaseClient | None) -> APIRouter:
    router = APIRouter(prefix="/api/v1/smart-scenes", tags=["smart-home"])
    orchestrator = SmartSceneOrchestrator(supabase_client)

    @router.post("/run", status_code=status.HTTP_202_ACCEPTED)
    async def run_scene(payload: SmartSceneRunRequest) -> dict[str, str]:
        """Trigger a configured smart scene."""
        return orchestrator.trigger(
            scene_id=payload.scene_id,
            user_id=payload.user_id,
            source=payload.trigger_source or "app",
        )

    return router
