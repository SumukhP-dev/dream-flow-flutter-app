"""
Azure Content Safety integration for AI-powered content moderation.

This module provides text and image moderation capabilities using Azure AI Content Safety
to complement on-device local model generation with cloud-based safety validation.
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Try to import Azure Content Safety client
try:
    from azure.ai.contentsafety import ContentSafetyClient
    from azure.core.credentials import AzureKeyCredential
    from azure.core.exceptions import HttpResponseError
    AZURE_CONTENT_SAFETY_AVAILABLE = True
except ImportError:
    AZURE_CONTENT_SAFETY_AVAILABLE = False


class AzureContentSafetyClient:
    """Client for Azure Content Safety API."""

    def __init__(self, endpoint: str, key: str):
        """
        Initialize Azure Content Safety client.

        Args:
            endpoint: Azure Content Safety endpoint URL
            key: Azure Content Safety API key
        """
        if not AZURE_CONTENT_SAFETY_AVAILABLE:
            raise ImportError(
                "Azure Content Safety SDK not installed. "
                "Install with: pip install azure-ai-contentsafety"
            )

        self.client = ContentSafetyClient(
            endpoint=endpoint,
            credential=AzureKeyCredential(key)
        )

    def moderate_text(
        self,
        text: str,
        categories: Optional[list] = None,
        severity_threshold: int = 2,  # 0-7 scale, 2 is Medium severity
    ) -> dict:
        """
        Moderate text content using Azure Content Safety.

        Args:
            text: Text content to moderate
            categories: List of categories to check (default: all categories)
            severity_threshold: Severity threshold (0-7, default: 2 for Medium)

        Returns:
            Dictionary containing moderation results:
            {
                "is_safe": bool,
                "categories_analyzed": dict,
                "blocklists_matched": list,
                "errors": list
            }
        """
        if not AZURE_CONTENT_SAFETY_AVAILABLE:
            logger.warning("Azure Content Safety not available, skipping text moderation")
            return {"is_safe": True, "categories_analyzed": {}, "blocklists_matched": [], "errors": []}

        try:
            from azure.ai.contentsafety.models import AnalyzeTextOptions, TextCategory

            # Default to all categories if not specified
            if categories is None:
                categories = [
                    TextCategory.HATE,
                    TextCategory.SELF_HARM,
                    TextCategory.SEXUAL,
                    TextCategory.VIOLENCE,
                ]

            response = self.client.analyze_text(
                AnalyzeTextOptions(
                    text=text,
                    categories=categories,
                    blocklist_names=[],  # Can be configured if needed
                    halt_on_blocklist_hit=False,
                )
            )

            # Analyze response to determine if content is safe
            is_safe = True
            categories_analyzed = {}
            blocklists_matched = []

            if hasattr(response, "categories_analysis"):
                for category_result in response.categories_analysis:
                    category = category_result.category
                    severity = category_result.severity if hasattr(category_result, "severity") else 0
                    categories_analyzed[category] = {
                        "severity": severity,
                        "category": category,
                    }
                    # Content is unsafe if severity exceeds threshold
                    if severity >= severity_threshold:
                        is_safe = False
                        logger.warning(
                            f"Unsafe content detected in category {category}: severity {severity}"
                        )

            if hasattr(response, "blocklists_match"):
                blocklists_matched = response.blocklists_match or []

            return {
                "is_safe": is_safe,
                "categories_analyzed": categories_analyzed,
                "blocklists_matched": blocklists_matched,
                "errors": [],
            }

        except HttpResponseError as e:
            logger.error(f"Azure Content Safety API error: {e}")
            return {
                "is_safe": True,  # Fail open for availability
                "categories_analyzed": {},
                "blocklists_matched": [],
                "errors": [str(e)],
            }
        except Exception as e:
            logger.error(f"Unexpected error in Azure Content Safety text moderation: {e}")
            return {
                "is_safe": True,  # Fail open for availability
                "categories_analyzed": {},
                "blocklists_matched": [],
                "errors": [str(e)],
            }

    def moderate_image(
        self,
        image_data: bytes,
        severity_threshold: int = 2,  # 0-7 scale, 2 is Medium severity
    ) -> dict:
        """
        Moderate image content using Azure Content Safety.

        Args:
            image_data: Image bytes to moderate
            severity_threshold: Severity threshold (0-7, default: 2 for Medium)

        Returns:
            Dictionary containing moderation results:
            {
                "is_safe": bool,
                "categories_analyzed": dict,
                "errors": list
            }
        """
        if not AZURE_CONTENT_SAFETY_AVAILABLE:
            logger.warning("Azure Content Safety not available, skipping image moderation")
            return {"is_safe": True, "categories_analyzed": {}, "errors": []}

        try:
            from azure.ai.contentsafety.models import AnalyzeImageOptions, ImageData

            response = self.client.analyze_image(
                AnalyzeImageOptions(image=ImageData(content=image_data))
            )

            # Analyze response to determine if content is safe
            is_safe = True
            categories_analyzed = {}

            if hasattr(response, "categories_analysis"):
                for category_result in response.categories_analysis:
                    category = category_result.category
                    severity = category_result.severity if hasattr(category_result, "severity") else 0
                    categories_analyzed[category] = {
                        "severity": severity,
                        "category": category,
                    }
                    # Content is unsafe if severity exceeds threshold
                    if severity >= severity_threshold:
                        is_safe = False
                        logger.warning(
                            f"Unsafe image detected in category {category}: severity {severity}"
                        )

            return {
                "is_safe": is_safe,
                "categories_analyzed": categories_analyzed,
                "errors": [],
            }

        except HttpResponseError as e:
            logger.error(f"Azure Content Safety API error: {e}")
            return {
                "is_safe": True,  # Fail open for availability
                "categories_analyzed": {},
                "errors": [str(e)],
            }
        except Exception as e:
            logger.error(f"Unexpected error in Azure Content Safety image moderation: {e}")
            return {
                "is_safe": True,  # Fail open for availability
                "categories_analyzed": {},
                "errors": [str(e)],
            }


def get_content_safety_client():
    """
    Get Azure Content Safety client instance from settings.

    Returns:
        AzureContentSafetyClient instance or None if not configured
    """
    from ..shared.config import get_settings
    
    settings = get_settings()

    if not settings.azure_content_safety_enabled:
        logger.debug("Azure Content Safety disabled via configuration; skipping client setup")
        return None

    if not AZURE_CONTENT_SAFETY_AVAILABLE:
        logger.warning(
            "Azure Content Safety SDK not installed but integration is enabled. "
            "Install with: pip install azure-ai-contentsafety or disable by "
            "setting AZURE_CONTENT_SAFETY_ENABLED=false."
        )
        return None

    endpoint = settings.azure_content_safety_endpoint
    key = settings.azure_content_safety_key

    if not endpoint or not key:
        logger.warning("Azure Content Safety endpoint or key not configured; integration disabled")
        return None

    try:
        return AzureContentSafetyClient(endpoint=endpoint, key=key)
    except Exception as e:
        logger.error(f"Failed to initialize Azure Content Safety client: {e}")
        return None

