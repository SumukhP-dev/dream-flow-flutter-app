"""
Static placeholder stories used when Supabase is not configured.

These records allow the public stories feed and story detail endpoints to
respond with deterministic demo content so the frontend can render something
useful during offline/local development.
"""

from __future__ import annotations

from typing import Any
from uuid import UUID

PLACEHOLDER_STUDY_GROVE_ID = UUID("11111111-1111-1111-1111-111111111111")
PLACEHOLDER_FAMILY_HEARTH_ID = UUID("22222222-2222-2222-2222-222222222222")
PLACEHOLDER_OCEANIC_SERENITY_ID = UUID("33333333-3333-3333-3333-333333333333")

_PLACEHOLDER_STORIES: list[dict[str, Any]] = [
    {
        "session_id": PLACEHOLDER_STUDY_GROVE_ID,
        "theme": "Study Grove",
        "prompt": "A peaceful study session in a magical library",
        "story_text": (
            "In a quiet corner of the Study Grove, soft light filters through ancient "
            "windows. Books line the shelves, each holding stories waiting to be "
            "discovered. The gentle rustle of pages sounds like whispers of wisdom."
        ),
        "age_rating": "all",
        "like_count": 128,
        "frames": [
            "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1280&q=80"
        ],
        "audio_url": None,
        "video_url": None,
        "thumbnail_url": "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=640&q=80",
        "created_at": "2024-06-01T12:00:00Z",
        "is_public": True,
        "is_approved": True,
    },
    {
        "session_id": PLACEHOLDER_FAMILY_HEARTH_ID,
        "theme": "Family Hearth",
        "prompt": "A cozy evening by the fireplace",
        "story_text": (
            "The Family Hearth glows with warmth as evening settles in. Soft blankets "
            "and warm drinks create a sense of togetherness. Stories are shared, "
            "laughter fills the air, and memories are made."
        ),
        "age_rating": "all",
        "like_count": 96,
        "frames": [
            "https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=1280&q=80"
        ],
        "audio_url": None,
        "video_url": None,
        "thumbnail_url": "https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=640&q=80",
        "created_at": "2024-05-20T19:30:00Z",
        "is_public": True,
        "is_approved": True,
    },
    {
        "session_id": PLACEHOLDER_OCEANIC_SERENITY_ID,
        "theme": "Oceanic Serenity",
        "prompt": "Gentle waves on a peaceful beach",
        "story_text": (
            "The Oceanic Serenity stretches before you, with waves that whisper secrets "
            "of the deep. The sand is warm beneath your feet, and the horizon holds "
            "endless possibilities. Each wave brings calm and renewal."
        ),
        "age_rating": "all",
        "like_count": 143,
        "frames": [
            "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1280&q=80"
        ],
        "audio_url": None,
        "video_url": None,
        "thumbnail_url": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=640&q=80",
        "created_at": "2024-04-15T08:10:00Z",
        "is_public": True,
        "is_approved": True,
    },
]

_PLACEHOLDER_LOOKUP = {
    story["session_id"]: story for story in _PLACEHOLDER_STORIES
}


def list_placeholder_stories() -> list[dict[str, Any]]:
    """Return shallow copies of placeholder stories for safe external use."""
    return [story.copy() for story in _PLACEHOLDER_STORIES]


def get_placeholder_story(session_id: UUID) -> dict[str, Any] | None:
    """Return a shallow copy of the placeholder story for the given ID."""
    story = _PLACEHOLDER_LOOKUP.get(session_id)
    return story.copy() if story else None
