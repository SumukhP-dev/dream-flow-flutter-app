"""Maestro insights aggregation service."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from statistics import mean
from typing import Any, Optional
from uuid import UUID, uuid4

from ..shared.supabase_client import SupabaseClient

logger = logging.getLogger("dream_flow.maestro")


DEFAULT_TIP = {
    "title": "Tonight’s Micro-Adjustment",
    "description": "Nova settles 12 minutes faster when wind-down starts before 8:15 pm.",
    "micro_adjustment": "Dim the nursery lights to 35% and layer the lavender diffuser 15 minutes earlier.",
    "confidence": 0.86,
}

DEFAULT_TRENDS = [
    {"label": "Bedtime drift", "delta_minutes": -8, "direction": "down"},
    {"label": "Energy settling", "delta_minutes": 5, "direction": "up"},
    {"label": "Travel recovery", "delta_minutes": 2, "direction": "steady"},
]

DEFAULT_ENVIRONMENT = {
    "lighting_score": 0.78,
    "scent_score": 0.64,
    "notes": [
        "Soft amber channel keeps heart rate variability stable.",
        "Diffuser pauses every 6 minutes avoid sensory overload.",
    ],
}

DEFAULT_ACTIONS = [
    {
        "id": "lights_dim",
        "label": "Dim nursery lights",
        "icon": "💡",
        "min": 10,
        "max": 80,
        "value": 40,
    },
    {"id": "diffuser", "label": "Lavender diffuser", "icon": "🌫️"},
    {"id": "soundscape", "label": "Travel comfort scene", "icon": "🎧"},
]


class MaestroInsightsService:
    """Aggregate nightly maestro insights from Supabase analytics tables."""

    def __init__(self, supabase_client: Optional[SupabaseClient]):
        self.supabase = supabase_client

    def get_insights(self, user_id: Optional[UUID] = None) -> dict[str, Any]:
        sessions = self._fetch_recent_sessions(user_id)
        contexts = self._fetch_session_contexts(user_id)
        reflections = self._fetch_recent_reflections(user_id)

        streak_days = self._calculate_streak(sessions)
        has_travel_shift = self._detect_travel_shift(user_id)

        tip = self._build_tip(sessions, reflections)
        trends = self._build_trends(sessions)
        environment = self._build_environment(contexts)
        quick_actions = self._build_quick_actions(environment)

        insights = {
            "nightly_tip": tip,
            "streaks": trends,
            "environment": environment,
            "quick_actions": quick_actions,
            "streak_days": streak_days,
            "has_travel_shift": has_travel_shift,
        }

        self._persist_summary(user_id, insights)
        return insights

    def log_quick_action(
        self,
        action_id: str,
        slider_value: Optional[float] = None,
        user_id: Optional[UUID] = None,
    ) -> None:
        """Audit every maestro quick action trigger for COPPA compliance."""
        if not self.supabase:
            logger.info(
                "maestro.quick_action (no-supabase): %s %.2f",
                action_id,
                slider_value or -1,
            )
            return

        payload = {
            "id": str(uuid4()),
            "action_id": action_id,
            "user_id": str(user_id) if user_id else None,
            "slider_value": slider_value,
        }
        try:
            self.supabase.client.table("maestro_coach_activity").insert(
                payload
            ).execute()
        except Exception as exc:  # pragma: no cover - telemetry only
            logger.warning("Failed to log maestro quick action: %s", exc)

    # --------------------------------------------------------------------- #
    # Internal helpers
    # --------------------------------------------------------------------- #

    def _fetch_recent_sessions(self, user_id: Optional[UUID]) -> list[dict[str, Any]]:
        if not self.supabase or not user_id:
            return []
        try:
            return self.supabase.get_user_sessions(user_id=user_id, limit=14)
        except Exception as exc:  # pragma: no cover - remote failure
            logger.warning("Failed to load sessions for maestro insights: %s", exc)
            return []

    def _fetch_session_contexts(self, user_id: Optional[UUID]) -> list[dict[str, Any]]:
        if not self.supabase:
            return []
        try:
            query = (
                self.supabase.client.table("session_contexts")
                .select("*")
                .order("created_at", desc=True)
                .limit(12)
            )
            if user_id:
                query = query.eq("user_id", str(user_id))
            response = query.execute()
            return response.data or []
        except Exception as exc:
            logger.debug("No session_contexts available: %s", exc)
            return []

    def _fetch_recent_reflections(
        self, user_id: Optional[UUID]
    ) -> list[dict[str, Any]]:
        if not self.supabase:
            return []
        try:
            query = (
                self.supabase.client.table("story_reflections")
                .select("*")
                .order("created_at", desc=True)
                .limit(30)
            )
            if user_id:
                query = query.eq("user_id", str(user_id))
            response = query.execute()
            return response.data or []
        except Exception:
            return []

    def _calculate_streak(self, sessions: list[dict[str, Any]]) -> int:
        if not sessions:
            return 0
        dates = []
        for session in sessions:
            raw = session.get("created_at")
            if not raw:
                continue
            try:
                dates.append(self._parse_iso(raw).date())
            except ValueError:
                continue
        if not dates:
            return 0
        dates = sorted(set(dates), reverse=True)
        streak = 1
        for idx in range(1, len(dates)):
            if (dates[idx - 1] - dates[idx]) == timedelta(days=1):
                streak += 1
            else:
                break
        return streak

    def _detect_travel_shift(self, user_id: Optional[UUID]) -> bool:
        if not self.supabase or not user_id:
            return False
        try:
            today = datetime.now(timezone.utc).date()
            response = (
                self.supabase.client.table("travel_itineraries")
                .select("start_date,end_date,timezone_offset")
                .eq("user_id", str(user_id))
                .gte("end_date", today.isoformat())
                .order("start_date", desc=True)
                .limit(1)
                .execute()
            )
            itinerary = (response.data or [None])[0]
            if not itinerary:
                return False
            tz = itinerary.get("timezone_offset") or 0
            return abs(int(tz)) >= 120  # minutes difference
        except Exception:
            return False

    def _build_tip(
        self, sessions: list[dict[str, Any]], reflections: list[dict[str, Any]]
    ) -> dict[str, Any]:
        if not sessions:
            return DEFAULT_TIP
        latest = sessions[0]
        theme = latest.get("theme") or "Lantern trail"
        avg_mood = self._average_mood_delta(reflections)
        description = (
            f"{theme} weeks trend {avg_mood:+.0f} in calmness when you start by "
            f"{self._format_time(latest.get('created_at'))}."
        )
        adjustment = (
            "Layer the diffuser 10 minutes earlier and keep white noise on low hum."
        )
        return {
            "title": "Tonight’s Micro-Adjustment",
            "description": description,
            "micro_adjustment": adjustment,
            "confidence": min(max(0.5 + (avg_mood / 20), 0.55), 0.95),
        }

    def _average_mood_delta(self, reflections: list[dict[str, Any]]) -> float:
        if not reflections:
            return 0
        sentiments = []
        for entry in reflections:
            sentiment = entry.get("sentiment")
            if sentiment is None:
                continue
            try:
                sentiments.append(float(sentiment) * 100)
            except (TypeError, ValueError):
                continue
        return mean(sentiments) if sentiments else 0

    def _build_trends(self, sessions: list[dict[str, Any]]) -> list[dict[str, Any]]:
        if len(sessions) < 2:
            return DEFAULT_TRENDS
        minutes = []
        energy = []
        for session in sessions:
            created = session.get("created_at")
            if created:
                try:
                    minutes.append(
                        self._parse_iso(created).hour * 60
                        + self._parse_iso(created).minute
                    )
                except ValueError:
                    continue
            feedback = session.get("mood_delta")
            if feedback is not None:
                energy.append(float(feedback))
        if not minutes:
            return DEFAULT_TRENDS
        latest = minutes[0]
        avg_rest = mean(minutes[1:]) if len(minutes) > 1 else latest
        drift = latest - avg_rest
        energy_delta = mean(energy[:3]) if energy else 0
        return [
            {
                "label": "Bedtime drift",
                "delta_minutes": round(drift, 1),
                "direction": self._direction(drift),
            },
            {
                "label": "Energy settling",
                "delta_minutes": round(energy_delta, 1),
                "direction": self._direction(energy_delta),
            },
            {"label": "Travel recovery", "delta_minutes": 2.0, "direction": "steady"},
        ]

    def _build_environment(self, contexts: list[dict[str, Any]]) -> dict[str, Any]:
        if not contexts:
            return DEFAULT_ENVIRONMENT
        lighting_scores = []
        scent_scores = []
        notes: list[str] = []
        for context in contexts:
            lighting = context.get("lighting_score")
            scent = context.get("scent_score")
            if lighting is not None:
                try:
                    lighting_scores.append(float(lighting))
                except (TypeError, ValueError):
                    continue
            if scent is not None:
                try:
                    scent_scores.append(float(scent))
                except (TypeError, ValueError):
                    continue
            if context.get("note"):
                notes.append(context["note"])
        return {
            "lighting_score": round(
                mean(lighting_scores)
                if lighting_scores
                else DEFAULT_ENVIRONMENT["lighting_score"],
                2,
            ),
            "scent_score": round(
                mean(scent_scores)
                if scent_scores
                else DEFAULT_ENVIRONMENT["scent_score"],
                2,
            ),
            "notes": notes or DEFAULT_ENVIRONMENT["notes"],
        }

    def _build_quick_actions(self, environment: dict[str, Any]) -> list[dict[str, Any]]:
        slider_value = (
            environment.get("lighting_score", DEFAULT_ENVIRONMENT["lighting_score"])
            * 100
        )
        actions = DEFAULT_ACTIONS.copy()
        actions[0] = {**actions[0], "value": round(slider_value, 1)}
        return actions

    def _persist_summary(
        self, user_id: Optional[UUID], payload: dict[str, Any]
    ) -> None:
        if not self.supabase or not user_id:
            return
        try:
            record = {
                "id": str(uuid4()),
                "user_id": str(user_id),
                "nightly_tip": payload["nightly_tip"],
                "streaks": payload["streaks"],
                "environment": payload["environment"],
                "quick_actions": payload["quick_actions"],
                "streak_days": payload["streak_days"],
            }
            self.supabase.client.table("maestro_insight_summaries").insert(
                record
            ).execute()
        except Exception as exc:  # pragma: no cover - telemetry only
            logger.debug("Unable to persist maestro insights: %s", exc)

    def _direction(self, delta: float) -> str:
        if delta > 1:
            return "up"
        if delta < -1:
            return "down"
        return "steady"

    def _parse_iso(self, value: str) -> datetime:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))

    def _format_time(self, raw: Optional[str]) -> str:
        if not raw:
            return "8:15 pm"
        try:
            dt = self._parse_iso(raw)
            return dt.strftime("%I:%M %p").lstrip("0")
        except ValueError:
            return "8:15 pm"
