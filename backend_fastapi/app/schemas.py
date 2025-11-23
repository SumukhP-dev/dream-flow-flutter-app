from typing import Optional
from uuid import UUID
from datetime import datetime

from pydantic import BaseModel, Field


class UserProfile(BaseModel):
    mood: str = Field(..., description="Current emotional tone reported by the user")
    routine: str = Field(..., description="Bedtime routine or activity context")
    preferences: list[str] = Field(default_factory=list, description="General likes and interests")
    favorite_characters: list[str] = Field(default_factory=list)
    calming_elements: list[str] = Field(default_factory=list, description="Anchors such as sounds, locations, or colors")


class StoryRequest(BaseModel):
    prompt: str = Field(..., description="Seed prompt from the user")
    theme: str = Field(..., description="Theme that shapes narrative, visuals, and narration")
    target_length: int = Field(400, description="Approximate number of words for the story")
    voice: Optional[str] = Field(None, description="Voice preset for narration if supported by the model")
    num_scenes: int = Field(4, ge=1, le=8, description="Number of visual scenes to generate")
    profile: Optional[UserProfile] = Field(None, description="User-specific context for mood, routine, and preferences")
    user_id: Optional[UUID] = Field(None, description="User ID for persisting the story to Supabase")
    child_mode: bool = Field(False, description="Enable child-safe content filtering")
    child_profile_id: Optional[UUID] = Field(None, description="Child profile ID for family mode")
    language: Optional[str] = Field("en", description="Language code for story generation (e.g., 'en', 'es', 'fr')")


class AssetUrls(BaseModel):
    audio: str
    video: str
    frames: list[str]


class StoryResponse(BaseModel):
    story_text: str
    theme: str
    assets: AssetUrls
    session_id: Optional[UUID] = Field(None, description="Session ID if story was persisted to Supabase")


class SessionHistoryItem(BaseModel):
    session_id: UUID
    theme: str
    prompt: str
    thumbnail_url: Optional[str] = Field(None, description="URL to the first frame/thumbnail")
    created_at: str


class SessionHistoryResponse(BaseModel):
    sessions: list[SessionHistoryItem]


class SessionAsset(BaseModel):
    id: UUID
    asset_type: str = Field(..., description="Type of asset: 'audio', 'video', or 'frame'")
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


class StoryPresetsResponse(BaseModel):
    themes: list[ThemePreset] = Field(..., description="All available story themes")
    featured: list[ThemePreset] = Field(..., description="Featured worlds (one from each category)")


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
    content_type: str = Field(..., description="Type: story, prompt, narration, or visual")
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
    notes: Optional[str] = Field(None, description="Optional notes about the resolution")


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
    status: str = Field(..., description="Subscription status: active, cancelled, expired, or past_due")
    current_period_start: datetime
    current_period_end: datetime
    cancel_at_period_end: bool = False
    cancelled_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class UsageQuotaResponse(BaseModel):
    tier: str = Field(..., description="Current subscription tier")
    quota: int = Field(..., description="Story generation quota (3 for free, unlimited for premium/family)")
    current_count: int = Field(..., description="Current story count for the period")
    period_type: str = Field(..., description="Period type: daily, weekly, or monthly")
    can_generate: bool = Field(..., description="Whether user can generate a story")
    error_message: Optional[str] = Field(None, description="Error message if quota exceeded")


class CreateSubscriptionRequest(BaseModel):
    tier: str = Field(..., description="Subscription tier: premium or family")
    stripe_subscription_id: Optional[str] = Field(None, description="Stripe subscription ID (for web)")
    stripe_customer_id: Optional[str] = Field(None, description="Stripe customer ID (for web)")
    revenuecat_user_id: Optional[str] = Field(None, description="RevenueCat user ID (for mobile)")
    revenuecat_entitlement_id: Optional[str] = Field(None, description="RevenueCat entitlement ID (for mobile)")


class CancelSubscriptionRequest(BaseModel):
    cancel_at_period_end: bool = Field(True, description="Cancel at period end or immediately")


# Notification Schemas
class RegisterNotificationTokenRequest(BaseModel):
    token: str = Field(..., description="FCM or APNs token")
    platform: str = Field(..., description="Platform: android, ios, or web")
    device_id: Optional[str] = Field(None, description="Optional device identifier")


class NotificationPreferencesResponse(BaseModel):
    id: UUID
    user_id: UUID
    bedtime_reminders_enabled: bool
    bedtime_reminder_time: Optional[str] = Field(None, description="Time in HH:MM format")
    streak_notifications_enabled: bool
    story_recommendations_enabled: bool
    weekly_summary_enabled: bool
    created_at: datetime
    updated_at: datetime


class UpdateNotificationPreferencesRequest(BaseModel):
    bedtime_reminders_enabled: Optional[bool] = None
    bedtime_reminder_time: Optional[str] = Field(None, description="Time in HH:MM format")
    streak_notifications_enabled: Optional[bool] = None
    story_recommendations_enabled: Optional[bool] = None
    weekly_summary_enabled: Optional[bool] = None


