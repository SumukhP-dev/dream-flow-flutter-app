"""
Subscription service for managing user subscriptions and usage quotas.

Handles subscription tiers (Free, Premium, Family), usage tracking, and quota enforcement.
Integrates with Stripe (web) and RevenueCat (mobile) for payment processing.
"""

import logging
from datetime import datetime, timedelta
from typing import Optional
from uuid import UUID

from supabase import Client

logger = logging.getLogger("dream_flow")


class SubscriptionService:
    """Service for managing subscriptions and usage quotas."""

    def __init__(self, supabase_client: Client):
        """
        Initialize subscription service.

        Args:
            supabase_client: Supabase client instance with service-role authentication
        """
        self.client = supabase_client

    def get_user_subscription(self, user_id: UUID) -> Optional[dict]:
        """
        Get user's current subscription.

        Args:
            user_id: UUID of the user

        Returns:
            Subscription dictionary or None if not found
        """
        response = (
            self.client.table("subscriptions")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("status", "active")
            .gte("current_period_end", datetime.utcnow().isoformat())
            .order("created_at", desc=True)
            .limit(1)
            .maybe_single()
            .execute()
        )
        return response.data if response.data else None

    def get_user_tier(self, user_id: UUID) -> str:
        """
        Get user's subscription tier.

        Args:
            user_id: UUID of the user

        Returns:
            Subscription tier: 'free', 'premium', or 'family'
        """
        subscription = self.get_user_subscription(user_id)
        if subscription:
            return subscription.get("tier", "free")
        return "free"

    def get_user_quota(self, user_id: UUID) -> int:
        """
        Get user's story generation quota based on subscription tier.

        Args:
            user_id: UUID of the user

        Returns:
            Quota limit (7 for free, 999999 for premium/family)
        """
        tier = self.get_user_tier(user_id)
        if tier in ("premium", "family"):
            return 999999  # Unlimited
        return 7  # Free tier: 7 stories per week

    def get_user_story_count(self, user_id: UUID, period_type: str = "weekly") -> int:
        """
        Get user's current story count for the period.

        Args:
            user_id: UUID of the user
            period_type: 'daily', 'weekly', or 'monthly'

        Returns:
            Current story count for the period
        """
        now = datetime.utcnow()
        if period_type == "daily":
            period_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            period_end = period_start + timedelta(days=1)
        elif period_type == "weekly":
            # Start of week (Monday)
            days_since_monday = now.weekday()
            period_start = (now - timedelta(days=days_since_monday)).replace(
                hour=0, minute=0, second=0, microsecond=0
            )
            period_end = period_start + timedelta(weeks=1)
        else:  # monthly
            period_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if period_start.month == 12:
                period_end = period_start.replace(year=period_start.year + 1, month=1)
            else:
                period_end = period_start.replace(month=period_start.month + 1)

        response = (
            self.client.table("usage_tracking")
            .select("story_count")
            .eq("user_id", str(user_id))
            .eq("period_type", period_type)
            .eq("period_start", period_start.isoformat())
            .eq("period_end", period_end.isoformat())
            .maybe_single()
            .execute()
        )

        if response.data:
            return response.data.get("story_count", 0)
        return 0

    def can_generate_story(self, user_id: UUID) -> tuple[bool, Optional[str]]:
        """
        Check if user can generate a story based on quota.

        Args:
            user_id: UUID of the user

        Returns:
            Tuple of (can_generate, error_message)
        """
        tier = self.get_user_tier(user_id)
        quota = self.get_user_quota(user_id)

        # Premium and Family tiers have unlimited quota
        if tier in ("premium", "family"):
            return True, None

        # Free tier: check weekly quota
        current_count = self.get_user_story_count(user_id, "weekly")
        if current_count >= quota:
            return (
                False,
                f"You've reached your weekly limit of {quota} stories. Upgrade to Premium for unlimited stories!",
            )

        return True, None

    def increment_story_count(self, user_id: UUID, period_type: str = "weekly") -> int:
        """
        Increment user's story count for the period.

        Args:
            user_id: UUID of the user
            period_type: 'daily', 'weekly', or 'monthly'

        Returns:
            New story count after increment
        """
        now = datetime.utcnow()
        if period_type == "daily":
            period_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            period_end = period_start + timedelta(days=1)
        elif period_type == "weekly":
            days_since_monday = now.weekday()
            period_start = (now - timedelta(days=days_since_monday)).replace(
                hour=0, minute=0, second=0, microsecond=0
            )
            period_end = period_start + timedelta(weeks=1)
        else:  # monthly
            period_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if period_start.month == 12:
                period_end = period_start.replace(year=period_start.year + 1, month=1)
            else:
                period_end = period_start.replace(month=period_start.month + 1)

        # Try to update existing record
        response = (
            self.client.table("usage_tracking")
            .select("*")
            .eq("user_id", str(user_id))
            .eq("period_type", period_type)
            .eq("period_start", period_start.isoformat())
            .eq("period_end", period_end.isoformat())
            .maybe_single()
            .execute()
        )

        if response.data:
            # Update existing record
            new_count = response.data.get("story_count", 0) + 1
            self.client.table("usage_tracking").update(
                {"story_count": new_count, "updated_at": now.isoformat()}
            ).eq("id", response.data["id"]).execute()
            return new_count
        else:
            # Create new record
            new_count = 1
            self.client.table("usage_tracking").insert(
                {
                    "user_id": str(user_id),
                    "period_start": period_start.isoformat(),
                    "period_end": period_end.isoformat(),
                    "period_type": period_type,
                    "story_count": new_count,
                }
            ).execute()
            return new_count

    def create_or_update_subscription(
        self,
        user_id: UUID,
        tier: str,
        stripe_subscription_id: Optional[str] = None,
        stripe_customer_id: Optional[str] = None,
        revenuecat_user_id: Optional[str] = None,
        revenuecat_entitlement_id: Optional[str] = None,
        current_period_end: Optional[datetime] = None,
    ) -> dict:
        """
        Create or update user subscription.

        Args:
            user_id: UUID of the user
            tier: Subscription tier ('free', 'premium', 'family')
            stripe_subscription_id: Stripe subscription ID (for web)
            stripe_customer_id: Stripe customer ID (for web)
            revenuecat_user_id: RevenueCat user ID (for mobile)
            revenuecat_entitlement_id: RevenueCat entitlement ID (for mobile)
            current_period_end: Subscription period end date

        Returns:
            Created or updated subscription dictionary
        """
        if current_period_end is None:
            current_period_end = datetime.utcnow() + timedelta(days=30)

        subscription_data = {
            "user_id": str(user_id),
            "tier": tier,
            "status": "active",
            "current_period_start": datetime.utcnow().isoformat(),
            "current_period_end": current_period_end.isoformat(),
        }

        if stripe_subscription_id:
            subscription_data["stripe_subscription_id"] = stripe_subscription_id
        if stripe_customer_id:
            subscription_data["stripe_customer_id"] = stripe_customer_id
        if revenuecat_user_id:
            subscription_data["revenuecat_user_id"] = revenuecat_user_id
        if revenuecat_entitlement_id:
            subscription_data["revenuecat_entitlement_id"] = revenuecat_entitlement_id

        # Check if subscription exists
        existing = (
            self.client.table("subscriptions")
            .select("*")
            .eq("user_id", str(user_id))
            .maybe_single()
            .execute()
        )

        if existing.data:
            # Update existing subscription
            response = (
                self.client.table("subscriptions")
                .update(subscription_data)
                .eq("id", existing.data["id"])
                .execute()
            )
            return response.data[0] if response.data else existing.data
        else:
            # Create new subscription
            response = self.client.table("subscriptions").insert(subscription_data).execute()
            return response.data[0] if response.data else {}

    def cancel_subscription(self, user_id: UUID, cancel_at_period_end: bool = True) -> dict:
        """
        Cancel user subscription.

        Args:
            user_id: UUID of the user
            cancel_at_period_end: If True, cancel at period end; if False, cancel immediately

        Returns:
            Updated subscription dictionary
        """
        update_data = {
            "cancel_at_period_end": cancel_at_period_end,
            "cancelled_at": datetime.utcnow().isoformat() if not cancel_at_period_end else None,
            "status": "cancelled" if not cancel_at_period_end else "active",
        }

        response = (
            self.client.table("subscriptions")
            .update(update_data)
            .eq("user_id", str(user_id))
            .execute()
        )

        return response.data[0] if response.data else {}

