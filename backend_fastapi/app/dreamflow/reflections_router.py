"""Narrative reflection endpoints."""

from __future__ import annotations

import collections
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, HTTPException, status

from .schemas import (
    ReflectionCelebrationSchema,
    ReflectionEntryRequest,
    ReflectionEntryResponse,
    ReflectionInsightsResponse,
    ReflectionRecommendationSchema,
    ReflectionTopicSchema,
    ReflectionWeekClusterSchema,
    ReflectionBadgeSchema,
    ReflectionRecapSchema,
)
from ..shared.supabase_client import SupabaseClient


class ReflectionAnalyticsService:
    """Persist reflections and compute lightweight insights."""

    KEYWORDS = {
        "Ocean": {"ocean", "wave", "tide", "sea"},
        "Forest": {"forest", "pine", "owl", "fox"},
        "Travel": {"plane", "train", "hotel", "travel"},
        "Music": {"song", "melody", "piano", "harp"},
    }

    def __init__(self, supabase_client: SupabaseClient | None):
        self.supabase = supabase_client

    def submit_reflection(
        self, payload: ReflectionEntryRequest, user_id: Optional[UUID]
    ) -> ReflectionEntryResponse:
        entry_id = payload.id or uuid4()
        record = {
            "id": str(entry_id),
            "user_id": str(user_id) if user_id else None,
            "session_id": str(payload.session_id) if payload.session_id else None,
            "child_profile_id": str(payload.child_profile_id)
            if payload.child_profile_id
            else None,
            "mood": payload.mood,
            "note": payload.note,
            "transcript": payload.transcript,
            "audio_url": payload.audio_url,
            "sentiment": payload.sentiment,
            "tags": payload.tags,
        }
        created_at = None
        if self.supabase:
            try:
                response = (
                    self.supabase.client.table("story_reflections")
                    .upsert(record, on_conflict="id")
                    .execute()
                )
                created_at = response.data[0]["created_at"] if response.data else None
            except (
                Exception
            ) as exc:  # pragma: no cover - persistence failure should not crash app
                raise HTTPException(
                    status_code=500, detail=f"Unable to store reflection: {exc}"
                ) from exc

        return ReflectionEntryResponse(
            id=entry_id,
            session_id=payload.session_id,
            mood=payload.mood,
            note=payload.note,
            transcript=payload.transcript,
            created_at=self._parse_timestamp(created_at),
        )

    def get_insights(self, user_id: Optional[UUID]) -> ReflectionInsightsResponse:
        entries = self._load_entries(user_id)
        if not entries:
            return ReflectionInsightsResponse(
                dominant_mood="calm",
                streak=0,
                topics=[],
                entries=[],
                weekly_clusters=[],
                recommendations=[],
                celebrations=ReflectionCelebrationSchema(
                    badges=[],
                    weekly_recap=ReflectionRecapSchema(),
                ),
            )

        dominant_mood = self._dominant_mood(entries)
        streak = self._calculate_streak(entries)
        topics = self._extract_topics(entries)

        simplified_entries = [
            ReflectionEntryResponse(
                id=UUID(entry["id"]),
                session_id=UUID(entry["session_id"])
                if entry.get("session_id")
                else None,
                mood=entry.get("mood", "calm"),
                note=entry.get("note"),
                transcript=entry.get("transcript"),
                created_at=self._parse_timestamp(entry.get("created_at")),
            )
            for entry in entries[:15]
        ]

        weekly_clusters = self._build_weekly_clusters(entries)
        recommendations = self._build_recommendations(entries, weekly_clusters)
        celebrations = ReflectionCelebrationSchema(
            badges=self._evaluate_badges(entries, streak, weekly_clusters),
            weekly_recap=self._build_weekly_recap(entries),
        )

        return ReflectionInsightsResponse(
            dominant_mood=dominant_mood,
            streak=streak,
            topics=topics,
            entries=simplified_entries,
            weekly_clusters=weekly_clusters,
            recommendations=recommendations,
            celebrations=celebrations,
        )

    def _load_entries(self, user_id: Optional[UUID]) -> list[dict]:
        if not self.supabase:
            return []
        query = (
            self.supabase.client.table("story_reflections")
            .select("*")
            .order("created_at", desc=True)
            .limit(60)
        )
        if user_id:
            query = query.eq("user_id", str(user_id))
        response = query.execute()
        return response.data or []

    def _dominant_mood(self, entries: list[dict]) -> str:
        counter = collections.Counter(entry.get("mood", "calm") for entry in entries)
        if not counter:
            return "calm"
        return counter.most_common(1)[0][0]

    def _calculate_streak(self, entries: list[dict]) -> int:
        seen_dates = []
        for entry in entries:
            created_at = entry.get("created_at")
            if not created_at:
                continue
            seen_dates.append(self._parse_timestamp(created_at).date())
        if not seen_dates:
            return 0
        seen_dates = sorted(set(seen_dates), reverse=True)
        streak = 1
        for idx in range(1, len(seen_dates)):
            if (seen_dates[idx - 1] - seen_dates[idx]).days == 1:
                streak += 1
            else:
                break
        return streak

    def _extract_topics(self, entries: list[dict]) -> List[ReflectionTopicSchema]:
        topic_counts: dict[str, int] = {}
        for entry in entries:
            for label in self._topics_for_entry(entry):
                topic_counts[label] = topic_counts.get(label, 0) + 1
        return [
            ReflectionTopicSchema(label=label, mentions=count)
            for label, count in sorted(
                topic_counts.items(), key=lambda item: item[1], reverse=True
            )
        ][:3]

    def _topics_for_entry(self, entry: dict) -> list[str]:
        corpus = " ".join(
            filter(None, [entry.get("note"), entry.get("transcript")])
        ).lower()
        matches: list[str] = []
        for label, keywords in self.KEYWORDS.items():
            if any(keyword in corpus for keyword in keywords):
                matches.append(label)
        return matches

    def _build_weekly_clusters(
        self, entries: list[dict]
    ) -> list[ReflectionWeekClusterSchema]:
        if not entries:
            return []

        buckets: dict = {}
        for entry in entries:
            created_at = entry.get("created_at")
            if not created_at:
                continue
            timestamp = self._parse_timestamp(created_at)
            week_start = (timestamp - timedelta(days=timestamp.weekday())).date()
            bucket = buckets.setdefault(
                week_start,
                {
                    "entries": [],
                    "moods": collections.Counter(),
                    "topics": collections.Counter(),
                },
            )
            bucket["entries"].append(entry)
            bucket["moods"][entry.get("mood", "calm")] += 1
            for topic in self._topics_for_entry(entry):
                bucket["topics"][topic] += 1

        clusters: list[ReflectionWeekClusterSchema] = []
        for week_start, bucket in sorted(buckets.items(), reverse=True):
            entry_count = len(bucket["entries"])
            dominant_mood = (
                bucket["moods"].most_common(1)[0][0] if bucket["moods"] else "calm"
            )
            top_topics = [topic for topic, _ in bucket["topics"].most_common(3)]
            clusters.append(
                ReflectionWeekClusterSchema(
                    week_start=week_start,
                    entry_count=entry_count,
                    dominant_mood=dominant_mood,
                    top_topics=top_topics,
                    headline=self._cluster_headline(dominant_mood, top_topics),
                    recommendation=self._cluster_recommendation(
                        dominant_mood,
                        top_topics,
                        entry_count,
                    ),
                )
            )

        return clusters[:4]

    def _cluster_headline(self, mood: str, topics: list[str]) -> str:
        if topics:
            return f"{topics[0]} focus • {mood.title()} energy"
        return f"{mood.title()} reflections"

    def _cluster_recommendation(
        self,
        mood: str,
        topics: list[str],
        entry_count: int,
    ) -> str:
        if mood == "restless":
            return "Add an earlier wind-down ritual to help the body land before story time."
        if mood == "wiggly":
            return "Try guided stretches while narrating to channel the extra energy."
        if topics:
            return f"Revisit the {topics[0].lower()} motif with a new sensory detail tonight."
        if entry_count >= 4:
            return "You captured a full week of reflections—summarize the theme with your child."
        return "Log another reflection this week to unlock a personalized prompt."

    def _build_recommendations(
        self,
        entries: list[dict],
        clusters: list[ReflectionWeekClusterSchema],
    ) -> list[ReflectionRecommendationSchema]:
        if not entries:
            return []

        recs: list[ReflectionRecommendationSchema] = []
        restless_ratio = sum(
            1 for entry in entries if entry.get("mood") == "restless"
        ) / len(entries)
        if restless_ratio >= 0.3:
            recs.append(
                ReflectionRecommendationSchema(
                    title="Cool-down moments",
                    detail="Blend box-breathing or gentle squeezes before pressing play to soften restlessness.",
                    type="ritual",
                )
            )

        audio_entries = [
            entry
            for entry in entries
            if entry.get("audio_url") or entry.get("audio_path")
        ]
        if not audio_entries:
            recs.append(
                ReflectionRecommendationSchema(
                    title="Layer a voice memo",
                    detail="A 30-second whisper log unlocks richer AI insights and memory cues.",
                    type="journaling",
                )
            )

        if clusters:
            cluster = clusters[0]
            if cluster.top_topics:
                recs.append(
                    ReflectionRecommendationSchema(
                        title=f"Lean into {cluster.top_topics[0].lower()}",
                        detail="Use tonight's prompt to continue that narrative thread and build continuity.",
                        type="story_seed",
                    )
                )

        if len(recs) < 3:
            recs.append(
                ReflectionRecommendationSchema(
                    title="Celebrate the ritual",
                    detail="Share your nightly reflection recap with your child to reinforce the habit loop.",
                    type="celebration",
                )
            )

        return recs[:3]

    def _evaluate_badges(
        self,
        entries: list[dict],
        streak: int,
        clusters: list[ReflectionWeekClusterSchema],
    ) -> list[ReflectionBadgeSchema]:
        badges: list[ReflectionBadgeSchema] = []
        total_entries = len(entries)

        if total_entries >= 5:
            unlocked_at = self._entry_timestamp(entries[min(4, total_entries - 1)])
            badges.append(
                ReflectionBadgeSchema(
                    code="mindful_scribe",
                    label="Mindful Scribe",
                    description="Logged 5 narrative reflections.",
                    unlocked_at=unlocked_at,
                )
            )

        audio_entries = [
            entry
            for entry in entries
            if entry.get("audio_url") or entry.get("audio_path")
        ]
        if len(audio_entries) >= 3:
            unlocked_at = self._entry_timestamp(
                audio_entries[min(2, len(audio_entries) - 1)]
            )
            badges.append(
                ReflectionBadgeSchema(
                    code="voice_archivist",
                    label="Voice Archivist",
                    description="Captured 3 calming voice notes.",
                    unlocked_at=unlocked_at,
                )
            )

        if streak >= 3:
            unlocked_at = self._entry_timestamp(entries[0])
            badges.append(
                ReflectionBadgeSchema(
                    code="streak_keeper",
                    label="Streak Keeper",
                    description="Held a 3-night reflection streak.",
                    unlocked_at=unlocked_at,
                )
            )

        if len(clusters) >= 2:
            badges.append(
                ReflectionBadgeSchema(
                    code="pattern_spotter",
                    label="Pattern Spotter",
                    description="Unlocked multi-week insight clusters.",
                    unlocked_at=self._entry_timestamp(entries[0]),
                )
            )

        return badges

    def _build_weekly_recap(self, entries: list[dict]) -> ReflectionRecapSchema:
        if not entries:
            return ReflectionRecapSchema()

        window_start = datetime.now(timezone.utc).date() - timedelta(days=6)
        recent_entries = []
        for entry in entries:
            created_at = entry.get("created_at")
            if not created_at:
                continue
            date_value = self._parse_timestamp(created_at).date()
            if date_value >= window_start:
                recent_entries.append(entry)

        audio_notes = sum(
            1
            for entry in recent_entries
            if entry.get("audio_url") or entry.get("audio_path")
        )
        topics = {
            topic for entry in recent_entries for topic in self._topics_for_entry(entry)
        }
        return ReflectionRecapSchema(
            entries_logged=len(recent_entries),
            audio_notes=audio_notes,
            new_topics=sorted(topics),
        )

    def _entry_timestamp(self, entry: dict) -> datetime:
        created_at = entry.get("created_at")
        if not created_at:
            return datetime.now(timezone.utc)
        return self._parse_timestamp(created_at)

    def _parse_timestamp(self, value: Optional[str]):
        if not value:
            return datetime.now(timezone.utc)
        return datetime.fromisoformat(value.replace("Z", "+00:00"))


def create_reflections_router(supabase_client: SupabaseClient | None) -> APIRouter:
    router = APIRouter(prefix="/api/v1/reflections", tags=["reflections"])
    service = ReflectionAnalyticsService(supabase_client)

    @router.post(
        "", response_model=ReflectionEntryResponse, status_code=status.HTTP_201_CREATED
    )
    async def submit_reflection(
        payload: ReflectionEntryRequest,
        user_id: UUID | None = None,
    ) -> ReflectionEntryResponse:
        """Persist a reflection entry."""
        return service.submit_reflection(payload, user_id)

    @router.get("/insights", response_model=ReflectionInsightsResponse)
    async def get_reflection_insights(
        user_id: UUID | None = None,
    ) -> ReflectionInsightsResponse:
        """Return weekly reflection insights for a caregiver."""
        return service.get_insights(user_id)

    return router
