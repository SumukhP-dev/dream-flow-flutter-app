"""
Content moderation service for story sharing.

Provides automated content filtering and human review workflow for public stories.
"""

import logging
from typing import Optional
from uuid import UUID

from .guardrails import ContentGuard, GuardrailMode, GuardrailViolation
from ..shared.supabase_client import SupabaseClient

logger = logging.getLogger(__name__)


class ModerationResult:
    """Result of content moderation check."""

    def __init__(
        self,
        approved: bool,
        requires_review: bool,
        violations: list[GuardrailViolation],
        confidence: float = 1.0,
    ):
        self.approved = approved
        self.requires_review = requires_review
        self.violations = violations
        self.confidence = confidence  # 0.0 to 1.0, higher = more confident in approval


class ContentModerationService:
    """Service for moderating user-generated content before public sharing."""

    def __init__(self, supabase_client: Optional[SupabaseClient] = None):
        """
        Initialize content moderation service.

        Args:
            supabase_client: Optional Supabase client for database operations
        """
        self.guard = ContentGuard(mode=GuardrailMode.BEDTIME_SAFETY)
        self.supabase = supabase_client
        # Confidence threshold: if violations are minor and confidence is high, auto-approve
        self.auto_approve_confidence_threshold = 0.9
        # Maximum violations for auto-approval
        self.max_violations_for_auto_approve = 0

    def moderate_story(
        self,
        story_text: str,
        session_id: Optional[UUID] = None,
        user_id: Optional[UUID] = None,
        child_mode: bool = False,
        content_filter_level: str = "standard",
    ) -> ModerationResult:
        """
        Moderate a story for public sharing.

        Args:
            story_text: Story text to moderate
            session_id: Optional session ID for logging
            user_id: Optional user ID for logging
            child_mode: If True, apply stricter child-safe filters
            content_filter_level: Filter level: 'strict', 'standard', or 'relaxed'

        Returns:
            ModerationResult with approval status and violations
        """
        # Run content guard check
        violations = self.guard.check_story(
            story_text=story_text,
            profile=None,
            child_mode=child_mode,
            content_filter_level=content_filter_level,
        )

        # Determine if story should be auto-approved or require review
        if len(violations) == 0:
            # No violations - auto-approve
            approved = True
            requires_review = False
            confidence = 1.0
        elif len(violations) <= self.max_violations_for_auto_approve:
            # Minor violations - check severity
            severity = self._calculate_severity(violations)
            if severity < 0.3:  # Low severity
                approved = True
                requires_review = False
                confidence = 0.85
            else:
                approved = False
                requires_review = True
                confidence = 0.7
        else:
            # Multiple or severe violations - require review
            approved = False
            requires_review = True
            confidence = 0.5

        result = ModerationResult(
            approved=approved,
            requires_review=requires_review,
            violations=violations,
            confidence=confidence,
        )

        # Log moderation result
        logger.info(
            f"Story moderation: session_id={session_id}, "
            f"approved={approved}, violations={len(violations)}, "
            f"requires_review={requires_review}"
        )

        # If review is required, create moderation queue item
        if requires_review and self.supabase and session_id:
            try:
                self._create_moderation_queue_item(
                    session_id=session_id,
                    user_id=user_id,
                    story_text=story_text,
                    violations=violations,
                )
            except Exception as e:
                logger.error(f"Failed to create moderation queue item: {e}")

        return result

    def _calculate_severity(self, violations: list[GuardrailViolation]) -> float:
        """
        Calculate severity score for violations (0.0 to 1.0).

        Args:
            violations: List of guardrail violations

        Returns:
            Severity score (higher = more severe)
        """
        if not violations:
            return 0.0

        # Weight different violation types
        severity_weights = {
            "safety": 1.0,  # Safety violations are most severe
            "tone": 0.5,  # Tone violations are less severe
            "content": 0.8,  # Content violations are moderately severe
        }

        total_severity = 0.0
        for violation in violations:
            weight = severity_weights.get(violation.category, 0.5)
            total_severity += weight

        # Normalize to 0.0-1.0 range
        max_severity = len(violations) * 1.0
        return min(total_severity / max_severity, 1.0) if max_severity > 0 else 0.0

    def _create_moderation_queue_item(
        self,
        session_id: UUID,
        user_id: Optional[UUID],
        story_text: str,
        violations: list[GuardrailViolation],
    ) -> None:
        """
        Create a moderation queue item for human review.

        Args:
            session_id: Session ID of the story
            user_id: User ID who created the story
            story_text: Story text to review
            violations: List of violations found
        """
        if not self.supabase:
            return

        violations_dict = [
            {"category": v.category, "detail": v.detail} for v in violations
        ]

        try:
            self.supabase.create_moderation_item(
                content=story_text,
                content_type="story",
                user_id=user_id,
                session_id=session_id,
                violations=violations_dict,
            )
        except Exception as e:
            logger.error(f"Failed to create moderation queue item: {e}")
            raise

    def approve_story(
        self, session_id: UUID, reviewer_id: Optional[UUID] = None
    ) -> bool:
        """
        Approve a story after human review.

        Args:
            session_id: Session ID of the story to approve
            reviewer_id: Optional ID of the reviewer

        Returns:
            True if approval was successful
        """
        if not self.supabase:
            return False

        try:
            # Update session to mark as approved
            (
                self.supabase.client.table("sessions")
                .update({"is_approved": True})
                .eq("id", str(session_id))
                .execute()
            )

            # Mark moderation queue item as resolved
            # Note: This assumes moderation_queue table exists
            # If it doesn't, we'll skip this step
            try:
                (
                    self.supabase.client.table("moderation_queue")
                    .update(
                        {
                            "status": "resolved",
                            "resolved_by": str(reviewer_id) if reviewer_id else None,
                            "resolved_at": "now()",
                        }
                    )
                    .eq("session_id", str(session_id))
                    .eq("status", "pending")
                    .execute()
                )
            except Exception:
                # Moderation queue might not exist or item might not exist
                logger.debug("Could not update moderation queue (may not exist)")

            logger.info(f"Story approved: session_id={session_id}, reviewer_id={reviewer_id}")
            return True

        except Exception as e:
            logger.error(f"Failed to approve story: {e}")
            return False

    def reject_story(
        self,
        session_id: UUID,
        reviewer_id: Optional[UUID] = None,
        reason: Optional[str] = None,
    ) -> bool:
        """
        Reject a story after human review.

        Args:
            session_id: Session ID of the story to reject
            reviewer_id: Optional ID of the reviewer
            reason: Optional rejection reason

        Returns:
            True if rejection was successful
        """
        if not self.supabase:
            return False

        try:
            # Update session to mark as not approved and make private
            (
                self.supabase.client.table("sessions")
                .update(
                    {
                        "is_approved": False,
                        "is_public": False,  # Make private if rejected
                    }
                )
                .eq("id", str(session_id))
                .execute()
            )

            # Mark moderation queue item as rejected
            try:
                (
                    self.supabase.client.table("moderation_queue")
                    .update(
                        {
                            "status": "rejected",
                            "resolved_by": str(reviewer_id) if reviewer_id else None,
                            "resolved_at": "now()",
                            "resolution_notes": reason,
                        }
                    )
                    .eq("session_id", str(session_id))
                    .eq("status", "pending")
                    .execute()
                )
            except Exception:
                logger.debug("Could not update moderation queue (may not exist)")

            logger.info(
                f"Story rejected: session_id={session_id}, "
                f"reviewer_id={reviewer_id}, reason={reason}"
            )
            return True

        except Exception as e:
            logger.error(f"Failed to reject story: {e}")
            return False

    def get_pending_reviews(
        self, limit: int = 20, offset: int = 0
    ) -> list[dict]:
        """
        Get stories pending human review.

        Args:
            limit: Maximum number of items to return
            offset: Number of items to skip

        Returns:
            List of stories pending review
        """
        if not self.supabase:
            return []

        try:
            # Get sessions that are public but not approved
            response = (
                self.supabase.client.table("sessions")
                .select("id, theme, prompt, story_text, user_id, created_at")
                .eq("is_public", True)
                .eq("is_approved", False)
                .order("created_at", desc=False)  # Oldest first
                .range(offset, offset + limit - 1)
                .execute()
            )

            return response.data if response.data else []

        except Exception as e:
            logger.error(f"Failed to get pending reviews: {e}")
            return []

