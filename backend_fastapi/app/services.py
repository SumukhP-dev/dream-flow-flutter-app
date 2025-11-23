from __future__ import annotations

import asyncio
import io
import os
import tempfile
import textwrap
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Optional

import httpx
from huggingface_hub import InferenceClient
from moviepy.editor import AudioFileClip, ImageClip, concatenate_videoclips
from PIL import Image, ImageDraw, ImageFont

from .config import get_settings
from .exceptions import (
    HuggingFaceConnectionError,
    HuggingFaceError,
    HuggingFaceModelError,
    HuggingFaceRateLimitError,
    HuggingFaceTimeoutError,
)
from .prompting import PromptBuilder, PromptContext
from .guardrails import GuardrailError, PromptSanitizer


settings = get_settings()

# Default timeout values (in seconds)
DEFAULT_TIMEOUT = 120.0  # 2 minutes for inference
DEFAULT_CONNECT_TIMEOUT = 10.0  # 10 seconds for connection
MAX_RETRIES = 3
RETRY_DELAY = 1.0  # seconds between retries


def _default_client(model_id: str) -> InferenceClient:
    """Create an InferenceClient with timeout configuration."""
    # InferenceClient uses httpx internally, but we can't directly configure timeouts
    # We'll handle timeouts at the call level with asyncio.wait_for
    # Note: InferenceClient doesn't support custom base URL for local mock service
    # For local development with mock service, modify this function to use httpx directly
    # when HUGGINGFACE_API_URL is set to a custom value
    return InferenceClient(model=model_id, token=settings.hf_token)


def _handle_hf_error(error: Exception, model_id: str, operation: str) -> HuggingFaceError:
    """Convert HuggingFace exceptions to structured errors."""
    error_str = str(error).lower()
    error_type = type(error).__name__.lower()
    
    # Check for timeout errors (various forms)
    if "timeout" in error_str or "timeout" in error_type or isinstance(error, (asyncio.TimeoutError, TimeoutError)):
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
    
    if "connection" in error_str or "network" in error_str or isinstance(error, (ConnectionError, httpx.ConnectError)):
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
                details={"operation": operation, "attempt": attempt + 1, "timeout": timeout},
            )
            if attempt < max_retries - 1:
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))  # Exponential backoff
                continue
        except Exception as e:
            last_error = _handle_hf_error(e, model_id, operation)
            if attempt < max_retries - 1:
                # Retry on connection errors and rate limits
                if isinstance(last_error, (HuggingFaceConnectionError, HuggingFaceRateLimitError)):
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

    async def generate(self, context: PromptContext) -> str:
        """Generate story text asynchronously with timeout and retries."""
        prompt = self.prompt_builder.story_prompt(context)
        
        def _generate() -> str:
            response = self.client.text_generation(
                prompt,
                max_new_tokens=settings.max_new_tokens,
                temperature=0.8,
                top_p=0.9,
                repetition_penalty=1.05,
                return_full_text=False,
            )
            return response.strip()
        
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
    ) -> str:
        """
        Synthesize audio asynchronously with timeout and retries.
        
        Returns:
            Signed URL if supabase_client is provided, otherwise local file path as string
        """
        prompt = self.prompt_builder.narration_prompt(context, story)
        prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="narration")
        voice_param = voice or "alloy"
        
        def _synthesize() -> dict[str, Any]:
            return self.client.text_to_audio(
                text=prompt,
                voice=voice_param,
            )
        
        result = await _run_with_retry(
            _synthesize,
            model_id=self.model_id,
            operation="text_to_audio",
            timeout=DEFAULT_TIMEOUT,
        )
        
        audio_bytes = result["audio"]
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
    return text[:max_length - 3] + "..."


@dataclass
class VisualGenerator:
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    model_id: str = settings.image_model

    def __post_init__(self):
        self.client = _default_client(self.model_id)

    def _create_placeholder_image(self, width: int = 1280, height: int = 720) -> Image.Image:
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
    ) -> list[str]:
        """Create visual frames asynchronously with timeout and retries.
        
        Evenly distributes paragraphs across num_scenes, truncates captions,
        and falls back to placeholder images when HuggingFace calls fail.
        
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
        
        for idx, chunk in enumerate(chunks):
            # Truncate caption for overlay
            caption = _truncate_caption(chunk)
            
            try:
                prompt = self.prompt_builder.visual_prompt(context, chunk)
                prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="visual")
                
                def _generate_image() -> bytes:
                    return self.client.text_to_image(prompt)
                
                # Generate image with retry and timeout
                image_bytes = await _run_with_retry(
                    _generate_image,
                    model_id=self.model_id,
                    operation=f"text_to_image (scene {idx + 1}/{len(chunks)})",
                    timeout=DEFAULT_TIMEOUT,
                )
                
                # Image processing can be done in thread pool as well
                def _process_image() -> bytes:
                    image = Image.open(io.BytesIO(image_bytes))
                    image = self._overlay_caption(image, caption)
                    # Save to bytes buffer instead of file
                    buffer = io.BytesIO()
                    image.save(buffer, format="PNG")
                    return buffer.getvalue()
                
                frame_bytes = await asyncio.to_thread(_process_image)
                
                # Upload to Supabase Storage if client is provided
                if supabase_client:
                    filename = f"{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(frame_bytes, filename)
                    frames.append(frame_url)
                else:
                    # Fallback: save locally (for backward compatibility)
                    def _save_local() -> str:
                        path = settings.frames_dir / f"{uuid.uuid4()}.png"
                        path.write_bytes(frame_bytes)
                        return str(path)
                    
                    frame_path = await asyncio.to_thread(_save_local)
                    frames.append(frame_path)
                
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
                    filename = f"{uuid.uuid4()}.png"
                    frame_url = supabase_client.upload_frame(placeholder_bytes, filename)
                    frames.append(frame_url)
                else:
                    # Fallback: save locally
                    def _save_local() -> str:
                        path = settings.frames_dir / f"{uuid.uuid4()}.png"
                        path.write_bytes(placeholder_bytes)
                        return str(path)
                    
                    frame_path = await asyncio.to_thread(_save_local)
                    frames.append(frame_path)
        
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


async def stitch_video(
    frame_paths: list[str],
    audio_path: str,
    supabase_client: Optional[Any] = None,
) -> str:
    """
    Stitch frames and audio into a video.
    
    Args:
        frame_paths: List of frame URLs or local paths
        audio_path: Audio URL or local path
        supabase_client: Optional SupabaseClient for uploading video
        
    Returns:
        Signed URL if supabase_client is provided, otherwise local file path as string
    """
    # Download files if they're URLs (for Supabase Storage)
    # For local paths, use them directly
    with tempfile.TemporaryDirectory() as temp_dir:
        # Download or copy audio
        if audio_path.startswith("http"):
            async with httpx.AsyncClient() as client:
                response = await client.get(audio_path)
                response.raise_for_status()
                audio_file = os.path.join(temp_dir, "audio.wav")
                with open(audio_file, "wb") as f:
                    f.write(response.content)
        else:
            audio_file = audio_path
        
        # Download or copy frames
        frame_files = []
        for idx, frame_path in enumerate(frame_paths):
            if frame_path.startswith("http"):
                async with httpx.AsyncClient() as client:
                    response = await client.get(frame_path)
                    response.raise_for_status()
                    frame_file = os.path.join(temp_dir, f"frame_{idx}.png")
                    with open(frame_file, "wb") as f:
                        f.write(response.content)
                    frame_files.append(frame_file)
            else:
                frame_files.append(frame_path)
        
        # Process video in thread pool
        def _create_video() -> bytes:
            clips = []
            audio = None
            video = None
            try:
                audio = AudioFileClip(audio_file)
                duration_per_clip = max(audio.duration / max(1, len(frame_files)), 2.0)
                for path in frame_files:
                    clip = ImageClip(path).set_duration(duration_per_clip).resize(height=720)
                    clips.append(clip)
                video = concatenate_videoclips(clips, method="compose").set_audio(audio)
                
                # Write to temporary file
                temp_video = os.path.join(temp_dir, "video.mp4")
                video.write_videofile(temp_video, fps=24, codec="libx264", audio_codec="aac", verbose=False, logger=None)
                
                # Read video bytes
                with open(temp_video, "rb") as f:
                    video_bytes = f.read()
                
                return video_bytes
            finally:
                # Ensure all resources are cleaned up even if an error occurs
                # Close in reverse order: composite video first, then components
                if video is not None:
                    try:
                        video.close()
                    except Exception:
                        pass  # Ignore errors during cleanup
                for clip in clips:
                    try:
                        clip.close()
                    except Exception:
                        pass  # Ignore errors during cleanup
                if audio is not None:
                    try:
                        audio.close()
                    except Exception:
                        pass  # Ignore errors during cleanup
        
        video_bytes = await asyncio.to_thread(_create_video)
        filename = f"{uuid.uuid4()}.mp4"
        
        # Upload to Supabase Storage if client is provided
        if supabase_client:
            return supabase_client.upload_video(video_bytes, filename)
        
        # Fallback: save locally (for backward compatibility, but won't be served)
        video_path = settings.video_dir / filename
        video_path.write_bytes(video_bytes)
        return str(video_path)


