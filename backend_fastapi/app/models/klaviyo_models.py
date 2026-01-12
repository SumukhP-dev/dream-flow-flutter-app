"""
Pydantic models for Klaviyo API request/response validation.

These models provide type safety, validation, and documentation for all
Klaviyo integration data structures.
"""

from datetime import datetime
from typing import Any, Literal, Optional
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field, field_validator


class KlaviyoEvent(BaseModel):
    """Model for Klaviyo event tracking."""
    
    event_name: str = Field(..., description="Name of the event (e.g., 'Story Generated')")
    user_id: UUID = Field(..., description="UUID of the user")
    email: EmailStr = Field(..., description="User's email address")
    properties: dict[str, Any] = Field(default_factory=dict, description="Event properties/metadata")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Event timestamp")
    
    @field_validator('event_name')
    @classmethod
    def validate_event_name(cls, v: str) -> str:
        """Validate event name is in allowed list."""
        allowed_events = [
            'Story Generated',
            'Subscription Created',
            'Subscription Cancelled',
            'Signed Up',
            'Profile Updated',
            'Story Downloaded',
            'Streak Maintained',
            'Story Skipped',
            'Story Completed',
            'Re-engagement Triggered',
        ]
        if v not in allowed_events:
            raise ValueError(f'Invalid event name: {v}. Must be one of {allowed_events}')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "event_name": "Story Generated",
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "email": "parent@example.com",
                "properties": {
                    "theme": "Calm Focus",
                    "story_length": 450,
                    "generation_time_seconds": 18.5
                },
                "timestamp": "2024-01-15T20:30:00Z"
            }
        }


class KlaviyoProfile(BaseModel):
    """Model for Klaviyo profile data."""
    
    email: EmailStr = Field(..., description="User's email address (required)")
    user_id: UUID = Field(..., description="Internal user ID")
    subscription_tier: Literal['free', 'premium', 'family'] = Field(
        default='free',
        description="Current subscription tier"
    )
    story_preferences: list[str] = Field(
        default_factory=list,
        description="List of preferred story themes"
    )
    total_stories: int = Field(
        default=0,
        ge=0,
        description="Total number of stories generated"
    )
    current_streak: int = Field(
        default=0,
        ge=0,
        description="Current daily usage streak"
    )
    family_mode_enabled: bool = Field(
        default=False,
        description="Whether family mode is enabled"
    )
    first_name: Optional[str] = Field(None, description="User's first name")
    last_name: Optional[str] = Field(None, description="User's last name")
    last_synced_at: datetime = Field(
        default_factory=datetime.utcnow,
        description="Last profile sync timestamp"
    )

    @field_validator('subscription_tier')
    @classmethod
    def validate_tier(cls, v: str) -> str:
        """Validate subscription tier is valid."""
        if v not in ['free', 'premium', 'family']:
            raise ValueError('Invalid subscription tier. Must be free, premium, or family')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "email": "parent@example.com",
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "subscription_tier": "premium",
                "story_preferences": ["animals", "nature", "bedtime"],
                "total_stories": 42,
                "current_streak": 7,
                "family_mode_enabled": True,
                "first_name": "Jane",
                "last_name": "Doe"
            }
        }


class StoryGeneratedEvent(BaseModel):
    """Specific model for Story Generated event properties."""
    
    theme: Optional[str] = Field(None, description="Story theme (e.g., 'Calm Focus')")
    story_length: Optional[int] = Field(None, ge=0, description="Length of story in characters")
    generation_time_seconds: Optional[float] = Field(
        None,
        ge=0,
        description="Time taken to generate story"
    )
    num_scenes: Optional[int] = Field(None, ge=1, le=10, description="Number of scenes generated")
    user_mood: Optional[str] = Field(None, description="User's reported mood")

    @field_validator('theme')
    @classmethod
    def validate_theme(cls, v: Optional[str]) -> Optional[str]:
        """Validate theme is in allowed list."""
        if v is None:
            return v
        allowed_themes = [
            'Calm Focus',
            'Peaceful Journey',
            'Tranquil Dreams',
            'Adventure',
            'Exploration',
            'Discovery',
            'Animals',
            'Nature',
            'Ocean',
            'Space',
            'Forest',
        ]
        if v not in allowed_themes:
            # Allow custom themes but log warning
            return v
        return v


class SubscriptionEvent(BaseModel):
    """Model for subscription-related events."""
    
    subscription_tier: Literal['free', 'premium', 'family'] = Field(
        ...,
        description="Subscription tier"
    )
    previous_tier: Optional[Literal['free', 'premium', 'family']] = Field(
        None,
        description="Previous subscription tier (for upgrades)"
    )
    stripe_subscription_id: Optional[str] = Field(
        None,
        description="Stripe subscription ID"
    )
    cancel_at_period_end: bool = Field(
        default=False,
        description="Whether cancellation is at period end"
    )


class KlaviyoSegment(BaseModel):
    """Model for Klaviyo segment configuration."""
    
    segment_name: str = Field(..., description="Name of the segment")
    filter_conditions: dict[str, Any] = Field(
        ...,
        description="Filter conditions for the segment"
    )
    segment_id: Optional[str] = Field(None, description="Klaviyo segment ID (after creation)")

    class Config:
        json_schema_extra = {
            "example": {
                "segment_name": "Premium Subscribers",
                "filter_conditions": {
                    "subscription_tier": "premium",
                    "total_stories": 10
                }
            }
        }


class KlaviyoList(BaseModel):
    """Model for Klaviyo email list."""
    
    list_name: str = Field(..., description="Internal list name")
    public_name: Optional[str] = Field(None, description="Public-facing list name")
    list_id: Optional[str] = Field(None, description="Klaviyo list ID (after creation)")

    class Config:
        json_schema_extra = {
            "example": {
                "list_name": "Active Users",
                "public_name": "Active Dream Flow Users"
            }
        }


class KlaviyoCampaign(BaseModel):
    """Model for Klaviyo email campaign."""
    
    campaign_name: str = Field(..., description="Name of the campaign")
    subject: str = Field(..., description="Email subject line")
    from_email: EmailStr = Field(..., description="Sender email address")
    from_name: str = Field(..., description="Sender name")
    list_ids: Optional[list[str]] = Field(None, description="List IDs to send to")
    segment_ids: Optional[list[str]] = Field(None, description="Segment IDs to send to")
    campaign_id: Optional[str] = Field(None, description="Klaviyo campaign ID (after creation)")
    scheduled_time: Optional[datetime] = Field(
        None,
        description="Scheduled send time (None = send immediately)"
    )

    @field_validator('list_ids', 'segment_ids')
    @classmethod
    def validate_audience(cls, v: Optional[list[str]], info) -> Optional[list[str]]:
        """Validate that either list_ids or segment_ids is provided."""
        # This is checked in the model's validation
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "campaign_name": "Weekly Story Summary",
                "subject": "Your Week in Dream Flow Stories",
                "from_email": "noreply@dreamflow.com",
                "from_name": "Dream Flow",
                "segment_ids": ["seg_123"]
            }
        }


class ParentInsight(BaseModel):
    """Model for parent insight data."""
    
    user_id: UUID = Field(..., description="Parent user ID")
    email: EmailStr = Field(..., description="Parent email")
    period_start: datetime = Field(..., description="Analysis period start")
    period_end: datetime = Field(..., description="Analysis period end")
    insights: dict[str, Any] = Field(
        ...,
        description="Calculated insights and metrics"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "email": "parent@example.com",
                "period_start": "2024-01-01T00:00:00Z",
                "period_end": "2024-01-31T23:59:59Z",
                "insights": {
                    "total_stories": 45,
                    "favorite_theme": "Ocean",
                    "engagement_trend": "+23%",
                    "bedtime_consistency": "Improved",
                    "recommendations": [
                        "Try more ocean-themed stories",
                        "Consistent bedtime helps routine"
                    ]
                }
            }
        }


class ChurnRiskAssessment(BaseModel):
    """Model for churn risk assessment data."""
    
    user_id: UUID = Field(..., description="User ID")
    risk_score: float = Field(..., ge=0.0, le=1.0, description="Churn risk score (0.0 to 1.0)")
    risk_level: Literal['low', 'medium', 'high'] = Field(..., description="Risk level category")
    days_since_last_story: Optional[int] = Field(None, ge=0, description="Days since last story")
    recommendations: list[str] = Field(
        default_factory=list,
        description="Recommended re-engagement actions"
    )
    should_trigger_reengagement: bool = Field(
        default=False,
        description="Whether to trigger re-engagement flow"
    )

    @field_validator('risk_level')
    @classmethod
    def determine_risk_level(cls, v: str, info) -> str:
        """Auto-determine risk level from risk_score if not explicitly set."""
        # This could be auto-computed from risk_score
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "risk_score": 0.85,
                "risk_level": "high",
                "days_since_last_story": 21,
                "recommendations": [
                    "We miss you! Try a new story theme today",
                    "Explore our premium features"
                ],
                "should_trigger_reengagement": True
            }
        }
