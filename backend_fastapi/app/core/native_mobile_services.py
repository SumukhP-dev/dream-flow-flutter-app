"""
Native mobile inference services for Tensor chip (Android) and Neural Engine (iOS).

These services call the Flutter ML HTTP server running on localhost:8081
to perform inference using native ML frameworks (TFLite/Core ML).
"""

from __future__ import annotations

import asyncio
import base64
import io
import logging
from dataclasses import dataclass, field
from typing import Any, Optional

import httpx
from PIL import Image

from ..shared.config import get_settings
from ..core.prompting import PromptBuilder, PromptContext
from ..core.guardrails import PromptSanitizer

settings = get_settings()
logger = logging.getLogger(__name__)

# ML HTTP server URL (Flutter app exposes this)
ML_SERVER_URL = "http://localhost:8081"
ML_SERVER_TIMEOUT = 120.0  # 2 minutes for inference


@dataclass
class NativeMobileStoryGenerator:
    """Story generator using native mobile ML (TFLite/Core ML)."""
    
    prompt_builder: PromptBuilder
    ml_server_url: str = ML_SERVER_URL
    
    async def generate(self, context: PromptContext, user_agent: str | None = None) -> str:
        """
        Generate story text using native mobile ML model.
        
        Args:
            context: Prompt context for story generation
            user_agent: User-Agent header (not used for native mobile)
        """
        prompt = self.prompt_builder.story_prompt(context)
        
        try:
            async with httpx.AsyncClient(timeout=ML_SERVER_TIMEOUT) as client:
                response = await client.post(
                    f"{self.ml_server_url}/ml/story/generate",
                    json={
                        "prompt": prompt,
                        "maxTokens": settings.max_new_tokens,
                        "temperature": 0.8,
                    },
                )
                response.raise_for_status()
                result = response.json()
                story_text = result.get("story_text", "")
                
                if not story_text:
                    raise ValueError("Empty story text returned from native ML")
                
                logger.info(f"Generated story using native mobile ML ({result.get('model', 'unknown')})")
                return story_text
                
        except httpx.TimeoutException:
            logger.error("Native ML story generation timed out")
            raise TimeoutError("Story generation timed out")
        except httpx.RequestError as e:
            logger.error(f"Failed to connect to ML server: {e}")
            raise ConnectionError(f"ML server not available: {e}")
        except Exception as e:
            logger.error(f"Native ML story generation failed: {e}")
            raise RuntimeError(f"Story generation failed: {e}")


@dataclass
class NativeMobileVisualGenerator:
    """Visual generator using native mobile ML (TFLite/Core ML)."""
    
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    ml_server_url: str = ML_SERVER_URL
    
    async def create_frames(
        self,
        story: str,
        context: PromptContext,
        num_scenes: int,
        supabase_client: Optional[Any] = None,
        storage_prefix: str | None = None,
    ) -> list[str]:
        """
        Create visual frames using native mobile ML model.
        
        Args:
            story: Story text
            context: Prompt context
            num_scenes: Number of scenes to generate
            supabase_client: Optional Supabase client for storage
            storage_prefix: Optional storage prefix
            
        Returns:
            List of frame URLs or file paths
        """
        paragraphs = [p.strip() for p in story.split("\n") if p.strip()]
        
        # Distribute paragraphs across scenes
        if not paragraphs:
            chunks = [story]
        else:
            from ..core.services import _distribute_paragraphs
            chunks = _distribute_paragraphs(paragraphs, num_scenes)
        
        frames: list[str] = []
        
        for idx, chunk in enumerate(chunks):
            try:
                prompt = self.prompt_builder.visual_prompt(context, chunk)
                prompt = self.prompt_sanitizer.enforce(prompt, prompt_type="visual")
                
                # Generate image using native ML
                image_bytes = await self._generate_image(prompt)
                
                if image_bytes:
                    # Process and save image
                    image = Image.open(io.BytesIO(image_bytes))
                    
                    # Overlay caption
                    from ..core.services import _truncate_caption
                    caption = _truncate_caption(chunk)
                    image = self._overlay_caption(image, caption)
                    
                    # Save to buffer
                    buffer = io.BytesIO()
                    image.save(buffer, format="PNG")
                    frame_bytes = buffer.getvalue()
                    
                    # Upload to Supabase or save locally
                    if supabase_client:
                        import uuid
                        filename = f"{storage_prefix or ''}{uuid.uuid4()}.png"
                        frame_url = supabase_client.upload_frame(frame_bytes, filename)
                        frames.append(frame_url)
                    else:
                        # Save locally and return /assets URL for HTTP serving
                        import uuid
                        filename = f"{uuid.uuid4()}.png"
                        # Save to asset_dir/frames for static file serving
                        frames_dir = settings.asset_dir / "frames"
                        frames_dir.mkdir(parents=True, exist_ok=True)
                        frame_path = frames_dir / filename
                        frame_path.write_bytes(frame_bytes)
                        # Return /assets/frames/... URL instead of file path
                        frames.append(f"/assets/frames/{filename}")
                else:
                    # Use placeholder if generation failed
                    logger.warning(f"Image generation failed for scene {idx + 1}, using placeholder")
                    from ..core.services import VisualGenerator
                    visual_gen = VisualGenerator(
                        prompt_builder=self.prompt_builder,
                        prompt_sanitizer=self.prompt_sanitizer,
                    )
                    placeholder_frames = await visual_gen.create_frames(
                        story, context, 1, supabase_client, storage_prefix
                    )
                    frames.extend(placeholder_frames)
                    
            except Exception as e:
                logger.error(f"Error generating frame {idx + 1}: {e}")
                # Fall back to placeholder
                from ..core.services import VisualGenerator
                visual_gen = VisualGenerator(
                    prompt_builder=self.prompt_builder,
                    prompt_sanitizer=self.prompt_sanitizer,
                )
                placeholder_frames = await visual_gen.create_frames(
                    story, context, 1, supabase_client, storage_prefix
                )
                frames.extend(placeholder_frames)
        
        return frames
    
    async def _generate_image(self, prompt: str) -> bytes | None:
        """Generate image using native ML server."""
        try:
            async with httpx.AsyncClient(timeout=ML_SERVER_TIMEOUT) as client:
                response = await client.post(
                    f"{self.ml_server_url}/ml/image/generate",
                    json={
                        "prompt": prompt,
                        "width": 512,
                        "height": 512,
                        "numInferenceSteps": 20,
                    },
                )
                
                if response.status_code == 501:
                    # Not implemented - return None to use placeholder
                    logger.info("Image generation not implemented, using placeholder")
                    return None
                
                response.raise_for_status()
                result = response.json()
                
                # Decode base64 image
                image_base64 = result.get("image", "")
                if image_base64:
                    image_bytes = base64.b64decode(image_base64)
                    logger.info(f"Generated image using native mobile ML ({result.get('model', 'unknown')})")
                    return image_bytes
                
                return None
                
        except httpx.TimeoutException:
            logger.error("Native ML image generation timed out")
            return None
        except httpx.RequestError as e:
            logger.error(f"Failed to connect to ML server: {e}")
            return None
        except Exception as e:
            logger.error(f"Native ML image generation failed: {e}")
            return None
    
    def _overlay_caption(self, image: Image.Image, text: str) -> Image.Image:
        """Overlay caption on image."""
        from ..core.services import VisualGenerator
        visual_gen = VisualGenerator(
            prompt_builder=self.prompt_builder,
            prompt_sanitizer=self.prompt_sanitizer,
        )
        return visual_gen._overlay_caption(image, text)


@dataclass
class NativeMobileNarrationGenerator:
    """Narration generator using native mobile TTS."""
    
    prompt_builder: PromptBuilder
    prompt_sanitizer: PromptSanitizer = field(default_factory=PromptSanitizer)
    ml_server_url: str = ML_SERVER_URL
    
    async def synthesize(
        self,
        story: str,
        context: PromptContext,
        voice: str | None,
        supabase_client: Optional[Any] = None,
        user_agent: str | None = None,
    ) -> str:
        """
        Synthesize audio using local TTS.
        
        Note: TTS is handled client-side by native APIs (AVSpeechSynthesizer on iOS,
        Android TTS on Android). This generator uses local TTS as a fallback for backend
        audio generation when client-side TTS is not available.
        """
        # Use local TTS directly - TTS is primarily client-side
        from ..core.local_services import LocalNarrationGenerator
        
        local_tts = LocalNarrationGenerator(
            prompt_builder=self.prompt_builder,
            prompt_sanitizer=self.prompt_sanitizer,
        )
        
        return await local_tts.synthesize(
            story, context, voice, supabase_client, user_agent
        )

