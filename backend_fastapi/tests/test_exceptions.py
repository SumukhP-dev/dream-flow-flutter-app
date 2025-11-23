"""
Unit tests for custom exceptions.

Tests ensure:
- All exception types are properly defined
- Exception attributes are correctly set
- Exception messages are formatted correctly
"""

import pytest

from app.exceptions import (
    HuggingFaceError,
    HuggingFaceTimeoutError,
    HuggingFaceRateLimitError,
    HuggingFaceModelError,
    HuggingFaceConnectionError,
)


class TestHuggingFaceError:
    """Tests for HuggingFaceError base exception."""

    def test_base_exception_creation(self):
        """Test creating base HuggingFaceError."""
        error = HuggingFaceError(
            message="Test error",
            model_id="test/model",
            status_code=500,
            details={"key": "value"}
        )
        
        assert str(error) == "Test error"
        assert error.message == "Test error"
        assert error.model_id == "test/model"
        assert error.status_code == 500
        assert error.details == {"key": "value"}

    def test_base_exception_minimal(self):
        """Test creating base HuggingFaceError with minimal args."""
        error = HuggingFaceError(message="Test error")
        
        assert error.message == "Test error"
        assert error.model_id is None
        assert error.status_code is None
        assert error.details == {}


class TestHuggingFaceTimeoutError:
    """Tests for HuggingFaceTimeoutError."""

    def test_timeout_error_creation(self):
        """Test creating timeout error."""
        error = HuggingFaceTimeoutError(
            message="Request timed out",
            model_id="test/model",
            details={"timeout": 120}
        )
        
        assert isinstance(error, HuggingFaceError)
        assert error.message == "Request timed out"
        assert error.model_id == "test/model"
        assert error.details == {"timeout": 120}


class TestHuggingFaceRateLimitError:
    """Tests for HuggingFaceRateLimitError."""

    def test_rate_limit_error_creation(self):
        """Test creating rate limit error."""
        error = HuggingFaceRateLimitError(
            message="Rate limit exceeded",
            model_id="test/model",
            status_code=429,
            details={"retry_after": 60}
        )
        
        assert isinstance(error, HuggingFaceError)
        assert error.message == "Rate limit exceeded"
        assert error.status_code == 429
        assert error.details == {"retry_after": 60}


class TestHuggingFaceModelError:
    """Tests for HuggingFaceModelError."""

    def test_model_error_creation(self):
        """Test creating model error."""
        error = HuggingFaceModelError(
            message="Model error",
            model_id="test/model",
            details={"error_type": "inference"}
        )
        
        assert isinstance(error, HuggingFaceError)
        assert error.message == "Model error"
        assert error.model_id == "test/model"


class TestHuggingFaceConnectionError:
    """Tests for HuggingFaceConnectionError."""

    def test_connection_error_creation(self):
        """Test creating connection error."""
        error = HuggingFaceConnectionError(
            message="Connection failed",
            model_id="test/model",
            details={"host": "api.huggingface.co"}
        )
        
        assert isinstance(error, HuggingFaceError)
        assert error.message == "Connection failed"
        assert error.model_id == "test/model"


class TestExceptionInheritance:
    """Tests for exception inheritance hierarchy."""

    def test_all_errors_inherit_from_base(self):
        """Test that all error types inherit from HuggingFaceError."""
        timeout = HuggingFaceTimeoutError("Timeout", model_id="test")
        rate_limit = HuggingFaceRateLimitError("Rate limit", model_id="test")
        model = HuggingFaceModelError("Model error", model_id="test")
        connection = HuggingFaceConnectionError("Connection error", model_id="test")
        
        assert isinstance(timeout, HuggingFaceError)
        assert isinstance(rate_limit, HuggingFaceError)
        assert isinstance(model, HuggingFaceError)
        assert isinstance(connection, HuggingFaceError)

    def test_exception_raising(self):
        """Test that exceptions can be raised and caught."""
        with pytest.raises(HuggingFaceError):
            raise HuggingFaceTimeoutError("Timeout", model_id="test")
        
        with pytest.raises(HuggingFaceRateLimitError):
            raise HuggingFaceRateLimitError("Rate limit", model_id="test")

