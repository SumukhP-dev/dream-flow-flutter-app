"""
Mock Klaviyo service for demos and testing with API limits.

This module provides a fully functional mock implementation of KlaviyoService
that can be used for demos, testing, and development when Klaviyo API access
is limited or unavailable.
"""

import logging
from datetime import datetime, timedelta
from typing import Any, Optional
from uuid import UUID
import random

logger = logging.getLogger("dream_flow")


class MockKlaviyoService:
    """
    Mock implementation of KlaviyoService for demos with API limits.
    
    This service simulates all Klaviyo API operations with realistic responses
    but without making actual API calls. Perfect for:
    - Hackathon demos with limited API access
    - Development without Klaviyo account
    - Testing without hitting rate limits
    - Offline demonstrations
    """

    def __init__(
        self,
        api_key: Optional[str] = "mock_api_key",
        supabase_client=None,
        enabled: bool = True,
    ):
        """
        Initialize mock Klaviyo service.
        
        Args:
            api_key: Mock API key (not used)
            supabase_client: Optional Supabase client
            enabled: Whether service is enabled
        """
        self.enabled = enabled
        self.api_key = api_key
        self.supabase_client = supabase_client
        
        # In-memory storage for mock data
        self._profiles = {}
        self._events = []
        self._lists = {}
        self._segments = {}
        self._campaigns = {}
        
        logger.info("Mock Klaviyo service initialized (no API calls will be made)")

    async def track_event_async(
        self,
        event_name: str,
        user_id: Optional[UUID],
        properties: Optional[dict[str, Any]] = None,
        email: Optional[str] = None,
    ) -> bool:
        """Mock event tracking."""
        if not self.enabled:
            return False

        event = {
            "event_name": event_name,
            "user_id": str(user_id) if user_id else None,
            "email": email,
            "properties": properties or {},
            "timestamp": datetime.utcnow().isoformat(),
        }
        
        self._events.append(event)
        logger.debug(f"[MOCK] Tracked event: {event_name} for {email}")
        return True

    def track_event(
        self,
        event_name: str,
        user_id: Optional[UUID],
        properties: Optional[dict[str, Any]] = None,
        email: Optional[str] = None,
    ) -> bool:
        """Sync wrapper for track_event_async."""
        import asyncio
        try:
            loop = asyncio.get_event_loop()
            return loop.run_until_complete(
                self.track_event_async(event_name, user_id, properties, email)
            )
        except:
            # If no loop, just simulate success
            self._events.append({
                "event_name": event_name,
                "user_id": str(user_id) if user_id else None,
                "email": email,
                "properties": properties or {},
                "timestamp": datetime.utcnow().isoformat(),
            })
            return True

    async def track_story_generated_async(
        self,
        user_id: Optional[UUID],
        email: Optional[str] = None,
        **kwargs
    ) -> bool:
        """Mock story generation tracking."""
        return await self.track_event_async(
            "Story Generated",
            user_id,
            kwargs,
            email
        )

    def track_story_generated(self, user_id: Optional[UUID], **kwargs) -> bool:
        """Sync wrapper."""
        return self.track_event("Story Generated", user_id, kwargs, kwargs.get("email"))

    async def track_subscription_created_async(
        self,
        user_id: UUID,
        email: Optional[str] = None,
        tier: str = "free",
        previous_tier: Optional[str] = None,
        stripe_subscription_id: Optional[str] = None,
    ) -> bool:
        """Mock subscription creation tracking."""
        return await self.track_event_async(
            "Subscription Created",
            user_id,
            {
                "subscription_tier": tier,
                "previous_tier": previous_tier,
                "stripe_subscription_id": stripe_subscription_id,
            },
            email
        )

    async def track_subscription_cancelled_async(
        self,
        user_id: UUID,
        email: Optional[str] = None,
        tier: str = "free",
        cancel_at_period_end: bool = False,
    ) -> bool:
        """Mock subscription cancellation tracking."""
        return await self.track_event_async(
            "Subscription Cancelled",
            user_id,
            {
                "subscription_tier": tier,
                "cancel_at_period_end": cancel_at_period_end,
            },
            email
        )

    async def create_or_update_profile_async(
        self,
        user_id: UUID,
        email: str,
        **attributes
    ) -> bool:
        """Mock profile creation/update."""
        if not self.enabled:
            return False

        profile_id = str(user_id)
        
        self._profiles[profile_id] = {
            "id": profile_id,
            "email": email,
            "attributes": {
                **attributes,
                "last_synced_at": datetime.utcnow().isoformat(),
            }
        }
        
        logger.debug(f"[MOCK] Updated profile for {email}")
        return True

    async def get_profile_metrics_async(
        self,
        user_id: UUID,
        email: Optional[str] = None,
    ) -> Optional[dict[str, Any]]:
        """Mock profile metrics retrieval."""
        if not self.enabled:
            return None

        profile_id = str(user_id)
        
        # Return mock profile or generate realistic data
        if profile_id in self._profiles:
            return self._profiles[profile_id]
        
        # Generate realistic mock data
        return {
            "profile_id": profile_id,
            "email": email or f"user{profile_id[:8]}@example.com",
            "user_id": profile_id,
            "attributes": {
                "subscription_tier": random.choice(["free", "premium", "family"]),
                "story_preferences": random.sample(
                    ["Ocean", "Forest", "Space", "Animals", "Magic"],
                    k=random.randint(1, 3)
                ),
                "total_stories": random.randint(5, 100),
                "current_streak": random.randint(0, 30),
                "family_mode_enabled": random.choice([True, False]),
                "engagement_score": random.randint(40, 95),
            }
        }

    async def get_event_metrics_async(
        self,
        event_name: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> Optional[dict[str, Any]]:
        """Mock event metrics retrieval."""
        if not self.enabled:
            return None

        # Filter events by name and date range
        filtered_events = [
            e for e in self._events
            if e["event_name"] == event_name
        ]
        
        # Generate realistic mock metrics
        return {
            "metric_id": f"metric_{event_name.lower().replace(' ', '_')}",
            "name": event_name,
            "attributes": {
                "count": len(filtered_events) or random.randint(10, 500),
                "unique_users": random.randint(5, 100),
                "avg_per_user": round(random.uniform(1.5, 10.0), 2),
            }
        }

    # Additional mock methods

    def create_list(
        self,
        list_name: str,
        public_name: Optional[str] = None,
    ) -> Optional[str]:
        """Mock list creation."""
        list_id = f"list_{list_name.lower().replace(' ', '_')}"
        self._lists[list_id] = {
            "id": list_id,
            "name": list_name,
            "public_name": public_name or list_name,
            "members": [],
        }
        logger.debug(f"[MOCK] Created list: {list_name}")
        return list_id

    def create_segment(
        self,
        segment_name: str,
        filter_conditions: dict[str, Any],
    ) -> Optional[str]:
        """Mock segment creation."""
        segment_id = f"seg_{segment_name.lower().replace(' ', '_')}"
        self._segments[segment_id] = {
            "id": segment_id,
            "name": segment_name,
            "filter_conditions": filter_conditions,
            "estimated_size": random.randint(10, 500),
        }
        logger.debug(f"[MOCK] Created segment: {segment_name}")
        return segment_id

    def create_campaign(
        self,
        campaign_name: str,
        subject: str,
        from_email: str,
        from_name: str,
        list_ids: Optional[list[str]] = None,
        segment_ids: Optional[list[str]] = None,
    ) -> Optional[str]:
        """Mock campaign creation."""
        campaign_id = f"camp_{campaign_name.lower().replace(' ', '_')[:20]}"
        self._campaigns[campaign_id] = {
            "id": campaign_id,
            "name": campaign_name,
            "subject": subject,
            "from_email": from_email,
            "from_name": from_name,
            "status": "draft",
            "created_at": datetime.utcnow().isoformat(),
        }
        logger.debug(f"[MOCK] Created campaign: {campaign_name}")
        return campaign_id

    def get_mock_statistics(self) -> dict[str, Any]:
        """Get statistics about mock data."""
        return {
            "profiles_count": len(self._profiles),
            "events_count": len(self._events),
            "lists_count": len(self._lists),
            "segments_count": len(self._segments),
            "campaigns_count": len(self._campaigns),
            "event_types": list(set(e["event_name"] for e in self._events)),
            "is_mock": True,
            "note": "This is mock data - no real API calls made",
        }

    def populate_demo_data(self):
        """Populate with realistic demo data for presentations."""
        # Add some sample profiles
        demo_users = [
            {
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "email": "sarah.parent@example.com",
                "subscription_tier": "premium",
                "story_preferences": ["Ocean", "Animals"],
                "total_stories": 47,
                "current_streak": 12,
                "family_mode_enabled": True,
            },
            {
                "user_id": "223e4567-e89b-12d3-a456-426614174001",
                "email": "john.dad@example.com",
                "subscription_tier": "family",
                "story_preferences": ["Space", "Adventure"],
                "total_stories": 89,
                "current_streak": 23,
                "family_mode_enabled": True,
            },
            {
                "user_id": "323e4567-e89b-12d3-a456-426614174002",
                "email": "emily.mom@example.com",
                "subscription_tier": "free",
                "story_preferences": ["Forest", "Magic"],
                "total_stories": 15,
                "current_streak": 5,
                "family_mode_enabled": False,
            },
        ]
        
        for user in demo_users:
            self._profiles[user["user_id"]] = {
                "id": user["user_id"],
                "email": user["email"],
                "attributes": {k: v for k, v in user.items() if k not in ["user_id", "email"]}
            }
        
        # Add sample events
        for _ in range(50):
            self._events.append({
                "event_name": random.choice(["Story Generated", "Story Completed", "Streak Maintained"]),
                "user_id": random.choice([u["user_id"] for u in demo_users]),
                "email": random.choice([u["email"] for u in demo_users]),
                "properties": {
                    "theme": random.choice(["Ocean", "Forest", "Space", "Animals"]),
                },
                "timestamp": (datetime.utcnow() - timedelta(days=random.randint(0, 30))).isoformat(),
            })
        
        logger.info("[MOCK] Populated with demo data for presentation")


# Helper function to create mock service
def create_mock_klaviyo_service(with_demo_data: bool = True) -> MockKlaviyoService:
    """
    Create a mock Klaviyo service, optionally with demo data.
    
    Args:
        with_demo_data: Whether to populate with demo data
        
    Returns:
        MockKlaviyoService instance
    """
    service = MockKlaviyoService(enabled=True)
    
    if with_demo_data:
        service.populate_demo_data()
    
    return service
