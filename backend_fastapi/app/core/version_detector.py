"""
Version detection system for multi-version backend architecture.

Detects available inference versions (local, Apple) and recommends
the best version based on hardware and configuration.
"""

import os
import platform
import logging
import re
from typing import Literal, Set
from pathlib import Path

from ..shared.config import get_settings

logger = logging.getLogger(__name__)

InferenceVersion = Literal["local", "apple", "native_mobile", "auto"]


def detect_local_version() -> bool:
    """
    Check if local inference is available.
    
    Returns:
        True if local models and dependencies are available
    """
    try:
        import llama_cpp
        import edge_tts
        
        settings = get_settings()
        # Check if model file exists or can be downloaded
        model_path = Path(settings.local_model_path)
        if model_path.exists() or settings.local_model_path:
            return True
        
        # Check for diffusers for image generation
        try:
            import diffusers
            import torch
            return True
        except ImportError:
            # Images might not be available, but story/narration can still work
            return True
    except ImportError:
        return False



def detect_native_mobile_accelerator(user_agent: str | None = None) -> tuple[bool, str]:
    """
    Detect if native mobile hardware accelerators are available.
    
    This checks for:
    - Android: Tensor chip (Pixel devices) or NPU availability
    - iOS: Neural Engine (A12 Bionic and later)
    
    Args:
        user_agent: User-Agent header from request (optional)
        
    Returns:
        Tuple of (is_available, accelerator_type)
        accelerator_type: "tensor" (Android), "neural_engine" (iOS), or "none"
    """
    if not user_agent:
        # Try to detect from platform if running on mobile
        try:
            # Check if we're in a mobile environment via environment variables
            # This would be set by the mobile app when bundling Python
            mobile_platform = os.getenv("MOBILE_PLATFORM", "").lower()
            if mobile_platform == "android":
                # Check for Tensor chip via Android system properties
                # In a bundled Python environment, this would need to be passed from Java/Kotlin
                has_tensor = os.getenv("HAS_TENSOR_CHIP", "false").lower() == "true"
                if has_tensor:
                    return True, "tensor"
            elif mobile_platform == "ios":
                # Check for Neural Engine
                # In a bundled Python environment, this would need to be passed from Swift/Objective-C
                has_neural_engine = os.getenv("HAS_NEURAL_ENGINE", "false").lower() == "true"
                if has_neural_engine:
                    return True, "neural_engine"
        except Exception:
            pass
        return False, "none"
    
    user_agent_lower = user_agent.lower()
    
    # Detect iOS with Neural Engine (A12 Bionic and later)
    # Neural Engine is available on iPhone XS and later, iPad Pro 2018 and later
    if "iphone" in user_agent_lower or "ipad" in user_agent_lower:
        # Check for newer iOS devices (A12+)
        # In production, you'd check device model via a header or API
        # For now, we assume modern iOS devices have Neural Engine
        ios_version_match = re.search(r"OS (\d+)[_\.](\d+)", user_agent)
        if ios_version_match:
            major_version = int(ios_version_match.group(1))
            if major_version >= 12:  # iOS 12+ typically means A12 Bionic or later
                # Additional check: device model passed from app
                has_neural_engine = os.getenv("HAS_NEURAL_ENGINE", "true").lower() == "true"
                if has_neural_engine:
                    return True, "neural_engine"
    
    # Detect Android with Tensor chip (Pixel 6 and later)
    if "android" in user_agent_lower:
        # Pixel devices with Tensor chip
        if "pixel" in user_agent_lower:
            # Pixel 6, 6 Pro, 7, 7 Pro, 8, 8 Pro, etc. have Tensor chips
            pixel_model_match = re.search(r"Pixel (\d+)", user_agent)
            if pixel_model_match:
                pixel_number = int(pixel_model_match.group(1))
                if pixel_number >= 6:  # Pixel 6+ have Tensor chips
                    return True, "tensor"
        
        # Check for NPU/neural processing via environment variable (set by mobile app)
        has_npu = os.getenv("HAS_NPU", "false").lower() == "true"
        if has_npu:
            return True, "npu"  # Generic NPU on non-Pixel Android devices
    
    return False, "none"


def detect_native_mobile_version(user_agent: str | None = None) -> bool:
    """
    Check if native mobile accelerator (Tensor/Neural Engine) is available.
    
    This is for use when the backend is bundled into the mobile app.
    
    Args:
        user_agent: User-Agent header from request (optional)
        
    Returns:
        True if native mobile accelerator is available
    """
    has_accelerator, accelerator_type = detect_native_mobile_accelerator(user_agent)
    
    if has_accelerator:
        logger.info(f"Native mobile accelerator detected: {accelerator_type}")
        
        # Check if native ML models are available (TFLite for Android, Core ML for iOS)
        try:
            mobile_platform = os.getenv("MOBILE_PLATFORM", "").lower()
            if not mobile_platform and user_agent:
                if "android" in user_agent.lower():
                    mobile_platform = "android"
                elif "iphone" in user_agent.lower() or "ipad" in user_agent.lower():
                    mobile_platform = "ios"
            
            if mobile_platform == "android":
                # Check for TFLite models in assets
                # This would be checked via Flutter/Java code that sets env var
                has_tflite_models = os.getenv("HAS_TFLITE_MODELS", "false").lower() == "true"
                return has_tflite_models
            elif mobile_platform == "ios":
                # Check for Core ML models in bundle
                # This would be checked via Flutter/Swift code that sets env var
                has_coreml_models = os.getenv("HAS_COREML_MODELS", "false").lower() == "true"
                return has_coreml_models
        except Exception as e:
            logger.debug(f"Error checking native mobile models: {e}")
    
    return False


def detect_apple_version() -> bool:
    """
    Check if Apple Intelligence API or Apple Silicon server is available.
    
    Returns:
        True if Apple Intelligence API is configured or running on Apple Silicon
    """
    # Apple Intelligence API is not yet available - disable by default
    # Set ENABLE_APPLE_INTELLIGENCE=true to enable (when API becomes available)
    enable_apple = os.getenv("ENABLE_APPLE_INTELLIGENCE", "false").lower() == "true"
    if not enable_apple:
        logger.debug("Apple Intelligence API is disabled by default. Set ENABLE_APPLE_INTELLIGENCE=true to enable.")
        return False
    
    settings = get_settings()
    
    # Check for Apple Intelligence API credentials
    if settings.apple_intelligence_api_key:
        logger.warning(
            "Apple Intelligence API is enabled but the API is not yet available. "
            "This will fail in production. Consider disabling until API is released."
        )
        return True
    
    # Check if running on Apple Silicon (arm64) - only if explicitly enabled
    machine = platform.machine().lower()
    if machine == "arm64":
        # Check if we're on macOS (Apple Silicon)
        if platform.system() == "Darwin":
            logger.info("Apple Silicon server detected, but Apple Intelligence API is not available yet")
            return False  # Don't enable even on Apple Silicon until API is available
    
    return False


def detect_available_versions(user_agent: str | None = None) -> Set[InferenceVersion]:
    """
    Detect all available inference versions.
    
    Since FastAPI backend always runs on servers, we optimize for server deployment:
    - Skip expensive mobile hardware detection (servers don't have Tensor chips/Neural Engines)
    - Focus on local models + cloud API fallback
    
    Args:
        user_agent: User-Agent header from request (optional, for override detection)
    
    Returns:
        Set of available version strings (excluding "auto")
    """
    available = set()
    
    # For server deployments, only check what's actually relevant
    logger.debug("Server deployment - checking available local models and cloud APIs")
    
    # Check for local GGUF models (primary option for servers)
    if detect_local_version():
        available.add("local")
        logger.debug("Local GGUF models detected and available")
    
    # Only check mobile/Apple if explicitly requested via environment variable
    if os.getenv("ENABLE_MOBILE_DETECTION", "false").lower() == "true":
        logger.info("Mobile detection explicitly enabled - checking native accelerators")
        
        if detect_native_mobile_version(user_agent):
            available.add("native_mobile")
            logger.info("Native mobile accelerator (Tensor/Neural Engine) detected")
        
        if detect_apple_version():
            available.add("apple")
            logger.info("Apple Intelligence API detected")
    else:
        logger.debug("Mobile detection disabled for server deployment (use ENABLE_MOBILE_DETECTION=true to override)")
    
    # Local is always available as fallback (falls back to cloud APIs)
    if not available:
        available.add("local")
        logger.debug("No specific versions detected - using 'local' (cloud API fallback)")
    
    return available


def is_cloud_deployment() -> bool:
    """
    Detect if we're running in a cloud server environment.
    
    This prevents trying to detect mobile hardware (Tensor chips, Neural Engines)
    on cloud platforms where they don't exist.
    
    Returns:
        True if running in cloud environment (Azure, AWS, GCP, etc.)
    """
    # Allow manual override for testing/special cases
    force_cloud = os.getenv("FORCE_CLOUD_DEPLOYMENT", "false").lower() == "true"
    if force_cloud:
        logger.info("Cloud deployment forced via FORCE_CLOUD_DEPLOYMENT=true")
        return True
    
    force_local = os.getenv("FORCE_LOCAL_DEPLOYMENT", "false").lower() == "true" 
    if force_local:
        logger.info("Local deployment forced via FORCE_LOCAL_DEPLOYMENT=true")
        return False
    
    # Check for cloud platform environment indicators
    cloud_indicators = [
        # Azure
        ("WEBSITE_SITE_NAME", "Azure App Service"),
        ("AZURE_CLIENT_ID", "Azure with Managed Identity"),
        ("APPLICATIONINSIGHTS_CONNECTION_STRING", "Azure with App Insights"),
        
        # AWS
        ("AWS_LAMBDA_FUNCTION_NAME", "AWS Lambda"),
        ("AWS_EC2_INSTANCE_ID", "AWS EC2"),
        ("AWS_EXECUTION_ENV", "AWS execution environment"),
        ("AWS_REGION", "AWS with region configured"),
        
        # Other cloud providers
        ("HEROKU_APP_NAME", "Heroku"),
        ("RENDER_SERVICE_NAME", "Render"),
        ("RAILWAY_ENVIRONMENT", "Railway"),
        ("VERCEL", "Vercel"),
        ("FLY_APP_NAME", "Fly.io"),
        ("DETA_PROJECT_KEY", "Deta"),
        
        # Container platforms (often cloud)
        ("CONTAINER_NAME", "Docker container"),
        ("KUBERNETES_SERVICE_HOST", "Kubernetes"),
    ]
    
    detected_platform = None
    for env_var, platform_name in cloud_indicators:
        value = os.getenv(env_var, "").strip()
        if value:
            detected_platform = platform_name
            logger.info(f"Cloud deployment detected via {env_var}: {platform_name}")
            return True
    
    # Check for Docker container (often indicates cloud deployment)
    if os.path.exists("/.dockerenv"):
        logger.info("Docker container detected (/.dockerenv exists) - likely cloud deployment")
        return True
    
    if os.getenv("DOCKER_CONTAINER"):
        logger.info("Docker container detected via DOCKER_CONTAINER env var")
        return True
    
    # Check hostname patterns (cloud instances often have generated hostnames)
    hostname = os.getenv("HOSTNAME", "").lower()
    if hostname:
        # Skip obvious development machines
        dev_patterns = ["localhost", "desktop", "laptop", "pc-", "macbook", "imac", "home"]
        if not any(dev_pattern in hostname for dev_pattern in dev_patterns):
            # Cloud environments often have long, generated, or hyphenated hostnames
            if len(hostname) > 15 or hostname.count("-") >= 2:
                logger.info(f"Cloud deployment detected via hostname pattern: {hostname}")
                return True
    
    # Check for cloud-specific networking
    if os.getenv("PORT") and not os.getenv("PORT") == "8080":
        # Cloud platforms often set dynamic PORT env var
        logger.debug(f"Dynamic PORT detected: {os.getenv('PORT')} - possible cloud deployment")
    
    logger.debug("No cloud deployment indicators found - assuming local development")
    return False


def get_recommended_version(user_agent: str | None = None) -> InferenceVersion:
    """
    Get the recommended inference version based on availability and priority.
    
    Priority system:
    1. Cloud/Server environments: Always use "local" (with cloud API fallback)
    2. Development environments: Also use "local" for consistency
    3. Mobile-specific: Only when explicitly configured via INFERENCE_VERSION
    
    This avoids the problem where cloud servers try to detect Tensor chips or Neural Engines
    that don't exist on Azure App Service, AWS EC2, or other cloud platforms.
    
    Args:
        user_agent: User-Agent header from request (optional, for mobile detection)
    
    Returns:
        Recommended version string
    """
    settings = get_settings()
    
    # If explicitly set, use that (unless it's "auto")
    if settings.inference_version and settings.inference_version != "auto":
        # Validate that the set version is valid
        valid_versions = ["local", "apple", "native_mobile"]
        if settings.inference_version not in valid_versions:
            logger.warning(
                f"Invalid INFERENCE_VERSION '{settings.inference_version}' found. "
                f"Valid values are: {', '.join(valid_versions)}. Falling back to server-optimized default."
            )
            # Fall through to server-optimized default
        else:
            logger.info(f"Using explicitly configured version: {settings.inference_version}")
            return settings.inference_version
    
    # Check if we're in a cloud deployment
    is_cloud = is_cloud_deployment()
    
    if is_cloud:
        logger.info("Cloud deployment detected (Azure/AWS/GCP) - using server-optimized version")
        logger.info("Skipping mobile accelerator detection (Tensor/Neural Engine not available in cloud)")
    else:
        logger.info("Local development environment - using server-optimized version")
    
    # Always use "local" for server deployments (cloud or local development)
    # This provides the best experience:
    # 1. If local GGUF models are available → uses them efficiently
    # 2. If local models fail → automatically falls back to HuggingFace cloud APIs
    # 3. No wasted cycles trying to detect mobile hardware that doesn't exist on servers
    logger.info("Recommended version: local (server-optimized: local GGUF → cloud API fallback)")
    return "local"


def is_iphone_client(user_agent: str | None) -> bool:
    """
    Detect if the request is from an iPhone client.
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        True if client is an iPhone
    """
    if not user_agent:
        return False
    
    user_agent_lower = user_agent.lower()
    # Check for iPhone indicators
    return "iphone" in user_agent_lower or "ios" in user_agent_lower


def should_use_on_device_processing(user_agent: str | None) -> bool:
    """
    Determine if iPhone client should use on-device Core ML processing.
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        True if on-device processing should be used
    """
    settings = get_settings()
    
    if not settings.apple_support_on_device:
        return False
    
    if not is_iphone_client(user_agent):
        return False
    
    return True


def is_pixel_client(user_agent: str | None) -> bool:
    """
    Detect if the request is from a Google Pixel device.
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        True if client is a Google Pixel device
    """
    if not user_agent:
        return False
    
    user_agent_lower = user_agent.lower()
    # Check for Pixel indicators (Pixel phones typically have "Pixel" in User-Agent)
    return "pixel" in user_agent_lower


def is_android_client(user_agent: str | None) -> bool:
    """
    Detect if the request is from an Android device.
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        True if client is an Android device
    """
    if not user_agent:
        return False
    
    user_agent_lower = user_agent.lower()
    return "android" in user_agent_lower


def should_use_apple_services(user_agent: str | None) -> bool:
    """
    Determine if client should use Apple services (e.g., iOS devices).
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        True if Apple services should be preferred
    """
    if not user_agent:
        return False
    
    # Prefer Apple services for iOS devices
    if is_iphone_client(user_agent):
        return True
    
    return False


def get_device_type(user_agent: str | None) -> str:
    """
    Get the device type from User-Agent header.
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        Device type: "iphone", "pixel", "android", "ios", "other"
    """
    if not user_agent:
        return "other"
    
    user_agent_lower = user_agent.lower()
    
    # Check for iPhone first (more specific)
    if "iphone" in user_agent_lower:
        return "iphone"
    
    # Check for other iOS devices
    if "ipad" in user_agent_lower or "ipod" in user_agent_lower:
        return "ios"
    
    # Check for Pixel
    if "pixel" in user_agent_lower:
        return "pixel"
    
    # Check for Android
    if "android" in user_agent_lower:
        return "android"
    
    return "other"


def is_phone_client(user_agent: str | None) -> bool:
    """
    Detect if the request is from a phone client (iPhone or Android phone).
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        True if client is a phone device
    """
    if not user_agent:
        return False
    
    user_agent_lower = user_agent.lower()
    # Check for iPhone or Android phone (but not tablets)
    return (
        "iphone" in user_agent_lower or
        ("android" in user_agent_lower and "mobile" in user_agent_lower)
    )


def get_optimization_level(user_agent: str | None) -> str:
    """
    Get optimization level based on device type.
    
    Args:
        user_agent: User-Agent header value
        
    Returns:
        Optimization level: "ultra_fast", "fast", "standard"
    """
    if is_phone_client(user_agent):
        return "ultra_fast"
    
    device_type = get_device_type(user_agent)
    if device_type in ["iphone", "android"]:
        return "fast"
    
    return "standard"
