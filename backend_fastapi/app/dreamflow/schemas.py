from typing import Optional
from uuid import UUID
from datetime import datetime, date

from pydantic import BaseModel, Field


class UserProfile(BaseModel):
    mood: str = Field(..., description="Current emotional tone reported by the user")
    routine: str = Field(..., description="Bedtime routine or activity context")
    preferences: list[str] = Field(
        default_factory=list, description="General likes and interests"
    )
    favorite_characters: list[str] = Field(default_factory=list)
    calming_elements: list[str] = Field(
        default_factory=list, description="Anchors such as sounds, locations, or colors"
    )


class StoryRequest(BaseModel):
    prompt: str = Field(..., description="Seed prompt from the user")
    theme: str = Field(
        ..., description="Theme that shapes narrative, visuals, and narration"
    )
    target_length: int = Field(
        400, description="Approximate number of words for the story"
    )
    voice: Optional[str] = Field(
        None, description="Voice preset for narration if supported by the model"
    )
    num_scenes: int = Field(
        4, ge=1, le=8, description="Number of visual scenes to generate"
    )
    profile: Optional[UserProfile] = Field(
        None, description="User-specific context for mood, routine, and preferences"
    )
    user_id: Optional[UUID] = Field(
        None, description="User ID for persisting the story to Supabase"
    )
    child_mode: bool = Field(False, description="Enable child-safe content filtering")
    child_profile_id: Optional[UUID] = Field(
        None, description="Child profile ID for family mode"
    )
    language: Optional[str] = Field(
        "en", description="Language code for story generation (e.g., 'en', 'es', 'fr')"
    )
    primary_language: Optional[str] = Field(
        None, description="Primary language code for bilingual story generation (e.g., 'en', 'es', 'fr')"
    )
    include_text_overlay: bool = Field(
        True, description="Whether to include text overlays on generated images (default: True)"
    )
    secondary_language: Optional[str] = Field(
        None, description="Secondary language code for bilingual story generation (e.g., 'en', 'es', 'fr')"
    )
    visual_mode: Optional[str] = Field(
        None,
        description="Visual generation mode: 'images'"
    )


class AssetUrls(BaseModel):
    audio: str
    frames: list[str] = Field(default_factory=list, description="Image frames for slideshow (primary visual layer)")


class StoryResponse(BaseModel):
    story_text: str
    theme: str
    assets: AssetUrls
    session_id: Optional[UUID] = Field(
        None, description="Session ID if story was persisted to Supabase"
    )
    primary_language: Optional[str] = Field(
        None, description="Primary language code used for story generation"
    )
    secondary_language: Optional[str] = Field(
        None, description="Secondary language code used for bilingual story generation"
    )


class StoryJobStatus(BaseModel):
    """Status payload for queued story generation jobs."""

    job_id: str
    status: str = Field(
        ..., description="queued, processing, completed, or failed"
    )
    queue_position: Optional[int] = Field(
        None,
        description="0-based position in the queue when status is 'queued'",
    )
    result: Optional[StoryResponse] = Field(
        None, description="Final StoryResponse once the job is completed"
    )
    error: Optional[str] = Field(
        None, description="Error message if the job failed"
    )


class SessionHistoryItem(BaseModel):
    session_id: UUID
    theme: str
    prompt: str
    thumbnail_url: Optional[str] = Field(
        None, description="URL to the first frame/thumbnail"
    )
    created_at: str


class SessionHistoryResponse(BaseModel):
    sessions: list[SessionHistoryItem]


class SessionAsset(BaseModel):
    id: UUID
    asset_type: str = Field(
        ..., description="Type of asset: 'audio', 'video', or 'frame'"
    )
    asset_url: str
    display_order: int


class StoryHistoryItem(BaseModel):
    id: UUID
    prompt: str
    theme: str
    story_text: str
    target_length: int
    num_scenes: int
    voice: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    assets: list[SessionAsset] = Field(default_factory=list)


class StoryHistoryResponse(BaseModel):
    stories: list[StoryHistoryItem]
    total: int = Field(..., description="Total number of stories available")
    limit: int = Field(..., description="Number of items per page")
    offset: int = Field(..., description="Number of items skipped")
    has_more: bool = Field(..., description="Whether there are more stories available")


class ThemePreset(BaseModel):
    title: str
    emoji: str
    description: str
    mood: str
    routine: str
    category: str


class StoryTemplate(BaseModel):
    id: UUID
    title: str
    emoji: str
    description: str
    mood: str
    routine: str
    category: str
    is_featured: bool
    sample_story_text: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class StoryPresetsResponse(BaseModel):
    themes: list[ThemePreset] = Field(..., description="All available story themes")
    featured: list[ThemePreset] = Field(
        ..., description="Featured worlds (one from each category)"
    )


class StoryTemplatesResponse(BaseModel):
    templates: list[StoryTemplate] = Field(..., description="All available story templates")
    featured: list[StoryTemplate] = Field(
        ..., description="Featured story templates"
    )
    categories: dict[str, list[StoryTemplate]] = Field(
        ..., description="Templates grouped by category"
    )


class FeedbackRequest(BaseModel):
    session_id: UUID = Field(..., description="Session ID to provide feedback for")
    rating: int = Field(..., ge=1, le=5, description="Rating from 1 to 5")
    mood_delta: int = Field(..., ge=-5, le=5, description="Mood change from -5 to 5")


class FeedbackResponse(BaseModel):
    id: UUID
    session_id: UUID
    rating: int
    mood_delta: int
    created_at: datetime


class GuardrailViolationSchema(BaseModel):
    category: str
    detail: str


class ModerationQueueItem(BaseModel):
    id: UUID
    status: str = Field(..., description="Status: pending, resolved, or rejected")
    violations: list[GuardrailViolationSchema]
    content: str
    content_type: str = Field(
        ..., description="Type: story, prompt, narration, or visual"
    )
    user_id: Optional[UUID] = None
    session_id: Optional[UUID] = None
    resolved_by: Optional[UUID] = None
    resolved_at: Optional[datetime] = None
    resolution_notes: Optional[str] = None
    audit_log: list[dict] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class ModerationQueueListResponse(BaseModel):
    items: list[ModerationQueueItem]
    total: int = Field(..., description="Total number of items")
    limit: int = Field(..., description="Number of items per page")
    offset: int = Field(..., description="Number of items skipped")
    has_more: bool = Field(..., description="Whether there are more items available")


class ResolveModerationRequest(BaseModel):
    resolution: str = Field(..., description="Resolution: 'resolved' or 'rejected'")
    notes: Optional[str] = Field(
        None, description="Optional notes about the resolution"
    )


# Subscription Schemas
class SubscriptionTier(str):
    FREE = "free"
    PREMIUM = "premium"
    FAMILY = "family"


class SubscriptionStatus(str):
    ACTIVE = "active"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    PAST_DUE = "past_due"


class SubscriptionResponse(BaseModel):
    id: UUID
    user_id: UUID
    tier: str = Field(..., description="Subscription tier: free, premium, or family")
    status: str = Field(
        ..., description="Subscription status: active, cancelled, expired, or past_due"
    )
    current_period_start: datetime
    current_period_end: datetime
    cancel_at_period_end: bool = False
    cancelled_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class UsageQuotaResponse(BaseModel):
    tier: str = Field(..., description="Current subscription tier")
    quota: int = Field(..., description="Story generation quota (unlimited for all tiers)")
    has_ads: bool = Field(..., description="Whether user should see ads (True for free tier, False for paid)")
    current_count: int = Field(..., description="Current story count for the period (for analytics)")
    period_type: str = Field(..., description="Period type: daily, weekly, or monthly")
    can_generate: bool = Field(..., description="Whether user can generate a story (always True - unlimited)")
    error_message: Optional[str] = Field(
        None, description="Error message if quota exceeded (deprecated - always None)"
    )


class CreateSubscriptionRequest(BaseModel):
    tier: str = Field(..., description="Subscription tier: premium or family")
    stripe_subscription_id: Optional[str] = Field(
        None, description="Stripe subscription ID (for web)"
    )
    stripe_customer_id: Optional[str] = Field(
        None, description="Stripe customer ID (for web)"
    )


class CancelSubscriptionRequest(BaseModel):
    cancel_at_period_end: bool = Field(
        True, description="Cancel at period end or immediately"
    )


# Notification Schemas
class RegisterNotificationTokenRequest(BaseModel):
    token: str = Field(..., description="FCM or APNs token")
    platform: str = Field(..., description="Platform: android, ios, or web")
    device_id: Optional[str] = Field(None, description="Optional device identifier")


class NotificationPreferencesResponse(BaseModel):
    id: UUID
    user_id: UUID
    bedtime_reminders_enabled: bool
    bedtime_reminder_time: Optional[str] = Field(
        None, description="Time in HH:MM format"
    )
    streak_notifications_enabled: bool
    story_recommendations_enabled: bool
    weekly_summary_enabled: bool
    maestro_nudges_enabled: bool = False
    maestro_digest_time: Optional[str] = Field(
        None, description="Digest time in HH:MM format"
    )
    created_at: datetime
    updated_at: datetime


class UpdateNotificationPreferencesRequest(BaseModel):
    bedtime_reminders_enabled: Optional[bool] = None
    bedtime_reminder_time: Optional[str] = Field(
        None, description="Time in HH:MM format"
    )
    streak_notifications_enabled: Optional[bool] = None
    story_recommendations_enabled: Optional[bool] = None
    weekly_summary_enabled: Optional[bool] = None
    maestro_nudges_enabled: Optional[bool] = None
    maestro_digest_time: Optional[str] = Field(
        None, description="Digest time in HH:MM format"
    )


# ============================================================================
# Advanced Experience Schemas
# ============================================================================


class MaestroTipSchema(BaseModel):
    title: str
    description: str
    micro_adjustment: str
    confidence: float = Field(ge=0, le=1, default=0.75)


class MaestroTrendSchema(BaseModel):
    label: str
    delta_minutes: float
    direction: str = Field(..., description="up, down, or steady")


class EnvironmentInsightsSchema(BaseModel):
    lighting_score: float = Field(ge=0, le=1)
    scent_score: float = Field(ge=0, le=1)
    notes: list[str] = Field(default_factory=list)


class MaestroQuickActionSchema(BaseModel):
    id: str
    label: str
    icon: str = "🕯️"
    value: Optional[float] = None
    min: Optional[float] = None
    max: Optional[float] = None


class MaestroInsightsResponse(BaseModel):
    nightly_tip: MaestroTipSchema
    streaks: list[MaestroTrendSchema]
    environment: EnvironmentInsightsSchema
    quick_actions: list[MaestroQuickActionSchema]
    streak_days: int = 0
    has_travel_shift: bool = False


class MaestroQuickActionRequest(BaseModel):
    action_id: str = Field(..., description="Identifier of the quick action to trigger")
    value: Optional[float] = Field(None, description="Optional slider value")
    user_id: Optional[UUID] = Field(
        None, description="Optional user context for logging"
    )


class MoodboardStrokePoint(BaseModel):
    x: float
    y: float


class MoodboardStrokeSchema(BaseModel):
    points: list[MoodboardStrokePoint] = Field(default_factory=list)
    width: float = 6.0
    color: str = "#ffffff"


class MoodboardInspirationRequest(BaseModel):
    type: str = Field(..., description="photo or sketch")
    session_id: Optional[UUID] = None
    data: Optional[str] = Field(
        None, description="Base64 encoded image data for photos"
    )
    strokes: list[MoodboardStrokeSchema] = Field(default_factory=list)
    caption: Optional[str] = None
    caregiver_consent: bool = Field(
        True, description="Whether caregiver approved the upload flow"
    )


class MoodboardUploadResponse(BaseModel):
    preview_url: str
    frames: list[str]
    requires_moderation: bool = False


class ReflectionEntryRequest(BaseModel):
    id: Optional[UUID] = None
    session_id: Optional[UUID] = None
    child_profile_id: Optional[UUID] = None
    mood: str = Field(
        ..., description="Enum string matching ReflectionMood on the client"
    )
    note: Optional[str] = None
    transcript: Optional[str] = None
    audio_url: Optional[str] = Field(
        None, description="Signed URL to the uploaded voice note"
    )
    sentiment: Optional[float] = Field(
        None, ge=-1, le=1, description="Optional sentiment score"
    )
    tags: list[str] = Field(default_factory=list)


class ReflectionTopicSchema(BaseModel):
    label: str
    mentions: int


class ReflectionWeekClusterSchema(BaseModel):
    week_start: date
    entry_count: int
    dominant_mood: str
    top_topics: list[str] = Field(default_factory=list)
    headline: str
    recommendation: str


class ReflectionRecommendationSchema(BaseModel):
    title: str
    detail: str
    type: str = Field(
        "habit",
        description="Recommendation style (habit, ritual, journaling, environment)",
    )


class ReflectionBadgeSchema(BaseModel):
    code: str
    label: str
    description: str
    unlocked_at: Optional[datetime] = None


class ReflectionRecapSchema(BaseModel):
    entries_logged: int = 0
    audio_notes: int = 0
    new_topics: list[str] = Field(default_factory=list)


class ReflectionCelebrationSchema(BaseModel):
    badges: list[ReflectionBadgeSchema] = Field(default_factory=list)
    weekly_recap: ReflectionRecapSchema = Field(
        default_factory=ReflectionRecapSchema,
    )


class ReflectionEntryResponse(BaseModel):
    id: UUID
    session_id: Optional[UUID] = None
    mood: str
    note: Optional[str] = None
    transcript: Optional[str] = None
    created_at: datetime


class ReflectionInsightsResponse(BaseModel):
    dominant_mood: str
    streak: int
    topics: list[ReflectionTopicSchema]
    entries: list[ReflectionEntryResponse]
    weekly_clusters: list[ReflectionWeekClusterSchema] = Field(default_factory=list)
    recommendations: list[ReflectionRecommendationSchema] = Field(default_factory=list)
    celebrations: ReflectionCelebrationSchema = Field(
        default_factory=ReflectionCelebrationSchema,
    )


class SmartSceneRunRequest(BaseModel):
    scene_id: str
    user_id: Optional[UUID] = None
    trigger_source: Optional[str] = Field(
        "app", description="app, automation, or voice"
    )


# Story Sharing Schemas
class PublicStoryItem(BaseModel):
    session_id: UUID
    theme: str
    prompt: str
    story_text: str
    thumbnail_url: Optional[str] = Field(None, description="URL to the first frame/thumbnail")
    age_rating: str = Field(..., description="Age rating: all, 5+, 7+, 10+, 13+")
    like_count: int = Field(0, description="Number of likes")
    created_at: str
    is_liked: bool = Field(False, description="Whether current user has liked this story")


class PublicStoriesResponse(BaseModel):
    stories: list[PublicStoryItem]
    total: int = Field(..., description="Total number of public stories available")
    limit: int = Field(..., description="Number of items per page")
    offset: int = Field(..., description="Number of items skipped")
    has_more: bool = Field(..., description="Whether there are more stories available")


class ShareStoryRequest(BaseModel):
    is_public: bool = Field(..., description="Whether to make the story public")
    age_rating: Optional[str] = Field(
        "all", description="Age rating: all, 5+, 7+, 10+, 13+"
    )


class ShareStoryResponse(BaseModel):
    session_id: UUID
    is_public: bool
    is_approved: bool = Field(False, description="Whether story has been approved by moderation")
    shared_at: Optional[str] = None
    message: str = Field(..., description="Status message")


class ReportStoryRequest(BaseModel):
    reason: str = Field(
        ..., description="Reason: inappropriate, spam, harassment, copyright, other"
    )
    details: Optional[str] = Field(None, description="Additional details about the report")


class ReportStoryResponse(BaseModel):
    report_id: UUID
    message: str = Field(..., description="Confirmation message")


class LikeStoryResponse(BaseModel):
    session_id: UUID
    liked: bool = Field(..., description="Whether story is now liked")
    like_count: int = Field(..., description="Total number of likes")


class StoryDetailResponse(BaseModel):
    session_id: UUID
    theme: str
    prompt: str
    story_text: str
    thumbnail_url: Optional[str] = None
    frames: list[str] = Field(default_factory=list)
    audio_url: Optional[str] = None
    video_url: Optional[str] = None
    age_rating: str
    like_count: int
    is_liked: bool
    is_public: bool
    is_approved: bool
    created_at: str
    can_share: bool = Field(False, description="Whether current user can share this story")


class SupportContactRequest(BaseModel):
    name: str = Field(..., description="Contact name")
    email: str = Field(..., description="Contact email address")
    subject: str = Field(..., description="Message subject")
    message: str = Field(..., description="Message content", min_length=10)


class SupportContactResponse(BaseModel):
    status: str
    message: str


# Auth Schemas
class SignUpRequest(BaseModel):
    """Request schema for user signup."""
    email: str = Field(..., description="User email address")
    password: str = Field(..., min_length=8, description="User password (min 8 characters)")
    full_name: Optional[str] = Field(None, description="User's full name")
    signup_method: Optional[str] = Field("email", description="Signup method (email, google, apple)")


class SignUpResponse(BaseModel):
    """Response schema for user signup."""
    user_id: UUID = Field(..., description="Unique user ID")
    email: str = Field(..., description="User email address")
    message: str = Field(..., description="Success message")
    needs_email_verification: bool = Field(
        False, 
        description="Whether the user needs to verify their email"
    )