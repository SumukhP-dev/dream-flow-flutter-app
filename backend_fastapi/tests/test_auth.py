"""
Unit tests for authentication utilities.

Tests ensure:
- JWT token validation works correctly
- User ID extraction from tokens
- Admin user verification
- Error handling for invalid/missing tokens
"""

import base64
import json
import time
import pytest
from unittest.mock import MagicMock, patch
from uuid import uuid4, UUID
from fastapi import HTTPException

from app.auth import get_authenticated_user_id, get_admin_user_id
from app.config import Settings


def create_mock_jwt_token(user_id: UUID, expires_in: int = 3600) -> str:
    """Create a mock JWT token for testing."""
    # Create a simple mock JWT payload
    payload = {
        "sub": str(user_id),
        "exp": int(time.time()) + expires_in,
    }
    
    # Encode payload as base64
    payload_json = json.dumps(payload)
    payload_b64 = base64.urlsafe_b64encode(payload_json.encode()).decode().rstrip('=')
    
    # Return a mock JWT token (header.payload.signature)
    return f"header.{payload_b64}.signature"


class TestGetAuthenticatedUserId:
    """Tests for get_authenticated_user_id function."""

    def test_valid_token_returns_user_id(self):
        """Test that valid token returns user ID."""
        user_id = uuid4()
        token = create_mock_jwt_token(user_id)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        
        result = get_authenticated_user_id(
            authorization=f"Bearer {token}",
            settings=mock_settings
        )
        
        assert result == user_id

    def test_missing_authorization_header(self):
        """Test that missing authorization header raises 401."""
        mock_settings = MagicMock(spec=Settings)
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization=None,
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 401
        assert "Authorization" in exc_info.value.detail

    def test_invalid_authorization_format(self):
        """Test that invalid authorization format raises 401."""
        mock_settings = MagicMock(spec=Settings)
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization="InvalidFormat token",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 401
        assert "Invalid Authorization header format" in exc_info.value.detail

    def test_invalid_token_format(self):
        """Test that invalid token format raises 401."""
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization="Bearer invalid.token",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 401
        assert "Invalid token format" in exc_info.value.detail

    def test_token_without_user_id(self):
        """Test that token without user_id raises 401."""
        # Create token without sub or user_id
        payload = {"exp": int(time.time()) + 3600}
        payload_json = json.dumps(payload)
        payload_b64 = base64.urlsafe_b64encode(payload_json.encode()).decode().rstrip('=')
        token = f"header.{payload_b64}.signature"
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization=f"Bearer {token}",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 401
        assert "user ID" in exc_info.value.detail

    def test_expired_token(self):
        """Test that expired token raises 401."""
        user_id = uuid4()
        # Create expired token (expires 1 hour ago)
        token = create_mock_jwt_token(user_id, expires_in=-3600)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization=f"Bearer {token}",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 401
        assert "expired" in exc_info.value.detail.lower()

    def test_supabase_not_configured(self):
        """Test that missing Supabase URL raises 500."""
        user_id = uuid4()
        token = create_mock_jwt_token(user_id)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = None
        mock_settings.supabase_anon_key = "test_anon_key"
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization=f"Bearer {token}",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 500
        assert "Supabase not configured" in exc_info.value.detail

    def test_anon_key_not_configured(self):
        """Test that missing anon key raises 500."""
        user_id = uuid4()
        token = create_mock_jwt_token(user_id)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = None
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization=f"Bearer {token}",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 500
        assert "anon key not configured" in exc_info.value.detail

    def test_token_with_user_id_field(self):
        """Test that token with user_id field (instead of sub) works."""
        user_id = uuid4()
        payload = {
            "user_id": str(user_id),
            "exp": int(time.time()) + 3600,
        }
        payload_json = json.dumps(payload)
        payload_b64 = base64.urlsafe_b64encode(payload_json.encode()).decode().rstrip('=')
        token = f"header.{payload_b64}.signature"
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        
        result = get_authenticated_user_id(
            authorization=f"Bearer {token}",
            settings=mock_settings
        )
        
        assert result == user_id

    def test_invalid_base64_payload(self):
        """Test that invalid base64 payload raises 401."""
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        
        # Create token with invalid base64
        token = "header.invalid-base64!!!.signature"
        
        with pytest.raises(HTTPException) as exc_info:
            get_authenticated_user_id(
                authorization=f"Bearer {token}",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 401
        assert "Failed to decode token" in exc_info.value.detail


class TestGetAdminUserId:
    """Tests for get_admin_user_id function."""

    def test_admin_user_returns_user_id(self):
        """Test that admin user returns user ID."""
        user_id = uuid4()
        token = create_mock_jwt_token(user_id)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        mock_settings.admin_user_ids = [str(user_id)]
        
        result = get_admin_user_id(
            authorization=f"Bearer {token}",
            settings=mock_settings
        )
        
        assert result == user_id

    def test_non_admin_user_raises_403(self):
        """Test that non-admin user raises 403."""
        user_id = uuid4()
        token = create_mock_jwt_token(user_id)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        mock_settings.admin_user_ids = [str(uuid4())]  # Different user
        
        with pytest.raises(HTTPException) as exc_info:
            get_admin_user_id(
                authorization=f"Bearer {token}",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 403
        assert "Admin access required" in exc_info.value.detail

    def test_empty_admin_list_raises_403(self):
        """Test that empty admin list raises 403."""
        user_id = uuid4()
        token = create_mock_jwt_token(user_id)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        mock_settings.admin_user_ids = []
        
        with pytest.raises(HTTPException) as exc_info:
            get_admin_user_id(
                authorization=f"Bearer {token}",
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 403

    def test_admin_user_with_multiple_admins(self):
        """Test that admin check works with multiple admin users."""
        user_id = uuid4()
        other_admin = uuid4()
        token = create_mock_jwt_token(user_id)
        
        mock_settings = MagicMock(spec=Settings)
        mock_settings.supabase_url = "https://test.supabase.co"
        mock_settings.supabase_anon_key = "test_anon_key"
        mock_settings.admin_user_ids = [str(user_id), str(other_admin)]
        
        result = get_admin_user_id(
            authorization=f"Bearer {token}",
            settings=mock_settings
        )
        
        assert result == user_id

    def test_admin_user_inherits_auth_errors(self):
        """Test that admin check inherits authentication errors."""
        mock_settings = MagicMock(spec=Settings)
        
        # Missing authorization should raise 401 (from get_authenticated_user_id)
        with pytest.raises(HTTPException) as exc_info:
            get_admin_user_id(
                authorization=None,
                settings=mock_settings
            )
        
        assert exc_info.value.status_code == 401

