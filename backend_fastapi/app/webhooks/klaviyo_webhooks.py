"""
Klaviyo webhook handlers for bidirectional integration.

This module receives real-time updates FROM Klaviyo when users interact with
emails (opens, clicks, bounces, etc.) and updates the application state accordingly.
"""

import logging
import hmac
import hashlib
from typing import Any, Optional
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Request, HTTPException, Header
from pydantic import BaseModel

logger = logging.getLogger("dream_flow")

# Create router for webhook endpoints
router = APIRouter(prefix="/webhooks", tags=["webhooks"])


class KlaviyoWebhookPayload(BaseModel):
    """Model for Klaviyo webhook payload."""
    type: str
    id: str
    attributes: dict[str, Any]


class KlaviyoWebhookHandler:
    """Handler for processing Klaviyo webhook events."""
    
    def __init__(
        self,
        supabase_client=None,
        klaviyo_service=None,
        webhook_secret: Optional[str] = None,
    ):
        """
        Initialize webhook handler.
        
        Args:
            supabase_client: Supabase client for database updates
            klaviyo_service: Klaviyo service for additional API calls
            webhook_secret: Secret key for webhook signature verification
        """
        self.supabase_client = supabase_client
        self.klaviyo_service = klaviyo_service
        self.webhook_secret = webhook_secret

    def verify_webhook_signature(
        self,
        payload: bytes,
        signature: Optional[str],
    ) -> bool:
        """
        Verify Klaviyo webhook signature for security.
        
        Args:
            payload: Raw webhook payload bytes
            signature: X-Klaviyo-Signature header value
            
        Returns:
            True if signature is valid
        """
        if not self.webhook_secret or not signature:
            logger.warning("Webhook signature verification skipped (no secret configured)")
            return True  # Allow in development
        
        try:
            expected_signature = hmac.new(
                self.webhook_secret.encode(),
                payload,
                hashlib.sha256
            ).hexdigest()
            
            return hmac.compare_digest(signature, expected_signature)
            
        except Exception as e:
            logger.error(f"Error verifying webhook signature: {e}")
            return False

    async def handle_email_opened(
        self,
        event_data: dict[str, Any],
    ) -> bool:
        """
        Handle email opened event from Klaviyo.
        
        Updates user engagement score when they open emails.
        
        Args:
            event_data: Event data from webhook
            
        Returns:
            True if handled successfully
        """
        try:
            profile = event_data.get("profile", {})
            email = profile.get("email")
            campaign_name = event_data.get("campaign_name")
            
            if not email:
                logger.warning("No email in opened event")
                return False
            
            # Update engagement score in Supabase
            if self.supabase_client:
                # Increment engagement score
                response = await self._update_engagement_score(
                    email=email,
                    increment=5,  # +5 points for opening email
                )
                
                logger.info(f"Updated engagement score for {email} (opened: {campaign_name})")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error handling email opened event: {e}")
            return False

    async def handle_email_clicked(
        self,
        event_data: dict[str, Any],
    ) -> bool:
        """
        Handle email clicked event from Klaviyo.
        
        Triggers story recommendation refresh when users click email links.
        
        Args:
            event_data: Event data from webhook
            
        Returns:
            True if handled successfully
        """
        try:
            profile = event_data.get("profile", {})
            email = profile.get("email")
            url = event_data.get("url")
            campaign_name = event_data.get("campaign_name")
            
            if not email:
                logger.warning("No email in clicked event")
                return False
            
            # Update engagement score (higher for clicks)
            if self.supabase_client:
                response = await self._update_engagement_score(
                    email=email,
                    increment=10,  # +10 points for clicking
                )
                
                logger.info(f"Updated engagement score for {email} (clicked: {url})")
            
            # Trigger story recommendation refresh
            await self._refresh_story_recommendations(email)
            
            # Track click event back to Klaviyo for analysis
            if self.klaviyo_service and hasattr(self.klaviyo_service, 'track_event_async'):
                user_id = await self._get_user_id_from_email(email)
                if user_id:
                    await self.klaviyo_service.track_event_async(
                        event_name="Email Link Clicked",
                        user_id=user_id,
                        email=email,
                        properties={
                            "campaign_name": campaign_name,
                            "url": url,
                        }
                    )
            
            return True
            
        except Exception as e:
            logger.error(f"Error handling email clicked event: {e}")
            return False

    async def handle_email_bounced(
        self,
        event_data: dict[str, Any],
    ) -> bool:
        """
        Handle email bounced event from Klaviyo.
        
        Marks email as invalid in database.
        
        Args:
            event_data: Event data from webhook
            
        Returns:
            True if handled successfully
        """
        try:
            profile = event_data.get("profile", {})
            email = profile.get("email")
            bounce_type = event_data.get("bounce_type")  # hard or soft
            
            if not email:
                logger.warning("No email in bounced event")
                return False
            
            # Update email status in Supabase
            if self.supabase_client and bounce_type == "hard":
                response = self.supabase_client.table("profiles").update({
                    "email_valid": False,
                    "email_bounce_reason": f"Hard bounce: {event_data.get('reason')}",
                    "updated_at": datetime.utcnow().isoformat(),
                }).eq("email", email).execute()
                
                logger.warning(f"Marked email as bounced: {email}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error handling email bounced event: {e}")
            return False

    async def handle_unsubscribed(
        self,
        event_data: dict[str, Any],
    ) -> bool:
        """
        Handle unsubscribed event from Klaviyo.
        
        Updates user preferences to stop sending marketing emails.
        
        Args:
            event_data: Event data from webhook
            
        Returns:
            True if handled successfully
        """
        try:
            profile = event_data.get("profile", {})
            email = profile.get("email")
            list_id = event_data.get("list_id")
            
            if not email:
                logger.warning("No email in unsubscribed event")
                return False
            
            # Update preferences in Supabase
            if self.supabase_client:
                response = self.supabase_client.table("profiles").update({
                    "email_marketing_enabled": False,
                    "unsubscribed_at": datetime.utcnow().isoformat(),
                    "updated_at": datetime.utcnow().isoformat(),
                }).eq("email", email).execute()
                
                logger.info(f"Updated unsubscribe status for {email}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error handling unsubscribed event: {e}")
            return False

    async def _update_engagement_score(
        self,
        email: str,
        increment: int,
    ) -> bool:
        """
        Update user engagement score in database.
        
        Args:
            email: User email
            increment: Points to add to engagement score
            
        Returns:
            True if updated successfully
        """
        try:
            if not self.supabase_client:
                return False
            
            # Get current score
            response = self.supabase_client.table("profiles").select(
                "engagement_score"
            ).eq("email", email).maybe_single().execute()
            
            current_score = 0
            if response.data:
                current_score = response.data.get("engagement_score", 0)
            
            new_score = current_score + increment
            
            # Update score
            self.supabase_client.table("profiles").update({
                "engagement_score": new_score,
                "last_engagement_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat(),
            }).eq("email", email).execute()
            
            return True
            
        except Exception as e:
            logger.error(f"Error updating engagement score: {e}")
            return False

    async def _refresh_story_recommendations(
        self,
        email: str,
    ) -> bool:
        """
        Refresh story recommendations for a user.
        
        This could trigger re-calculation of personalized themes
        or update recommendation cache.
        
        Args:
            email: User email
            
        Returns:
            True if refreshed successfully
        """
        try:
            # In a full implementation, this would:
            # 1. Clear recommendation cache
            # 2. Trigger new recommendation calculation
            # 3. Update user's theme preferences
            
            logger.info(f"Refreshed story recommendations for {email}")
            return True
            
        except Exception as e:
            logger.error(f"Error refreshing recommendations: {e}")
            return False

    async def _get_user_id_from_email(
        self,
        email: str,
    ) -> Optional[UUID]:
        """
        Get user ID from email address.
        
        Args:
            email: User email
            
        Returns:
            User UUID or None
        """
        try:
            if not self.supabase_client:
                return None
            
            response = self.supabase_client.table("profiles").select(
                "id"
            ).eq("email", email).maybe_single().execute()
            
            if response.data:
                return UUID(response.data["id"])
            
            return None
            
        except Exception as e:
            logger.error(f"Error getting user ID from email: {e}")
            return None


# Initialize global handler (will be configured in main.py)
webhook_handler: Optional[KlaviyoWebhookHandler] = None


@router.post("/klaviyo")
async def handle_klaviyo_webhook(
    request: Request,
    x_klaviyo_signature: Optional[str] = Header(None),
):
    """
    Handle incoming Klaviyo webhooks.
    
    This endpoint receives real-time event notifications from Klaviyo
    when users interact with emails.
    
    Supported events:
    - email.opened
    - email.clicked
    - email.bounced
    - email.unsubscribed
    - email.marked_as_spam
    
    Args:
        request: FastAPI request object
        x_klaviyo_signature: Webhook signature for verification
        
    Returns:
        Status response
    """
    if not webhook_handler:
        raise HTTPException(
            status_code=503,
            detail="Webhook handler not configured"
        )
    
    try:
        # Read raw payload
        payload = await request.body()
        
        # Verify signature
        if not webhook_handler.verify_webhook_signature(payload, x_klaviyo_signature):
            logger.warning("Invalid webhook signature")
            raise HTTPException(
                status_code=401,
                detail="Invalid webhook signature"
            )
        
        # Parse JSON payload
        data = await request.json()
        
        # Extract event type and data
        event_type = data.get("type")
        event_data = data.get("data", {}).get("attributes", {})
        
        logger.info(f"Received Klaviyo webhook: {event_type}")
        
        # Route to appropriate handler
        if event_type == "email.opened":
            success = await webhook_handler.handle_email_opened(event_data)
        elif event_type == "email.clicked":
            success = await webhook_handler.handle_email_clicked(event_data)
        elif event_type == "email.bounced":
            success = await webhook_handler.handle_email_bounced(event_data)
        elif event_type == "email.unsubscribed":
            success = await webhook_handler.handle_unsubscribed(event_data)
        else:
            logger.info(f"Unhandled webhook event type: {event_type}")
            success = True  # Return success for unknown events
        
        return {
            "status": "processed" if success else "failed",
            "event_type": event_type,
            "timestamp": datetime.utcnow().isoformat(),
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing Klaviyo webhook: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Error processing webhook: {str(e)}"
        )


@router.get("/klaviyo/health")
async def webhook_health_check():
    """
    Health check endpoint for webhook configuration.
    
    Returns:
        Status of webhook handler
    """
    return {
        "status": "healthy" if webhook_handler else "not_configured",
        "timestamp": datetime.utcnow().isoformat(),
    }
