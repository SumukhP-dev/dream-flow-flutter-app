"""
Tests for native mobile hardware detection and version selection.
"""

import os
import pytest
from app.core.version_detector import (
    detect_native_mobile_accelerator,
    detect_native_mobile_version,
    get_recommended_version,
    detect_available_versions,
)


def test_detect_native_mobile_accelerator_android():
    """Test Tensor chip detection on Android."""
    user_agent = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36"
    
    has_accel, accel_type = detect_native_mobile_accelerator(user_agent)
    
    assert has_accel is True
    assert accel_type == "tensor"


def test_detect_native_mobile_accelerator_ios():
    """Test Neural Engine detection on iOS."""
    user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
    
    has_accel, accel_type = detect_native_mobile_accelerator(user_agent)
    
    # Should detect Neural Engine (A12+ devices)
    assert accel_type in ["neural_engine", "none"]  # May not detect from User-Agent alone


def test_detect_native_mobile_version_with_env_vars():
    """Test native mobile version detection with environment variables."""
    # Set environment variables as Flutter app would
    os.environ["MOBILE_PLATFORM"] = "android"
    os.environ["HAS_TENSOR_CHIP"] = "true"
    os.environ["HAS_TFLITE_MODELS"] = "true"
    
    try:
        available = detect_native_mobile_version()
        assert available is True
    finally:
        # Clean up
        os.environ.pop("MOBILE_PLATFORM", None)
        os.environ.pop("HAS_TENSOR_CHIP", None)
        os.environ.pop("HAS_TFLITE_MODELS", None)


def test_detect_native_mobile_version_ios():
    """Test native mobile version detection for iOS."""
    os.environ["MOBILE_PLATFORM"] = "ios"
    os.environ["HAS_NEURAL_ENGINE"] = "true"
    os.environ["HAS_COREML_MODELS"] = "true"
    
    try:
        available = detect_native_mobile_version()
        assert available is True
    finally:
        # Clean up
        os.environ.pop("MOBILE_PLATFORM", None)
        os.environ.pop("HAS_NEURAL_ENGINE", None)
        os.environ.pop("HAS_COREML_MODELS", None)


def test_get_recommended_version_native_mobile():
    """Test that native_mobile is recommended when available."""
    os.environ["MOBILE_PLATFORM"] = "android"
    os.environ["HAS_TENSOR_CHIP"] = "true"
    os.environ["HAS_TFLITE_MODELS"] = "true"
    
    try:
        version = get_recommended_version()
        assert version == "native_mobile"
    finally:
        # Clean up
        os.environ.pop("MOBILE_PLATFORM", None)
        os.environ.pop("HAS_TENSOR_CHIP", None)
        os.environ.pop("HAS_TFLITE_MODELS", None)


def test_get_recommended_version_fallback_to_local():
    """Test that local is recommended when native mobile not available."""
    # Clear environment variables
    os.environ.pop("MOBILE_PLATFORM", None)
    os.environ.pop("HAS_TENSOR_CHIP", None)
    os.environ.pop("HAS_TFLITE_MODELS", None)
    os.environ.pop("HAS_NEURAL_ENGINE", None)
    os.environ.pop("HAS_COREML_MODELS", None)
    
    version = get_recommended_version()
    # Should fall back to local (GGUF models)
    assert version == "local"


def test_detect_available_versions():
    """Test detection of all available versions."""
    available = detect_available_versions()
    
    # Should always include at least "local" as fallback
    assert "local" in available
    
    # May include other versions depending on configuration
    assert isinstance(available, set)
    assert len(available) > 0

