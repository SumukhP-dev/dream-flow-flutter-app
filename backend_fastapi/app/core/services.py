from __future__ import annotations

import asyncio
import base64
import io
import os
import tempfile
import textwrap
import uuid
from dataclasses import dataclass, field
from typing import Any, Callable, Optional
from urllib.parse import quote

import httpx
from huggingface_hub import InferenceClient
from PIL import Image, ImageDraw, ImageFont

from ..shared.config import get_settings, Settings
from ..shared.exceptions import (
    HuggingFaceConnectionError,
    HuggingFaceError,
    HuggingFaceModelError,
    HuggingFaceRateLimitError,
    HuggingFaceTimeoutError,
)
from ..core.prompting import PromptBuilder, PromptContext
from ..core.guardrails import PromptSanitizer

import logging

settings = get_settings()
logger = logging.getLogger(__name__)

# Pillow compatibility: provide ANTIALIAS constant if removed in newer versions
if not hasattr(Image, "ANTIALIAS"):
    Image.ANTIALIAS = Image.Resampling.LANCZOS

# Default timeout values (in seconds)
DEFAULT_TIMEOUT = 120.0  # 2 minutes for inference
DEFAULT_CONNECT_TIMEOUT = 10.0  # 10 seconds for connection
MAX_RETRIES = 3
RETRY_DELAY = 1.0  # seconds between retries


class CustomHuggingFaceClient:
    """Custom HuggingFace client that uses httpx with a custom base URL."""
    
    def __init__(self, base_url: str, model: str, token: str | None = None):
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.token = token
        self.client = httpx.Client(timeout=DEFAULT_TIMEOUT)
        # Remove /v1 if present, we'll add it in the endpoints
        if self.base_url.endswith('/v1'):
            self.base_url = self.base_url[:-3]
    
    def text_generation(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.8,
        top_p: float = 0.9,
        repetition_penalty: float = 1.05,
        return_full_text: bool = False,
    ) -> str:
        """Generate text using custom HuggingFace API endpoint."""
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        
        # Try the chat completions endpoint first (OpenAI-compatible)
        try:
            response = self.client.post(
                f"{self.base_url}/v1/chat/completions",
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "user", "content": prompt}
                    ],
                    "max_tokens": max_new_tokens,
                    "temperature": temperature,
                    "top_p": top_p,
                },
                headers=headers,
                timeout=DEFAULT_TIMEOUT,
            )
            response.raise_for_status()
            result = response.json()
            # Extract content from OpenAI-compatible response
            if "choices" in result and len(result["choices"]) > 0:
                return result["choices"][0]["message"]["content"].strip()
        except Exception as e:
            logger.debug(f"Chat completions endpoint failed, trying text generation: {e}")
        
        # Fallback to text generation endpoint
        response = self.client.post(
            f"{self.base_url}/models/{self.model}",
            json={
                "inputs": prompt,
                "parameters": {
                    "max_new_tokens": max_new_tokens,
                    "temperature": temperature,
                    "top_p": top_p,
                    "repetition_penalty": repetition_penalty,
                    "return_full_text": return_full_text,
                }
            },
            headers=headers,
            timeout=DEFAULT_TIMEOUT,
        )
        response.raise_for_status()
        result = response.json()
        # Handle different response formats
        if isinstance(result, list) and len(result) > 0:
            return result[0].get("generated_text", "").strip()
        elif isinstance(result, dict):
            return result.get("generated_text", "").strip()
        return str(result).strip()
    
    def chat_completion(
        self,
        messages: list[dict[str, str]],
        max_tokens: int = 512,
        temperature: float = 0.8,
        top_p: float = 0.9,
    ) -> dict:
        """Chat completion using custom HuggingFace API endpoint."""
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        
        response = self.client.post(
            f"{self.base_url}/v1/chat/completions",
            json={
                "model": self.model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
                "top_p": top_p,
            },
            headers=headers,
            timeout=DEFAULT_TIMEOUT,
        )
        response.raise_for_status()
        return response.json()
    
    def text_to_speech(
        self,
        text: str,
        model: str | None = None,
    ) -> bytes:
        """Text-to-speech using custom HuggingFace API endpoint."""
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        
        model_id = model or self.model
        # Try OpenAI-compatible TTS endpoint first
        try:
            response = self.client.post(
                f"{self.base_url}/v1/audio/speech",
                json={
                    "model": model_id,
                    "input": text,
                },
                headers=headers,
                timeout=DEFAULT_TIMEOUT,
            )
            response.raise_for_status()
            return response.content
        except Exception as e:
            logger.debug(f"OpenAI-compatible TTS endpoint failed, trying HuggingFace format: {e}")
        
        # Fallback to HuggingFace inference API format
        response = self.client.post(
            f"{self.base_url}/models/{model_id}",
            json={"inputs": text},
            headers=headers,
            timeout=DEFAULT_TIMEOUT,
        )
        response.raise_for_status()
        return response.content
    
    def text_to_image(
        self,
        prompt: str,
    ) -> Image.Image:
        """Text-to-image using custom HuggingFace API endpoint."""
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        
        # Try HuggingFace inference API format
        try:
            response = self.client.post(
                f"{self.base_url}/models/{self.model}",
                json={"inputs": prompt},
                headers=headers,
                timeout=DEFAULT_TIMEOUT,
            )
            response.raise_for_status()
            image_bytes = response.content
            return Image.open(io.BytesIO(image_bytes))
        except Exception as e:
            logger.debug(f"HuggingFace image endpoint failed: {e}")
            raise


class OllamaClient:
    """Ollama client wrapper that mimics InferenceClient interface for local models."""
    
    def __init__(self, base_url: str, model: str):
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.client = httpx.Client(timeout=DEFAULT_TIMEOUT)
    
    def text_generation(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.8,
        top_p: float = 0.9,
        repetition_penalty: float = 1.05,
        return_full_text: bool = False,
    ) -> str:
        """Generate text using Ollama API."""
        response = self.client.post(
            f"{self.base_url}/api/generate",
            json={
                "model": self.model,
                "prompt": prompt,
                "options": {
                    "num_predict": max_new_tokens,
                    "temperature": temperature,
                    "top_p": top_p,
                    "repeat_penalty": repetition_penalty,
                },
                "stream": False,
            },
            timeout=DEFAULT_TIMEOUT,
        )
        response.raise_for_status()
        result = response.json()
        return result.get("response", "").strip()
    
    def chat_completion(
        self,
        messages: list[dict[str, str]],
        max_tokens: int = 512,
        temperature: float = 0.8,
        top_p: float = 0.9,
    ) -> dict:
        """Chat completion using Ollama API."""
        # Convert messages format for Ollama
        ollama_messages = []
        for msg in messages:
            ollama_messages.append({
                "role": msg["role"],
                "content": msg["content"],
            })
        
        response = self.client.post(
            f"{self.base_url}/api/chat",
            json={
                "model": self.model,
                "messages": ollama_messages,
                "options": {
                    "num_predict": max_tokens,
                    "temperature": temperature,
                    "top_p": top_p,
                },
                "stream": False,
            },
            timeout=DEFAULT_TIMEOUT,
        )
        response.raise_for_status()
        result = response.json()
        
        # Format response to match HuggingFace format
        return {
            "choices": [{
                "message": {
                    "content": result.get("message", {}).get("content", "").strip()
                }
            }]
        }


def _default_client(model_id: str, use_ollama: bool = False) -> InferenceClient | OllamaClient | CustomHuggingFaceClient:
    """
    Create an InferenceClient, OllamaClient, or CustomHuggingFaceClient based on configuration.
    
    Args:
        model_id: Model identifier (HuggingFace model ID or Ollama model name)
        use_ollama: If True, use Ollama local models; if False, use HuggingFace
    
    Returns:
        InferenceClient, OllamaClient, or CustomHuggingFaceClient instance
    """
    if use_ollama and settings.use_local_models:
        logger.info(f"Using Ollama local model: {settings.ollama_story_model}")
        return OllamaClient(
            base_url=settings.ollama_base_url,
            model=settings.ollama_story_model,
        )
    
    # If custom HuggingFace API URL is set, use custom client
    if settings.hf_api_url:
        logger.info(f"Using custom HuggingFace API URL: {settings.hf_api_url} with model: {model_id}")
        return CustomHuggingFaceClient(
            base_url=settings.hf_api_url,
            model=model_id,
            token=settings.hf_token,
        )
    
    # InferenceClient uses httpx internally, but we can't directly configure timeouts
    # We'll handle timeouts at the call level with asyncio.wait_for
    logger.info(f"Using HuggingFace model: {model_id}")
    return InferenceClient(model=model_id, token=settings.hf_token)


def _handle_hf_error(
    error: Exception, model_id: str, operation: str
) -> HuggingFaceError:
    """Convert HuggingFace exceptions to structured errors."""
    error_str = str(error).lower()
    error_type = type(error).__name__.lower()

    # Check for timeout errors (various forms)
    if (
        "timeout" in error_str
        or "timeout" in error_type
        or isinstance(error, (asyncio.TimeoutError, TimeoutError))
    ):
        return HuggingFaceTimeoutError(
            f"Request to {model_id} timed out during {operation}",
            model_id=model_id,
            details={"operation": operation, "original_error": str(error)},
        )

    if "rate limit" in error_str or "429" in error_str:
        return HuggingFaceRateLimitError(
            f"Rate limit exceeded for {model_id} during {operation}",
            model_id=model_id,
            status_code=429,
            details={"operation": operation, "original_error": str(error)},
        )

    if (
        "connection" in error_str
        or "network" in error_str
        or isinstance(error, (ConnectionError, httpx.ConnectError))
    ):
        return HuggingFaceConnectionError(
            f"Connection error to {model_id} during {operation}",
            model_id=model_id,
            details={"operation": operation, "original_error": str(error)},
        )

    # Default to generic model error
    return HuggingFaceModelError(
        f"Error with {model_id} during {operation}: {str(error)}",
        model_id=model_id,
        details={"operation": operation, "original_error": str(error)},
    )


async def _run_with_retry(
    func: Callable[[], Any],
    model_id: str,
    operation: str,
    timeout: float = DEFAULT_TIMEOUT,
    max_retries: int = MAX_RETRIES,
) -> Any:
    """Run a blocking function with retries and timeout in a thread pool."""
    last_error = None

    for attempt in range(max_retries):
        try:
            # Run the blocking call in a thread pool with timeout
            result = await asyncio.wait_for(
                asyncio.to_thread(func),
                timeout=timeout,
            )
            return result
        except asyncio.TimeoutError:
            last_error = HuggingFaceTimeoutError(
                f"Request to {model_id} timed out after {timeout}s during {operation} (attempt {attempt + 1}/{max_retries})",
                model_id=model_id,
                details={
                    "operation": operation,
                    "attempt": attempt + 1,
                    "timeout": timeout,
                },
            )
            if attempt < max_retries - 1:
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))  # Exponential backoff
                continue
        except Exception as e:
            last_error = _handle_hf_error(e, model_id, operation)
            if attempt < max_retries - 1:
                # Retry on connection errors and rate limits
                if isinstance(
                    last_error, (HuggingFaceConnectionError, HuggingFaceRateLimitError)
                ):
                    await asyncio.sleep(RETRY_DELAY * (attempt + 1))
                    continue
            # Don't retry on other errors
            break

    raise last_error


@dataclass
class StoryGenerator:
    prompt_builder: PromptBuilder
    model_id: str = settings.story_model

    def __post_init__(self):
        self.client = _default_client(self.model_id)

    async def generate(self, context: PromptContext, user_agent: str | None = None) -> str:
        """
        Generate story text asynchronously with timeout and retries.
        
        Args:
            context: Prompt context for story generation
            user_agent: User-Agent header for device detection (optional, not used by HuggingFace generators)
        """
        prompt = self.prompt_builder.story_prompt(context)

        def _generate() -> str:
            # Try text_generation first, fall back to chat_completion for conversational models
            try:
                response = self.client.text_generation(
                    prompt,
                    max_new_tokens=settings.max_new_tokens,
                    temperature=0.8,
                    top_p=0.9,
                    repetition_penalty=1.05,
                    return_full_text=False,
                )
                return response.strip()
            except Exception as e:
                # If text_generation fails (e.g., model only supports conversational),
                # try using chat_completion instead
                error_str = str(e).lower()
                if "conversational" in error_str or "not supported for task text-generation" in error_str:
                    # Use chat completion format for conversational models
                    messages = [{"role": "user", "content": prompt}]
                    try:
                        response = self.client.chat_completion(
                            messages=messages,
                            max_tokens=settings.max_new_tokens,
                            temperature=0.8,
                            top_p=0.9,
                        )
                        # Extract the message content from chat completion response
                        # Response format can vary: dict with 'choices' or direct string
                        if isinstance(response, dict):
                            if "choices" in response and len(response["choices"]) > 0:
                                message = response["choices"][0].get("message", {})
                                content = message.get("content", "")
                                if content:
                                    return content.strip()
                            # Try other possible response formats
                            if "text" in response:
                                return str(response["text"]).strip()
                            if "generated_text" in response:
                                return str(response["generated_text"]).strip()
                        # If response is a string, return it directly
                        if isinstance(response, str):
                            return response.strip()
                        # Last resort: convert to string
                        return str(response).strip()
                    except Exception as chat_error:
                        # If chat_completion also fails, re-raise original error
                        raise e
                else:
                    # Re-raise if it's a different error
                    raise

        return await _run_with_retry(
            _generate,
            model_id=self.model_id,
            operation="text_generation",
            timeout=DEFAULT_TIMEOUT,
        )


@dataclass
class NarrationGenerator:
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    model_id: str = settings.tts_model

    def __post_init__(self):
        self.client = _default_client(self.model_id)

    async def synthesize(
        self,
        story: str,
        context: PromptContext,
        voice: str | None,
        supabase_client: Optional[Any] = None,
        user_agent: str | None = None,
    ) -> str:
        """
        Synthesize audio asynchronously with timeout and retries.

        Args:
            story: Story text to synthesize
            context: Prompt context
            voice: Voice to use for synthesis
            supabase_client: Supabase client for storage
            user_agent: User-Agent header for device detection (optional, not used by HuggingFace generators)

        Returns:
            Signed URL if supabase_client is provided, otherwise local file path as string
        """
        # Skip audio generation in fast mode for development
        if settings.skip_audio_generation:
            logger.info("🔇 Skipping audio generation (SKIP_AUDIO_GENERATION=true)")
            return "/assets/audio/placeholder.mp3"  # Return placeholder URL
            
        prompt = self.prompt_builder.narration_prompt(context, story)
        prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="narration")
        voice_param = voice or "alloy"

        def _synthesize() -> dict[str, Any]:
            # Use text_to_speech (new API) instead of text_to_audio (old API)
            response = self.client.text_to_speech(
                text=prompt,
            )
            # text_to_speech returns bytes directly, wrap in expected format
            if isinstance(response, bytes):
                return {"audio": response}
            # If it's already a dict, return as-is
            if isinstance(response, dict):
                return response
            # Otherwise wrap it
            return {"audio": response}

        result = await _run_with_retry(
            _synthesize,
            model_id=self.model_id,
            operation="text_to_audio",
            timeout=DEFAULT_TIMEOUT,
        )

        audio_bytes = result["audio"]
        if isinstance(audio_bytes, str):
            try:
                audio_bytes = base64.b64decode(audio_bytes)
            except Exception:
                # If decoding fails, fall back to original value
                audio_bytes = audio_bytes.encode()
        filename = f"{uuid.uuid4()}.wav"

        # Upload to Supabase Storage if client is provided
        if supabase_client:
            return supabase_client.upload_audio(audio_bytes, filename)

        # Fallback: save locally (for backward compatibility, but won't be served)
        audio_path = settings.audio_dir / filename
        audio_path.write_bytes(audio_bytes)
        return str(audio_path)


def _distribute_paragraphs(paragraphs: list[str], num_scenes: int) -> list[str]:
    """Evenly distribute paragraphs across num_scenes chunks."""
    if not paragraphs:
        return []

    if num_scenes <= 0:
        num_scenes = 1

    if len(paragraphs) <= num_scenes:
        return paragraphs

    # Calculate how many paragraphs per scene
    paragraphs_per_scene = len(paragraphs) // num_scenes
    remainder = len(paragraphs) % num_scenes

    chunks: list[str] = []
    start_idx = 0

    for i in range(num_scenes):
        # Distribute remainder paragraphs across first scenes
        chunk_size = paragraphs_per_scene + (1 if i < remainder else 0)
        end_idx = start_idx + chunk_size
        chunk = " ".join(paragraphs[start_idx:end_idx])
        chunks.append(chunk)
        start_idx = end_idx

    return chunks


def _truncate_caption(text: str, max_length: int = 200) -> str:
    """Truncate caption text to a maximum length."""
    if len(text) <= max_length:
        return text
    return text[: max_length - 3] + "..."


@dataclass
class VisualGenerator:
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    model_id: str = settings.image_model

    def __post_init__(self):
        self.client = _default_client(self.model_id)

    def _create_placeholder_image(
        self, width: int = 1280, height: int = 720
    ) -> Image.Image:
        """Create a placeholder image when HuggingFace generation fails."""
        image = Image.new("RGB", (width, height), color=(45, 45, 60))  # Dark blue-gray
        draw = ImageDraw.Draw(image)

        # Try to use a nice font, fall back to default
        try:
            font_large = ImageFont.truetype("arial.ttf", 48)
            font_small = ImageFont.truetype("arial.ttf", 24)
        except OSError:
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()

        # Draw centered text
        text = "Dream Flow"
        text_bbox = draw.textbbox((0, 0), text, font=font_large)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        x = (width - text_width) // 2
        y = (height - text_height) // 2 - 30

        draw.text((x, y), text, font=font_large, fill=(255, 255, 255))

        subtitle = "Visualizing your story..."
        sub_bbox = draw.textbbox((0, 0), subtitle, font=font_small)
        sub_width = sub_bbox[2] - sub_bbox[0]
        sub_x = (width - sub_width) // 2
        sub_y = y + text_height + 20

        draw.text((sub_x, sub_y), subtitle, font=font_small, fill=(200, 200, 200))

        return image

    async def create_frames(
        self,
        story: str,
        context: PromptContext,
        num_scenes: int,
        supabase_client: Optional[Any] = None,
        storage_prefix: str | None = None,
        include_text_overlay: bool = True,
    ) -> list[str]:
        """Create visual frames asynchronously with timeout and retries.

        Evenly distributes paragraphs across num_scenes, truncates captions,
        and falls back to placeholder images when HuggingFace calls fail.

        Args:
            story: The story text to convert to frames
            context: Prompt context for image generation
            num_scenes: Number of scenes to generate
            supabase_client: Optional Supabase client for storage
            storage_prefix: Optional prefix for storage paths
            include_text_overlay: Whether to include text captions on images (default: True)

        Returns:
            Signed URLs if supabase_client is provided, otherwise local file paths as strings
        """
        paragraphs = [p.strip() for p in story.split("\n") if p.strip()]

        # Evenly distribute paragraphs across num_scenes
        if not paragraphs:
            chunks = [story]
        else:
            chunks = _distribute_paragraphs(paragraphs, num_scenes)

        frames: list[str] = []

        normalized_prefix = ""
        if storage_prefix:
            normalized_prefix = f"{storage_prefix.strip('/')}/"

        for idx, chunk in enumerate(chunks):
            # Truncate caption for overlay
            caption = _truncate_caption(chunk)

            try:
                prompt = self.prompt_builder.visual_prompt(context, chunk)
                prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="visual")

                def _generate_image() -> Image.Image:
                    return self.client.text_to_image(prompt)

                # Generate image with retry and timeout
                image_result = await _run_with_retry(
                    _generate_image,
                    model_id=self.model_id,
                    operation=f"text_to_image (scene {idx + 1}/{len(chunks)})",
                    timeout=DEFAULT_TIMEOUT,
                )

                # Image processing with proper WebP/PIL object handling
                def _process_image() -> bytes:
                    # Handle both bytes and PIL Image objects from HuggingFace API
                    if isinstance(image_result, bytes):
                        # Standard bytes response
                        image = Image.open(io.BytesIO(image_result))
                    else:
                        # PIL Image object (WebPImageFile, etc.)
                        image = image_result
                    
                    # Apply caption overlay if needed
                    if include_text_overlay:
                        image = self._overlay_caption(image, caption)
                    
                    # Convert to bytes buffer
                    buffer = io.BytesIO()
                    image.save(buffer, format="PNG")
                    return buffer.getvalue()

                frame_bytes = await asyncio.to_thread(_process_image)

                # Azure Content Safety image moderation (post-generation safety check)
                try:
                    from ..core.azure_content_safety import get_content_safety_client
                    from ..shared.config import get_settings
                    settings = get_settings()
                    
                    if settings.azure_content_safety_enabled:
                        content_safety_client = get_content_safety_client()
                        if content_safety_client:
                            # Moderate image before saving/uploading
                            moderation_result = content_safety_client.moderate_image(frame_bytes)
                            if not moderation_result.get("is_safe", True):
                                # Image failed moderation - use placeholder instead
                                logger.warning(
                                    f"Image failed Azure Content Safety moderation for scene {idx + 1}, using placeholder"
                                )
                                # Create placeholder image
                                placeholder_image = self._create_placeholder_image()
                                if include_text_overlay:
                                    placeholder_image = self._overlay_caption(placeholder_image, caption)
                                buffer = io.BytesIO()
                                placeholder_image.save(buffer, format="PNG")
                                frame_bytes = buffer.getvalue()
                except Exception as e:
                    # Fail open - continue with original image if moderation fails
                    logger.warning(f"Azure Content Safety image moderation failed: {e}")

                # Azure Computer Vision image analysis (generate alt-text for accessibility)
                try:
                    from ..core.azure_computer_vision import get_computer_vision_client
                    from ..shared.config import get_settings
                    settings = get_settings()
                    
                    if settings.azure_computer_vision_enabled:
                        computer_vision_client = get_computer_vision_client()
                        if computer_vision_client:
                            # Generate image description for accessibility (alt-text)
                            description_result = computer_vision_client.describe_image(frame_bytes)
                            if description_result.get("captions"):
                                alt_text = description_result["captions"][0].get("text", "")
                                logger.info(f"Azure Computer Vision alt-text for scene {idx + 1}: {alt_text}")
                                # Tags can be used for search/recommendations
                                tags = description_result.get("tags", [])
                                if tags:
                                    logger.debug(f"Azure Computer Vision tags for scene {idx + 1}: {tags}")
                except Exception as e:
                    # Fail open - continue if analysis fails
                    logger.warning(f"Azure Computer Vision image analysis failed: {e}")

                # Upload to Supabase Storage if client is provided
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(frame_bytes, filename)
                    frames.append(frame_url)
                else:
                    # Fallback: save locally and return /assets URL for HTTP serving
                    def _save_local() -> str:
                        import uuid
                        from ..shared.config import get_settings
                        settings = get_settings()
                        filename = f"{uuid.uuid4()}.png"
                        # Save to asset_dir/frames for static file serving
                        frames_dir = settings.asset_dir / "frames"
                        frames_dir.mkdir(parents=True, exist_ok=True)
                        path = frames_dir / filename
                        path.write_bytes(frame_bytes)
                        # Return /assets/frames/... URL instead of file path
                        return f"/assets/frames/{filename}"

                    frame_url = await asyncio.to_thread(_save_local)
                    frames.append(frame_url)

            except HuggingFaceError:
                # Fall back to placeholder image on any HuggingFace error
                def _create_placeholder() -> bytes:
                    image = self._create_placeholder_image()
                    image = self._overlay_caption(image, caption)
                    # Save to bytes buffer instead of file
                    buffer = io.BytesIO()
                    image.save(buffer, format="PNG")
                    return buffer.getvalue()

                placeholder_bytes = await asyncio.to_thread(_create_placeholder)

                # Upload to Supabase Storage if client is provided
                if supabase_client:
                    filename = f"{normalized_prefix}{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(
                        placeholder_bytes, filename
                    )
                    frames.append(frame_url)
                else:
                    # Fallback: save locally and return /assets URL for HTTP serving
                    def _save_local() -> str:
                        import uuid
                        from ..shared.config import get_settings
                        settings = get_settings()
                        filename = f"{uuid.uuid4()}.png"
                        # Save to asset_dir/frames for static file serving
                        frames_dir = settings.asset_dir / "frames"
                        frames_dir.mkdir(parents=True, exist_ok=True)
                        path = frames_dir / filename
                        path.write_bytes(placeholder_bytes)
                        # Return /assets/frames/... URL instead of file path
                        return f"/assets/frames/{filename}"

                    frame_url = await asyncio.to_thread(_save_local)
                    frames.append(frame_url)

        return frames

    def _overlay_caption(self, image: Image.Image, text: str) -> Image.Image:
        overlay = image.copy()
        draw = ImageDraw.Draw(overlay)
        width, height = overlay.size
        font_size = max(24, width // 28)
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except OSError:
            font = ImageFont.load_default()

        text_block = textwrap.fill(text, width=40)
        text_bbox = draw.multiline_textbbox((0, 0), text_block, font=font)
        padding = 20
        box_width = width - 2 * padding
        box_height = text_bbox[3] - text_bbox[1] + 2 * padding
        y_position = height - box_height - padding
        draw.rectangle(
            (padding, y_position, padding + box_width, y_position + box_height),
            fill=(0, 0, 0, 180),
        )
        draw.multiline_text(
            (padding + 10, y_position + padding),
            text_block,
            font=font,
            fill=(255, 255, 255),
        )
        return overlay



def get_inference_config(ai_mode: str) -> dict:
    """
    Parse AI_INFERENCE_MODE into fallback chains and settings.
    
    Args:
        ai_mode: AI inference mode string
        
    Returns:
        Dictionary with primary mode, fallback chain, and settings
    """
    
    mode_configs = {
        # Fallback modes (with backup options for reliability)
        "cloud_first": {
            "primary": "cloud",
            "fallback_chain": ["cloud", "local", "native_mobile"],
            "allow_fallback": True,
            "description": "Cloud APIs → Server Local → Phone Local"
        },
        "server_first": {
            "primary": "local", 
            "fallback_chain": ["local", "cloud", "native_mobile"],
            "allow_fallback": True,
            "description": "Server Local → Cloud APIs → Phone Local"
        },
        "phone_first": {
            "primary": "native_mobile",
            "fallback_chain": ["native_mobile", "local", "cloud"],
            "allow_fallback": True,
            "description": "Phone Local → Server Local → Cloud APIs"
        },
        
        # Single modes (no fallback - fail if unavailable)
        "cloud_only": {
            "primary": "cloud",
            "fallback_chain": ["cloud"],
            "allow_fallback": False,
            "description": "Only HuggingFace APIs, no fallback"
        },
        "server_only": {
            "primary": "local",
            "fallback_chain": ["local"],
            "allow_fallback": False,
            "description": "Only Server Local models, no fallback"
        },
        "phone_only": {
            "primary": "native_mobile",
            "fallback_chain": ["native_mobile"],
            "allow_fallback": False,
            "description": "Only Phone Local models, no fallback"
        }
    }
    
    # Default to server_first if invalid mode provided
    config = mode_configs.get(ai_mode, mode_configs["server_first"])
    
    # Log the selected configuration
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"🎯 AI Inference Mode: {ai_mode}")
    logger.info(f"📋 Strategy: {config['description']}")
    logger.info(f"🔄 Fallback Chain: {' → '.join(config['fallback_chain'])}")
    
    return config


def _get_cloud_generators(prompt_builder: PromptBuilder) -> tuple:
    """Get pure HuggingFace cloud API generators."""
    logger.info("🌐 Using CLOUD inference mode (HuggingFace APIs)")
    
    story_gen = StoryGenerator(prompt_builder=prompt_builder)
    narration_gen = NarrationGenerator(prompt_builder=prompt_builder)  
    visual_gen = VisualGenerator(prompt_builder=prompt_builder)
    
    return (story_gen, narration_gen, visual_gen)


def get_generators(prompt_builder: PromptBuilder, user_agent: str | None = None) -> tuple:
    """
    Factory function to get the appropriate generators based on configuration.
    
    Uses unified AI_INFERENCE_MODE for clear control:
    - cloud_first: Cloud → Server Local → Phone Local  
    - server_first: Server Local → Cloud → Phone Local
    - phone_first: Phone Local → Server Local → Cloud
    - cloud_only: Only HuggingFace APIs (fast multimedia)
    - server_only: Only Server Local models
    - phone_only: Only Phone Local models
    
    Args:
        prompt_builder: The PromptBuilder instance for generating prompts
        user_agent: User-Agent header from request (optional, for mobile detection)
        
    Returns:
        Tuple of (story_generator, narration_generator, visual_generator)
    """
    from .version_detector import get_recommended_version, detect_available_versions
    
    # Get unified AI inference configuration
    ai_mode = getattr(settings, 'ai_inference_mode', 'server_first')
    config = get_inference_config(ai_mode)
    
    # Handle legacy INFERENCE_VERSION for backward compatibility
    if ai_mode == 'server_first' and hasattr(settings, 'inference_version'):
        legacy_version = settings.inference_version
        if legacy_version == "apple":
            ai_mode = "phone_first"  # Prioritize Apple/mobile
            config = get_inference_config(ai_mode)
        elif legacy_version == "native_mobile":
            ai_mode = "phone_first"
            config = get_inference_config(ai_mode)
        
        logger.info(f"🔄 Legacy INFERENCE_VERSION={legacy_version} mapped to AI_INFERENCE_MODE={ai_mode}")
    
    # Try generators in order specified by the configuration
    last_error = None
    for version in config["fallback_chain"]:
        try:
            if version == "cloud":
                return _get_cloud_generators(prompt_builder)
            elif version == "native_mobile":
                logger.info("�📱 Using native mobile inference mode (TFLite/Core ML)")
                return _get_native_mobile_generators(prompt_builder)
            elif version == "local":
                return _get_local_generators(prompt_builder)
            elif version == "apple":
                return _get_apple_generators(prompt_builder)
        except Exception as e:
            logger.warning(f"❌ Failed to initialize {version} generators: {e}")
            last_error = e
            if not config["allow_fallback"]:
                # For *_only modes, don't continue fallback chain
                logger.error(f"🚫 {ai_mode} mode failed and fallback is disabled")
                raise e
            logger.info(f"🔄 Falling back to next option in chain...")
            continue
    
    # If all options in chain failed
    if last_error:
        logger.error(f"💥 All inference options failed in {ai_mode} mode")
        raise RuntimeError(f"Failed to initialize any inference version in {ai_mode} mode. Last error: {last_error}")
    
    # This shouldn't be reached with the new system
    logger.error("🚨 Unexpected: No generators initialized")
    raise RuntimeError("No generators could be initialized")


def _get_local_generators(prompt_builder: PromptBuilder) -> tuple:
    """Get local inference generators."""
    from .local_services import (
        LocalStoryGenerator,
        LocalNarrationGenerator,
        LocalVisualGenerator,
        is_local_inference_available,
    )
    
    if not is_local_inference_available():
        deps = "llama-cpp-python edge-tts aiofiles"
        try:
            import llama_cpp
            import edge_tts
        except ImportError:
            raise ImportError(
                "Local inference is enabled but required packages are not installed. "
                f"Please install with: pip install {deps}"
            )
    
    logger.info("Using LOCAL inference mode (CPU-optimized)")
    
    story_gen = LocalStoryGenerator(prompt_builder=prompt_builder)
    narration_gen = LocalNarrationGenerator(prompt_builder=prompt_builder)
    visual_gen = LocalVisualGenerator(prompt_builder=prompt_builder)
    
    return (story_gen, narration_gen, visual_gen)


def _get_apple_generators(prompt_builder: PromptBuilder) -> tuple:
    """Get Apple Intelligence API generators."""
    from .apple_services import (
        AppleStoryGenerator,
        AppleNarrationGenerator,
        AppleVisualGenerator,
    )
    
    logger.info("Using APPLE inference mode (Apple Intelligence / Core ML)")
    
    story_gen = AppleStoryGenerator(prompt_builder=prompt_builder)
    narration_gen = AppleNarrationGenerator(prompt_builder=prompt_builder)
    visual_gen = AppleVisualGenerator(prompt_builder=prompt_builder)
    
    return (story_gen, narration_gen, visual_gen)


def _get_native_mobile_generators(prompt_builder: PromptBuilder) -> tuple:
    """Get native mobile generators (TFLite for Android, Core ML for iOS)."""
    from .native_mobile_services import (
        NativeMobileStoryGenerator,
        NativeMobileNarrationGenerator,
        NativeMobileVisualGenerator,
    )
    
    logger.info("Using NATIVE MOBILE inference mode (TFLite/Core ML via Flutter ML server)")
    
    story_gen = NativeMobileStoryGenerator(prompt_builder=prompt_builder)
    narration_gen = NativeMobileNarrationGenerator(prompt_builder=prompt_builder)
    visual_gen = NativeMobileVisualGenerator(prompt_builder=prompt_builder)
    
    return (story_gen, narration_gen, visual_gen)
