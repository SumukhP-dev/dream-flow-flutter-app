"""
Apple Intelligence API and Core ML services for story generation, narration, and images.

Uses Apple Intelligence API (cloud) for story generation, narration, and images.
Supports iPhone client detection for on-device Core ML processing.
"""

from __future__ import annotations

import asyncio
import io
import logging
import platform
import uuid
from dataclasses import dataclass, field
from typing import Any, AsyncIterator, Optional

import httpx
from PIL import Image, ImageDraw, ImageFont

from ..shared.config import get_settings
from .prompting import PromptBuilder, PromptContext
from .guardrails import PromptSanitizer
from .version_detector import is_iphone_client, should_use_on_device_processing

settings = get_settings()
logger = logging.getLogger(__name__)

# Default timeout values (in seconds)
DEFAULT_TIMEOUT = 120.0
MAX_RETRIES = 3
RETRY_DELAY = 1.0


def _truncate_caption(text: str, max_length: int = 200) -> str:
    """Truncate caption text to a maximum length."""
    if len(text) <= max_length:
        return text
    return text[: max_length - 3] + "..."


@dataclass
class AppleStoryGenerator:
    """Story generator using Apple Intelligence API or Core ML."""
    
    prompt_builder: PromptBuilder
    model_id: str = field(default_factory=lambda: settings.apple_story_model)
    use_coreml: bool = field(default_factory=lambda: settings.apple_silicon_server)
    
    def __post_init__(self):
        """Initialize Apple Intelligence API client or Core ML."""
        if self.use_coreml and platform.system() == "Darwin" and platform.machine() == "arm64":
            try:
                import coremltools
                logger.info("Using Core ML on Apple Silicon server")
                self.coreml_available = True
            except ImportError:
                logger.warning("Core ML not available, falling back to Apple Intelligence API")
                self.coreml_available = False
        else:
            self.coreml_available = False
        
        if not self.coreml_available:
            if not settings.apple_intelligence_api_key:
                raise ValueError(
                    "Apple Intelligence API key is required. "
                    "Set APPLE_INTELLIGENCE_API_KEY environment variable."
                )
            self.api_key = settings.apple_intelligence_api_key
            self.api_url = settings.apple_intelligence_api_url or "https://api.apple.com/v1/intelligence"
            logger.info("Using Apple Intelligence API")
    
    async def generate(self, context: PromptContext, user_agent: str | None = None) -> str:
        """
        Generate story text using Apple Intelligence API or Core ML.
        
        Args:
            context: Prompt context for story generation
            user_agent: User-Agent header to detect iPhone clients
            
        Returns:
            Generated story text
        """
        prompt = self.prompt_builder.story_prompt(context)
        
        # Check if iPhone client should use on-device processing
        if should_use_on_device_processing(user_agent):
            # Return a flag indicating on-device processing is available
            # The mobile app will handle the actual generation
            logger.info("iPhone client detected - on-device Core ML processing available")
            # For now, we'll still generate on backend as fallback
            # In production, you might want to return a special response
        
        if self.coreml_available:
            return await self._generate_coreml(prompt)
        else:
            return await self._generate_api(prompt)
    
    async def _generate_coreml(self, prompt: str) -> str:
        """Generate using Core ML on Apple Silicon server."""
        # This is a placeholder - actual Core ML implementation would load a model
        # and run inference. For now, we'll use the API as fallback.
        logger.warning("Core ML generation not fully implemented, using API fallback")
        return await self._generate_api(prompt)
    
    async def _generate_api(self, prompt: str) -> str:
        """Generate using Apple Intelligence API."""
        def _generate() -> str:
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }
            
            payload = {
                "model": self.model_id,
                "prompt": prompt,
                "max_tokens": settings.max_new_tokens,
                "temperature": 0.8,
                "top_p": 0.9,
            }
            
            try:
                with httpx.Client(timeout=DEFAULT_TIMEOUT) as client:
                    response = client.post(
                        f"{self.api_url}/generate",
                        json=payload,
                        headers=headers,
                    )
                    response.raise_for_status()
                    result = response.json()
                    
                    if "text" in result:
                        return result["text"].strip()
                    elif "content" in result:
                        return result["content"].strip()
                    else:
                        raise ValueError("Apple Intelligence API returned unexpected format")
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    raise ValueError(
                        "Apple Intelligence API endpoint not found. "
                        "The API may not be available yet. "
                        "Set ENABLE_APPLE_INTELLIGENCE=false to disable Apple version."
                    )
                elif e.response.status_code == 401:
                    raise ValueError(
                        "Apple Intelligence API authentication failed. "
                        "Check that APPLE_INTELLIGENCE_API_KEY is correct."
                    )
                else:
                    raise ValueError(
                        f"Apple Intelligence API error: {e.response.status_code} - {e.response.text}"
                    )
            except httpx.ConnectError:
                raise ValueError(
                    "Could not connect to Apple Intelligence API. "
                    "The API may not be available yet or the URL is incorrect."
                )
            except Exception as e:
                logger.error(f"Apple Intelligence API request failed: {e}")
                raise ValueError(f"Apple Intelligence API error: {str(e)}")
        
        # Run with retry logic
        last_error = None
        for attempt in range(MAX_RETRIES):
            try:
                return await asyncio.wait_for(
                    asyncio.to_thread(_generate),
                    timeout=DEFAULT_TIMEOUT,
                )
            except asyncio.TimeoutError:
                last_error = ValueError(f"Apple story generation timed out after {DEFAULT_TIMEOUT}s")
                if attempt == MAX_RETRIES - 1:
                    raise last_error
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))  # Exponential backoff
            except ValueError as e:
                # Don't retry on ValueError (API errors, auth errors, etc.)
                raise
            except Exception as e:
                last_error = e
                if attempt == MAX_RETRIES - 1:
                    raise ValueError(f"Apple story generation failed after {MAX_RETRIES} retries: {str(e)}")
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))  # Exponential backoff
        
        if last_error:
            raise ValueError(f"Apple story generation failed: {str(last_error)}")
        raise ValueError("Apple story generation failed after retries")
    
    async def generate_stream(self, context: PromptContext) -> AsyncIterator[str]:
        """Stream story text in chunks."""
        try:
            full_text = await self.generate(context)
            chunk_size = 200
            # Use while loop instead of for loop to avoid StopIteration issues in async context
            i = 0
            while i < len(full_text):
                chunk = full_text[i : i + chunk_size]
                if not chunk:  # Safety check for empty chunks
                    break
                yield chunk
                i += chunk_size
        except GeneratorExit:
            # Handle generator cleanup gracefully
            return
        except Exception as e:
            # Log other exceptions but don't re-raise StopIteration
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error in Apple generate_stream: {e}", exc_info=True)
            raise


@dataclass
class AppleNarrationGenerator:
    """Narration generator using Apple TTS API or Core ML."""
    
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    model_id: str = field(default_factory=lambda: settings.apple_tts_model)
    
    def __post_init__(self):
        """Initialize Apple TTS client."""
        if not settings.apple_intelligence_api_key:
            raise ValueError(
                "Apple Intelligence API key is required. "
                "Set APPLE_INTELLIGENCE_API_KEY environment variable."
            )
        self.api_key = settings.apple_intelligence_api_key
        self.api_url = settings.apple_intelligence_api_url or "https://api.apple.com/v1/intelligence"
        logger.info("Initialized Apple TTS")
    
    async def synthesize(
        self,
        story: str,
        context: PromptContext,
        voice: str | None,
        supabase_client: Optional[Any] = None,
        user_agent: str | None = None,
    ) -> str:
        """
        Synthesize audio using Apple TTS API.
        
        Returns:
            Signed URL if supabase_client is provided, otherwise local file path
        """
        prompt = self.prompt_builder.narration_prompt(context, story)
        prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="narration")
        voice_param = voice or "alloy"
        
        # Check if iPhone client should use on-device processing
        if should_use_on_device_processing(user_agent):
            logger.info("iPhone client detected - on-device TTS processing available")
            # For now, we'll still generate on backend as fallback
        
        def _synthesize() -> bytes:
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }
            
            payload = {
                "model": self.model_id,
                "text": prompt,
                "voice": voice_param,
                "format": "mp3",
            }
            
            with httpx.Client(timeout=DEFAULT_TIMEOUT) as client:
                response = client.post(
                    f"{self.api_url}/tts",
                    json=payload,
                    headers=headers,
                )
                response.raise_for_status()
                
                # Response might be JSON with base64 audio or direct bytes
                if response.headers.get("content-type", "").startswith("application/json"):
                    result = response.json()
                    if "audio" in result:
                        import base64
                        return base64.b64decode(result["audio"])
                    else:
                        raise ValueError("Apple TTS API returned unexpected format")
                else:
                    # Direct audio bytes
                    return response.content
        
        audio_bytes = await asyncio.to_thread(_synthesize)
        filename = f"{uuid.uuid4()}.mp3"
        
        # Upload to Supabase Storage if client is provided
        if supabase_client:
            return supabase_client.upload_audio(audio_bytes, filename)
        
        # Fallback: save locally
        audio_path = settings.audio_dir / filename
        audio_path.write_bytes(audio_bytes)
        return str(audio_path)


@dataclass
class AppleVisualGenerator:
    """Visual generator using Apple Intelligence image generation API."""
    
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    model_id: str = field(default_factory=lambda: settings.apple_image_model)
    
    def __post_init__(self):
        """Initialize Apple Intelligence image generation client."""
        if not settings.apple_intelligence_api_key:
            raise ValueError(
                "Apple Intelligence API key is required. "
                "Set APPLE_INTELLIGENCE_API_KEY environment variable."
            )
        self.api_key = settings.apple_intelligence_api_key
        self.api_url = settings.apple_intelligence_api_url or "https://api.apple.com/v1/intelligence"
        logger.info("Initialized Apple Intelligence image generation")
    
    def _create_placeholder_image(
        self, width: int = 1280, height: int = 720
    ) -> Image.Image:
        """Create a placeholder image when generation fails."""
        image = Image.new("RGB", (width, height), color=(45, 45, 60))
        draw = ImageDraw.Draw(image)
        
        try:
            font_large = ImageFont.truetype("arial.ttf", 48)
            font_small = ImageFont.truetype("arial.ttf", 24)
        except OSError:
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        text = "Dream Flow"
        text_bbox = draw.textbbox((0, 0), text, font=font_large)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        
        x = (width - text_width) // 2
        y = (height - text_height) // 2 - 20
        
        draw.text((x, y), text, fill=(255, 255, 255), font=font_large)
        
        subtext = "Image generation unavailable"
        subtext_bbox = draw.textbbox((0, 0), subtext, font=font_small)
        subtext_width = subtext_bbox[2] - subtext_bbox[0]
        subtext_x = (width - subtext_width) // 2
        draw.text(
            (subtext_x, y + text_height + 10),
            subtext,
            fill=(200, 200, 200),
            font=font_small,
        )
        
        return image
    
    def _overlay_caption(self, image: Image.Image, caption: str) -> Image.Image:
        """Overlay caption text on image if enabled."""
        if not settings.overlay_image_captions:
            return image
        
        draw = ImageDraw.Draw(image)
        try:
            font = ImageFont.truetype("arial.ttf", 24)
        except OSError:
            font = ImageFont.load_default()
        
        # Draw semi-transparent background for text
        text_bbox = draw.textbbox((0, 0), caption, font=font)
        text_height = text_bbox[3] - text_bbox[1]
        padding = 10
        
        overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
        overlay_draw = ImageDraw.Draw(overlay)
        overlay_draw.rectangle(
            [
                (0, image.height - text_height - padding * 2),
                (image.width, image.height),
            ],
            fill=(0, 0, 0, 180),
        )
        
        image = Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")
        draw = ImageDraw.Draw(image)
        
        # Draw text
        draw.text(
            (padding, image.height - text_height - padding),
            caption,
            fill=(255, 255, 255),
            font=font,
        )
        
        return image
    
    async def create_frames(
        self,
        story: str,
        context: PromptContext,
        num_scenes: int,
        supabase_client: Optional[Any] = None,
        storage_prefix: str | None = None,
    ) -> list[str]:
        """
        Generate image frames using Apple Intelligence image generation API.
        
        Returns:
            List of image URLs or file paths
        """
        if settings.use_placeholders_only:
            logger.info("Using placeholder images only (use_placeholders_only=true)")
            frames = []
            for _ in range(num_scenes):
                placeholder = self._create_placeholder_image()
                buffer = io.BytesIO()
                placeholder.save(buffer, format="PNG")
                frame_bytes = buffer.getvalue()
                
                if supabase_client:
                    filename = f"{storage_prefix or ''}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(frame_bytes, filename)
                    frames.append(frame_url)
                else:
                    frame_path = settings.frames_dir / f"{uuid.uuid4()}.png"
                    frame_path.write_bytes(frame_bytes)
                    frames.append(str(frame_path))
            return frames
        
        # Split story into chunks
        paragraphs = story.split("\n\n")
        chunks = self._distribute_paragraphs(paragraphs, num_scenes)
        frames: list[str] = []
        
        normalized_prefix = ""
        if storage_prefix:
            normalized_prefix = f"{storage_prefix.strip('/')}/"
        
        for idx, chunk in enumerate(chunks):
            caption = _truncate_caption(chunk)
            
            try:
                prompt = self.prompt_builder.visual_prompt(context, chunk)
                prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="visual")
                
                def _generate_image() -> bytes:
                    headers = {
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    }
                    
                    payload = {
                        "model": self.model_id,
                        "prompt": prompt,
                        "width": 1280,
                        "height": 720,
                        "num_images": 1,
                    }
                    
                    with httpx.Client(timeout=DEFAULT_TIMEOUT) as client:
                        response = client.post(
                            f"{self.api_url}/images/generate",
                            json=payload,
                            headers=headers,
                        )
                        response.raise_for_status()
                        
                        # Response might be JSON with base64 image or direct bytes
                        if response.headers.get("content-type", "").startswith("application/json"):
                            result = response.json()
                            if "image" in result:
                                import base64
                                return base64.b64decode(result["image"])
                            elif "images" in result and len(result["images"]) > 0:
                                import base64
                                return base64.b64decode(result["images"][0])
                            else:
                                raise ValueError("Apple image API returned unexpected format")
                        else:
                            # Direct image bytes
                            return response.content
                
                image_bytes = await asyncio.to_thread(_generate_image)
                
                # Process image (overlay caption if enabled)
                def _process_image() -> bytes:
                    image = Image.open(io.BytesIO(image_bytes))
                    image = self._overlay_caption(image, caption)
                    buffer = io.BytesIO()
                    image.save(buffer, format="PNG")
                    return buffer.getvalue()
                
                frame_bytes = await asyncio.to_thread(_process_image)
                
                # Upload to Supabase Storage if client is provided
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(frame_bytes, filename)
                    frames.append(frame_url)
                else:
                    frame_path = settings.frames_dir / f"{uuid.uuid4()}.png"
                    frame_path.write_bytes(frame_bytes)
                    frames.append(str(frame_path))
            
            except Exception as e:
                logger.error(f"Apple image generation failed for scene {idx + 1}: {e}")
                # Fallback to placeholder
                placeholder = self._create_placeholder_image()
                buffer = io.BytesIO()
                placeholder.save(buffer, format="PNG")
                frame_bytes = buffer.getvalue()
                
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(frame_bytes, filename)
                    frames.append(frame_url)
                else:
                    frame_path = settings.frames_dir / f"{uuid.uuid4()}.png"
                    frame_path.write_bytes(frame_bytes)
                    frames.append(str(frame_path))
        
        return frames
    
    def _distribute_paragraphs(self, paragraphs: list[str], num_scenes: int) -> list[str]:
        """Evenly distribute paragraphs across num_scenes chunks."""
        if not paragraphs:
            return []
        
        if num_scenes <= 0:
            num_scenes = 1
        
        if len(paragraphs) <= num_scenes:
            return paragraphs
        
        paragraphs_per_scene = len(paragraphs) // num_scenes
        remainder = len(paragraphs) % num_scenes
        
        chunks: list[str] = []
        start_idx = 0
        
        for i in range(num_scenes):
            chunk_size = paragraphs_per_scene + (1 if i < remainder else 0)
            end_idx = start_idx + chunk_size
            chunk = " ".join(paragraphs[start_idx:end_idx])
            chunks.append(chunk)
            start_idx = end_idx
        
        return chunks

