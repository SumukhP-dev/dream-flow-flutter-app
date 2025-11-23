"""Custom exceptions for structured error handling."""

from typing import Any, Optional


class HuggingFaceError(Exception):
    """Base exception for HuggingFace API errors."""
    
    def __init__(
        self,
        message: str,
        model_id: Optional[str] = None,
        status_code: Optional[int] = None,
        details: Optional[dict[str, Any]] = None,
    ):
        super().__init__(message)
        self.message = message
        self.model_id = model_id
        self.status_code = status_code
        self.details = details or {}


class HuggingFaceTimeoutError(HuggingFaceError):
    """Raised when a HuggingFace API request times out."""
    pass


class HuggingFaceRateLimitError(HuggingFaceError):
    """Raised when HuggingFace API rate limit is exceeded."""
    pass


class HuggingFaceModelError(HuggingFaceError):
    """Raised when there's an error with the model or inference."""
    pass


class HuggingFaceConnectionError(HuggingFaceError):
    """Raised when there's a connection error to HuggingFace API."""
    pass

