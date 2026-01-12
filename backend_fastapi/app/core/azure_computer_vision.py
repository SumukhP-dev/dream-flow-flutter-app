"""
Azure Computer Vision integration for image analysis and enhancement.

This module provides image analysis capabilities using Azure Computer Vision API
to enhance accessibility, validate image quality, and provide insights about generated images.
"""

import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

# Try to import Azure Computer Vision client
try:
    from azure.cognitiveservices.vision.computervision import ComputerVisionClient
    from azure.cognitiveservices.vision.computervision.models import VisualFeatureTypes
    from msrest.authentication import CognitiveServicesCredentials
    from msrest.exceptions import ClientException
    AZURE_COMPUTER_VISION_AVAILABLE = True
except ImportError:
    AZURE_COMPUTER_VISION_AVAILABLE = False
    logger.warning(
        "Azure Computer Vision SDK not installed. "
        "Install with: pip install azure-cognitiveservices-vision-computervision msrest"
    )


class AzureComputerVisionClient:
    """Client for Azure Computer Vision API."""

    def __init__(self, endpoint: str, key: str):
        """
        Initialize Azure Computer Vision client.

        Args:
            endpoint: Azure Computer Vision endpoint URL
            key: Azure Computer Vision API key
        """
        if not AZURE_COMPUTER_VISION_AVAILABLE:
            raise ImportError(
                "Azure Computer Vision SDK not installed. "
                "Install with: pip install azure-cognitiveservices-vision-computervision msrest"
            )

        self.client = ComputerVisionClient(
            endpoint=endpoint,
            credentials=CognitiveServicesCredentials(key)
        )

    def describe_image(self, image_data: bytes, max_candidates: int = 1) -> Dict[str, Any]:
        """
        Generate image description (captions) for accessibility.

        Args:
            image_data: Image bytes to describe
            max_candidates: Maximum number of caption candidates to return

        Returns:
            Dictionary containing description results:
            {
                "captions": list[dict],  # List of caption candidates with confidence
                "tags": list[str],  # List of detected tags
                "errors": list[str]
            }
        """
        if not AZURE_COMPUTER_VISION_AVAILABLE:
            logger.warning("Azure Computer Vision not available, skipping image description")
            return {"captions": [], "tags": [], "errors": []}

        try:
            from io import BytesIO

            response = self.client.describe_image_in_stream(
                BytesIO(image_data),
                max_candidates=max_candidates
            )

            captions = []
            if hasattr(response, "captions") and response.captions:
                for caption in response.captions:
                    captions.append({
                        "text": caption.text,
                        "confidence": caption.confidence if hasattr(caption, "confidence") else 0.0,
                    })

            tags = []
            if hasattr(response, "tags") and response.tags:
                tags = response.tags

            return {
                "captions": captions,
                "tags": tags,
                "errors": [],
            }

        except ClientException as e:
            logger.error(f"Azure Computer Vision API error: {e}")
            return {
                "captions": [],
                "tags": [],
                "errors": [str(e)],
            }
        except Exception as e:
            logger.error(f"Unexpected error in Azure Computer Vision image description: {e}")
            return {
                "captions": [],
                "tags": [],
                "errors": [str(e)],
            }

    def analyze_image(
        self,
        image_data: bytes,
        visual_features: Optional[list] = None,
    ) -> Dict[str, Any]:
        """
        Analyze image for objects, tags, and description.

        Args:
            image_data: Image bytes to analyze
            visual_features: List of visual features to extract (default: objects, tags, description)

        Returns:
            Dictionary containing analysis results:
            {
                "objects": list[dict],
                "tags": list[dict],
                "description": dict,
                "errors": list[str]
            }
        """
        if not AZURE_COMPUTER_VISION_AVAILABLE:
            logger.warning("Azure Computer Vision not available, skipping image analysis")
            return {"objects": [], "tags": [], "description": {}, "errors": []}

        try:
            from io import BytesIO

            # Default visual features
            if visual_features is None:
                visual_features = [
                    VisualFeatureTypes.objects,
                    VisualFeatureTypes.tags,
                    VisualFeatureTypes.description,
                ]

            response = self.client.analyze_image_in_stream(
                BytesIO(image_data),
                visual_features=visual_features
            )

            objects = []
            if hasattr(response, "objects") and response.objects:
                for obj in response.objects:
                    objects.append({
                        "object_property": obj.object_property if hasattr(obj, "object_property") else "",
                        "confidence": obj.confidence if hasattr(obj, "confidence") else 0.0,
                        "rectangle": {
                            "x": obj.rectangle.x if hasattr(obj, "rectangle") else 0,
                            "y": obj.rectangle.y if hasattr(obj, "rectangle") else 0,
                            "w": obj.rectangle.w if hasattr(obj, "rectangle") else 0,
                            "h": obj.rectangle.h if hasattr(obj, "rectangle") else 0,
                        } if hasattr(obj, "rectangle") else {},
                    })

            tags = []
            if hasattr(response, "tags") and response.tags:
                for tag in response.tags:
                    tags.append({
                        "name": tag.name if hasattr(tag, "name") else str(tag),
                        "confidence": tag.confidence if hasattr(tag, "confidence") else 0.0,
                    })

            description = {}
            if hasattr(response, "description") and response.description:
                desc = response.description
                description = {
                    "tags": desc.tags if hasattr(desc, "tags") else [],
                    "captions": [
                        {
                            "text": cap.text,
                            "confidence": cap.confidence if hasattr(cap, "confidence") else 0.0,
                        }
                        for cap in (desc.captions if hasattr(desc, "captions") and desc.captions else [])
                    ],
                }

            return {
                "objects": objects,
                "tags": tags,
                "description": description,
                "errors": [],
            }

        except ClientException as e:
            logger.error(f"Azure Computer Vision API error: {e}")
            return {
                "objects": [],
                "tags": [],
                "description": {},
                "errors": [str(e)],
            }
        except Exception as e:
            logger.error(f"Unexpected error in Azure Computer Vision image analysis: {e}")
            return {
                "objects": [],
                "tags": [],
                "description": {},
                "errors": [str(e)],
            }

    def generate_alt_text(self, image_data: bytes) -> str:
        """
        Generate alt-text for accessibility (screen readers).

        Args:
            image_data: Image bytes to analyze

        Returns:
            Alt-text string for accessibility
        """
        result = self.describe_image(image_data, max_candidates=1)
        
        if result["captions"]:
            # Use the highest confidence caption as alt-text
            caption = result["captions"][0]
            return caption.get("text", "")
        
        # Fallback to tags if no captions available
        if result["tags"]:
            return f"Image containing: {', '.join(result['tags'][:5])}"
        
        return "Image"


def get_computer_vision_client():
    """
    Get Azure Computer Vision client instance from settings.

    Returns:
        AzureComputerVisionClient instance or None if not configured
    """
    from ..shared.config import get_settings
    
    settings = get_settings()

    if not settings.azure_computer_vision_enabled:
        return None

    endpoint = settings.azure_computer_vision_endpoint
    key = settings.azure_computer_vision_key

    if not endpoint or not key:
        logger.warning("Azure Computer Vision endpoint or key not configured")
        return None

    try:
        return AzureComputerVisionClient(endpoint=endpoint, key=key)
    except Exception as e:
        logger.error(f"Failed to initialize Azure Computer Vision client: {e}")
        return None

