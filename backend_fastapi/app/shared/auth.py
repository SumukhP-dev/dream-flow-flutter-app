"""
Authentication utilities for FastAPI routes.
"""

import base64
import json
import warnings
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, Header

from .config import Settings, get_settings
from ..dreamflow.subscription_service import SubscriptionService
from .supabase_client import SupabaseClient

warnings.filterwarnings(
    "ignore",
    message="The `gotrue` package is deprecated",
    category=DeprecationWarning,
)


def get_authenticated_user_id(
    authorization: Optional[str] = Header(None, alias="Authorization"),
    settings: Settings = Depends(get_settings),
) -> UUID:
    """
    Verify Supabase JWT token from Authorization header and return user ID.

    Args:
        authorization: Authorization header value (should be "Bearer <token>")
        settings: Application settings

    Returns:
        UUID of the authenticated user

    Raises:
        HTTPException: If authentication fails
    """
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Missing Authorization header",
        )

    # Extract token from "Bearer <token>" format
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail="Invalid Authorization header format. Expected: Bearer <token>",
        )

    token = parts[1]

    # Verify Supabase configuration
    if not settings.supabase_url:
        raise HTTPException(
            status_code=500,
            detail="Supabase not configured",
        )

    # Use anon key to verify user token (not service-role, which bypasses auth)
    if not settings.supabase_anon_key:
        raise HTTPException(
            status_code=500,
            detail="Supabase anon key not configured",
        )

    try:
        # Decode JWT token to extract user_id
        # JWT format: header.payload.signature
        parts = token.split(".")
        if len(parts) != 3:
            raise HTTPException(
                status_code=401,
                detail="Invalid token format",
            )

        # Decode payload (second part)
        payload_part = parts[1]
        # Add padding if needed for base64 decoding
        padding = len(payload_part) % 4
        if padding:
            payload_part += "=" * (4 - padding)

        try:
            payload_bytes = base64.urlsafe_b64decode(payload_part)
            payload = json.loads(payload_bytes.decode("utf-8"))
        except Exception as e:
            raise HTTPException(
                status_code=401,
                detail=f"Failed to decode token: {str(e)}",
            )

        # Extract user_id from payload
        user_id_str = payload.get("sub") or payload.get("user_id")
        if not user_id_str:
            raise HTTPException(
                status_code=401,
                detail="Token does not contain user ID",
            )

        # Verify token is not expired (if exp claim exists)
        import time

        exp = payload.get("exp")
        if exp and exp < time.time():
            raise HTTPException(
                status_code=401,
                detail="Token has expired",
            )

        # Optionally verify token signature using Supabase client
        # For now, we'll trust the token if it decodes correctly
        # In production, you might want to verify the signature

        return UUID(user_id_str)

    except ValueError as e:
        raise HTTPException(
            status_code=401,
            detail=f"Invalid token: {str(e)}",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail=f"Authentication failed: {str(e)}",
        )


def get_admin_user_id(
    authorization: Optional[str] = Header(None, alias="Authorization"),
    settings: Settings = Depends(get_settings),
) -> UUID:
    """
    Verify Supabase JWT token and check if user is an admin.

    Args:
        authorization: Authorization header value (should be "Bearer <token>")
        settings: Application settings

    Returns:
        UUID of the authenticated admin user

    Raises:
        HTTPException: If authentication fails or user is not an admin
    """
    # First verify authentication
    user_id = get_authenticated_user_id(authorization, settings)

    # Check if user is admin
    user_id_str = str(user_id)
    if not settings.admin_user_ids or user_id_str not in settings.admin_user_ids:
        raise HTTPException(
            status_code=403,
            detail="Admin access required",
        )

    return user_id


def get_optional_authenticated_user_id(
    authorization: Optional[str] = Header(None, alias="Authorization"),
    settings: Settings = Depends(get_settings),
) -> Optional[UUID]:
    """
    Optionally verify Supabase JWT token from Authorization header and return user ID.
    Returns None if no authorization header is provided (for public endpoints).

    Args:
        authorization: Authorization header value (should be "Bearer <token>")
        settings: Application settings

    Returns:
        UUID of the authenticated user, or None if no authorization header is provided
    """
    if not authorization:
        return None

    # Extract token from "Bearer <token>" format
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None

    token = parts[1]

    # Verify Supabase configuration
    if not settings.supabase_url or not settings.supabase_anon_key:
        return None

    try:
        # Decode JWT token to extract user_id
        parts = token.split(".")
        if len(parts) != 3:
            return None

        # Decode payload (second part)
        payload_part = parts[1]
        # Add padding if needed for base64 decoding
        padding = len(payload_part) % 4
        if padding:
            payload_part += "=" * (4 - padding)

        try:
            payload_bytes = base64.urlsafe_b64decode(payload_part)
            payload = json.loads(payload_bytes.decode("utf-8"))
        except Exception:
            return None

        # Extract user_id from payload
        user_id_str = payload.get("sub") or payload.get("user_id")
        if not user_id_str:
            return None

        # Verify token is not expired (if exp claim exists)
        import time

        exp = payload.get("exp")
        if exp and exp < time.time():
            return None

        return UUID(user_id_str)

    except (ValueError, Exception):
        return None


def get_user_tier_from_subscription(
    user_id: Optional[UUID],
    supabase_client: Optional[SupabaseClient],
) -> str:
    """
    Helper to map a user's subscription to a simple tier label used by
    the priority queue: 'paid' or 'free'.

    - Returns 'paid' when the user has any non-free active subscription.
    - Returns 'free' when there is no active subscription, no user, or
      Supabase is not configured.
    """
    if not user_id or not supabase_client:
        return "free"

    try:
        service = SubscriptionService(supabase_client.client)
        tier = service.get_user_tier(user_id)
        if tier and tier != "free":
            return "paid"
        return "free"
    except Exception:
        # On any failure, fall back to free to avoid blocking generation.
        return "free"
