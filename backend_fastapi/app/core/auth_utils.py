"""
Authentication utilities for Dream Flow.

This module provides helper functions for JWT token handling and email extraction.
"""

import logging
from typing import Optional
from uuid import UUID
import jwt
from fastapi import Request

logger = logging.getLogger("dream_flow")


def extract_email_from_jwt(request: Request) -> Optional[str]:
    """
    Extract email from JWT token in request headers.
    
    This function parses the Authorization header and extracts the email
    from the JWT payload. It does not verify the signature since that's
    handled by Supabase middleware.
    
    Args:
        request: FastAPI Request object
        
    Returns:
        User email if found in token, None otherwise
    """
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return None
            
        token = auth_header.replace("Bearer ", "")
        
        # Decode without verification (signature already verified by middleware)
        payload = jwt.decode(token, options={"verify_signature": False})
        
        # Supabase JWT tokens have email in the payload
        email = payload.get("email")
        
        if email:
            logger.debug(f"Extracted email from JWT: {email}")
            return email
        else:
            logger.debug("No email found in JWT payload")
            return None
            
    except jwt.DecodeError as e:
        logger.warning(f"Failed to decode JWT token: {e}")
        return None
    except Exception as e:
        logger.warning(f"Error extracting email from JWT: {e}")
        return None


def extract_user_id_from_jwt(request: Request) -> Optional[UUID]:
    """
    Extract user ID from JWT token in request headers.
    
    Args:
        request: FastAPI Request object
        
    Returns:
        User ID (UUID) if found in token, None otherwise
    """
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return None
            
        token = auth_header.replace("Bearer ", "")
        payload = jwt.decode(token, options={"verify_signature": False})
        
        # Supabase JWT tokens have 'sub' claim with user ID
        user_id_str = payload.get("sub")
        
        if user_id_str:
            return UUID(user_id_str)
        else:
            return None
            
    except (jwt.DecodeError, ValueError) as e:
        logger.warning(f"Failed to extract user ID from JWT: {e}")
        return None
    except Exception as e:
        logger.warning(f"Error extracting user ID from JWT: {e}")
        return None


def get_user_context_from_jwt(request: Request) -> dict[str, Optional[str]]:
    """
    Extract complete user context from JWT token.
    
    Returns email, user_id, and other relevant user information from the JWT.
    
    Args:
        request: FastAPI Request object
        
    Returns:
        Dictionary with user context information
    """
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return {}
            
        token = auth_header.replace("Bearer ", "")
        payload = jwt.decode(token, options={"verify_signature": False})
        
        return {
            "email": payload.get("email"),
            "user_id": payload.get("sub"),
            "role": payload.get("role"),
            "phone": payload.get("phone"),
            "email_confirmed": payload.get("email_confirmed_at") is not None,
        }
            
    except Exception as e:
        logger.warning(f"Error extracting user context from JWT: {e}")
        return {}
