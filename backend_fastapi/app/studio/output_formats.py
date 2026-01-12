from __future__ import annotations

import asyncio
import io
import os
import secrets
import tempfile
from dataclasses import dataclass
from enum import Enum
from typing import Any, Optional

import httpx
from PIL import Image

from ..shared.config import get_settings
from ..shared.supabase_client import SupabaseClient


settings = get_settings()


class OutputFormat(str, Enum):
    """Supported output formats."""

    AUDIO_MP3 = "audio_mp3"
    CAPTIONS_SRT = "captions_srt"
    THUMBNAIL = "thumbnail"
    METADATA = "metadata"


@dataclass
class OutputFormats:
    """Container for all generated output formats."""

    audio_mp3: Optional[str] = None
    captions_srt: Optional[str] = None
    thumbnail: Optional[str] = None
    metadata: Optional[dict] = None


class OutputFormatService:
    """Service for generating multiple output formats from story assets."""

    def __init__(self, supabase_client: Optional[SupabaseClient] = None):
        """
        Initialize OutputFormatService.

        Args:
            supabase_client: Optional SupabaseClient for uploading assets
        """
        self.supabase_client = supabase_client

    async def generate_all_formats(
        self,
        frame_urls: list[str],
        audio_url: str,
        story_text: str,
        theme: str,
        formats: Optional[list[OutputFormat]] = None,
    ) -> OutputFormats:
        """
        Generate all requested output formats.

        Args:
            frame_urls: List of frame URLs
            audio_url: Audio file URL
            story_text: Story text for captions
            theme: Story theme for metadata
            formats: List of formats to generate (None = all formats)

        Returns:
            OutputFormats with generated asset URLs
        """
        if formats is None:
            formats = list(OutputFormat)

        result = OutputFormats()

        # Generate formats in parallel where possible
        tasks = []

        if OutputFormat.VIDEO_16_9 in formats:
            tasks.append(
                ("video_16_9", self._generate_video_16_9(frame_urls, audio_url))
            )

        if OutputFormat.VIDEO_9_16 in formats:
            tasks.append(
                ("video_9_16", self._generate_video_9_16(frame_urls, audio_url))
            )

        if OutputFormat.AUDIO_MP3 in formats:
            tasks.append(("audio_mp3", self._generate_audio_mp3(audio_url)))

        if OutputFormat.CAPTIONS_SRT in formats:
            tasks.append(
                ("captions_srt", self._generate_captions_srt(story_text, audio_url))
            )

        if OutputFormat.THUMBNAIL in formats:
            tasks.append(
                (
                    "thumbnail",
                    self._generate_thumbnail(
                        frame_urls[0] if frame_urls else None,
                        theme=theme,
                    ),
                )
            )

        if OutputFormat.METADATA in formats:
            result.metadata = self._generate_metadata(
                story_text, theme, len(frame_urls), video_id=None
            )

        # Execute tasks
        for key, task in tasks:
            try:
                value = await task
                setattr(result, key, value)
            except Exception as e:
                # Log error but continue with other formats
                print(f"Warning: Failed to generate {key}: {e}")

        return result

    async def _generate_video_16_9(self, frame_urls: list[str], audio_url: str) -> str:
        """Generate 16:9 video (1920x1080)."""
        return await self._generate_video(
            frame_urls, audio_url, width=1920, height=1080
        )

    async def _generate_video_9_16(self, frame_urls: list[str], audio_url: str) -> str:
        """Generate 9:16 vertical video (1080x1920)."""
        return await self._generate_video(
            frame_urls, audio_url, width=1080, height=1920
        )

    async def _generate_video(
        self,
        frame_urls: list[str],
        audio_url: str,
        width: int,
        height: int,
    ) -> str:
        """Generate video with specified dimensions."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download audio
            audio_file = await self._download_file(
                audio_url, os.path.join(temp_dir, "audio.wav")
            )

            # Download frames
            frame_files = []
            for idx, frame_url in enumerate(frame_urls):
                frame_file = await self._download_file(
                    frame_url, os.path.join(temp_dir, f"frame_{idx}.png")
                )
                frame_files.append(frame_file)

            # Generate video
            def _create_video() -> bytes:
                clips = []
                audio = None
                video = None
                try:
                    audio = AudioFileClip(audio_file)
                    duration_per_clip = max(
                        audio.duration / max(1, len(frame_files)), 2.0
                    )

                    for path in frame_files:
                        # Resize frame to target dimensions
                        clip = (
                            ImageClip(path)
                            .set_duration(duration_per_clip)
                            .resize((width, height))
                        )
                        clips.append(clip)

                    video = concatenate_videoclips(clips, method="compose").set_audio(
                        audio
                    )

                    temp_video = os.path.join(temp_dir, "video.mp4")
                    video.write_videofile(
                        temp_video,
                        fps=24,
                        codec="libx264",
                        audio_codec="aac",
                        verbose=False,
                        logger=None,
                    )

                    with open(temp_video, "rb") as f:
                        return f.read()
                finally:
                    if video:
                        try:
                            video.close()
                        except Exception:
                            pass
                    for clip in clips:
                        try:
                            clip.close()
                        except Exception:
                            pass
                    if audio:
                        try:
                            audio.close()
                        except Exception:
                            pass

            video_bytes = await asyncio.to_thread(_create_video)
            filename = f"{secrets.token_hex(16)}.mp4"

            if self.supabase_client:
                return self.supabase_client.upload_video(video_bytes, filename)

            # Fallback: save locally
            video_path = settings.video_dir / filename
            video_path.write_bytes(video_bytes)
            return str(video_path)

    async def _generate_audio_mp3(self, audio_url: str) -> str:
        """Convert audio to MP3 format."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download audio
            audio_file = await self._download_file(
                audio_url, os.path.join(temp_dir, "audio.wav")
            )

            # Convert to MP3
            def _convert_to_mp3() -> bytes:
                from moviepy.editor import AudioFileClip

                audio = None
                try:
                    audio = AudioFileClip(audio_file)
                    mp3_file = os.path.join(temp_dir, "audio.mp3")
                    audio.write_audiofile(mp3_file, verbose=False, logger=None)
                    with open(mp3_file, "rb") as f:
                        return f.read()
                finally:
                    if audio:
                        try:
                            audio.close()
                        except Exception:
                            pass

            mp3_bytes = await asyncio.to_thread(_convert_to_mp3)
            filename = f"{secrets.token_hex(16)}.mp3"

            if self.supabase_client:
                return self.supabase_client.upload_audio(mp3_bytes, filename)

            # Fallback: save locally
            audio_path = settings.audio_dir / filename
            audio_path.write_bytes(mp3_bytes)
            return str(audio_path)

    async def _generate_captions_srt(self, story_text: str, audio_url: str) -> str:
        """Generate SRT captions file from story text."""
        # Estimate timing: ~150 words per minute
        words = story_text.split()
        estimated_duration = len(words) / 150.0 * 60.0  # seconds

        # Split story into paragraphs for captions
        paragraphs = [p.strip() for p in story_text.split("\n\n") if p.strip()]
        if not paragraphs:
            paragraphs = [story_text]

        # Distribute paragraphs evenly across estimated duration
        duration_per_paragraph = estimated_duration / len(paragraphs)

        srt_lines = []
        start_time = 0.0

        for idx, paragraph in enumerate(paragraphs, 1):
            end_time = start_time + duration_per_paragraph

            # Format SRT timestamp (HH:MM:SS,mmm)
            start_str = self._format_srt_timestamp(start_time)
            end_str = self._format_srt_timestamp(end_time)

            srt_lines.append(f"{idx}")
            srt_lines.append(f"{start_str} --> {end_str}")
            srt_lines.append(paragraph)
            srt_lines.append("")  # Blank line between entries

            start_time = end_time

        srt_content = "\n".join(srt_lines)
        filename = f"{secrets.token_hex(16)}.srt"

        if self.supabase_client:
            # Upload as text file using upload_file
            file_path = f"captions/{filename}"
            self.supabase_client.upload_file(
                "captions",
                file_path,
                srt_content.encode("utf-8"),
                content_type="text/srt",
            )
            return self.supabase_client.get_signed_url("captions", file_path)

        # Fallback: save locally
        srt_path = settings.asset_dir / "captions" / filename
        srt_path.parent.mkdir(parents=True, exist_ok=True)
        srt_path.write_text(srt_content, encoding="utf-8")
        return str(srt_path)

    def _format_srt_timestamp(self, seconds: float) -> str:
        """Format seconds as SRT timestamp (HH:MM:SS,mmm)."""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"

    async def _generate_thumbnail(
        self,
        frame_url: Optional[str],
        theme: Optional[str] = None,
    ) -> str:
        """
        Generate branded thumbnail from first frame with Dream Flow branding.

        Args:
            frame_url: URL to first frame image
            theme: Story theme for text overlay
        """
        from PIL import ImageDraw, ImageFont

        # Thumbnail size (16:9 aspect ratio)
        thumbnail_width = 1280
        thumbnail_height = 720

        if not frame_url:
            # Create placeholder thumbnail with gradient background
            image = Image.new(
                "RGB", (thumbnail_width, thumbnail_height), color=(45, 45, 60)
            )
            # Create a simple gradient effect
            draw = ImageDraw.Draw(image)
            for y in range(thumbnail_height):
                # Gradient from dark purple to dark blue
                r = int(45 + (59 - 45) * (y / thumbnail_height))
                g = int(45 + (130 - 45) * (y / thumbnail_height))
                b = int(60 + (246 - 60) * (y / thumbnail_height))
                draw.line([(0, y), (thumbnail_width, y)], fill=(r, g, b))
        else:
            # Download and resize frame
            async with httpx.AsyncClient() as client:
                response = await client.get(frame_url)
                response.raise_for_status()
                image = Image.open(io.BytesIO(response.content))

        # Resize to thumbnail size maintaining aspect ratio, then crop to exact size
        image.thumbnail((thumbnail_width, thumbnail_height), Image.Resampling.LANCZOS)

        # Create new image with exact thumbnail size
        thumbnail = Image.new(
            "RGB", (thumbnail_width, thumbnail_height), color=(0, 0, 0)
        )

        # Center the image
        if image.width < thumbnail_width or image.height < thumbnail_height:
            # Image is smaller, center it
            x_offset = (thumbnail_width - image.width) // 2
            y_offset = (thumbnail_height - image.height) // 2
            thumbnail.paste(image, (x_offset, y_offset))
        else:
            # Image is larger or same size, crop to center
            x_offset = (image.width - thumbnail_width) // 2
            y_offset = (image.height - thumbnail_height) // 2
            thumbnail = image.crop(
                (
                    x_offset,
                    y_offset,
                    x_offset + thumbnail_width,
                    y_offset + thumbnail_height,
                )
            )

        # Add branding overlay
        draw = ImageDraw.Draw(thumbnail)

        # Try to load a font, fallback to default if not available
        try:
            font_medium = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 40
            )
            font_small = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 28
            )
        except (OSError, IOError):
            try:
                # Try alternative font paths
                font_medium = ImageFont.truetype(
                    "/System/Library/Fonts/Helvetica.ttc", 40
                )
                font_small = ImageFont.truetype(
                    "/System/Library/Fonts/Helvetica.ttc", 28
                )
            except (OSError, IOError):
                # Fallback to default font
                font_medium = ImageFont.load_default()
                font_small = ImageFont.load_default()

        # Add semi-transparent overlay at bottom for text readability
        overlay = Image.new("RGBA", (thumbnail_width, 200), (0, 0, 0, 180))
        thumbnail.paste(overlay, (0, thumbnail_height - 200), overlay)

        # Add "Dream Flow" brand text at bottom left
        brand_text = "Dream Flow"
        brand_bbox = draw.textbbox((0, 0), brand_text, font=font_medium)
        brand_width = brand_bbox[2] - brand_bbox[0]
        brand_height = brand_bbox[3] - brand_bbox[1]
        draw.text(
            (30, thumbnail_height - brand_height - 30),
            brand_text,
            fill=(255, 255, 255),
            font=font_medium,
        )

        # Add "AI" badge next to brand
        ai_text = "AI"
        ai_bbox = draw.textbbox((0, 0), ai_text, font=font_small)
        ai_width = ai_bbox[2] - ai_bbox[0]
        ai_height = ai_bbox[3] - ai_bbox[1]
        # Draw AI badge background (purple)
        ai_x = 30 + brand_width + 15
        ai_y = thumbnail_height - ai_height - 35
        draw.rectangle(
            [(ai_x - 10, ai_y - 5), (ai_x + ai_width + 10, ai_y + ai_height + 5)],
            fill=(139, 92, 246),  # Primary purple
        )
        draw.text(
            (ai_x, ai_y),
            ai_text,
            fill=(255, 255, 255),
            font=font_small,
        )

        # Add theme text at bottom right if provided
        if theme:
            theme_text = theme.title()
            # Truncate if too long
            if len(theme_text) > 20:
                theme_text = theme_text[:17] + "..."
            theme_bbox = draw.textbbox((0, 0), theme_text, font=font_medium)
            theme_width = theme_bbox[2] - theme_bbox[0]
            draw.text(
                (
                    thumbnail_width - theme_width - 30,
                    thumbnail_height - brand_height - 30,
                ),
                theme_text,
                fill=(255, 255, 255),
                font=font_medium,
            )

        # Add "Bedtime Story" subtitle
        subtitle_text = "Bedtime Story"
        subtitle_bbox = draw.textbbox((0, 0), subtitle_text, font=font_small)
        draw.text(
            (30, thumbnail_height - brand_height - subtitle_bbox[3] - 40),
            subtitle_text,
            fill=(200, 200, 200),
            font=font_small,
        )

        # Convert to bytes
        buffer = io.BytesIO()
        thumbnail.save(buffer, format="PNG", optimize=True)
        thumbnail_bytes = buffer.getvalue()

        filename = f"{secrets.token_hex(16)}.png"

        if self.supabase_client:
            return self.supabase_client.upload_frame(thumbnail_bytes, filename)

        # Fallback: save locally
        thumbnail_path = settings.frames_dir / filename
        thumbnail_path.write_bytes(thumbnail_bytes)
        return str(thumbnail_path)

    def _generate_metadata(
        self,
        story_text: str,
        theme: str,
        num_scenes: int,
        video_id: Optional[str] = None,
    ) -> dict[str, Any]:
        """Generate platform metadata."""
        from ..shared.config import get_settings

        settings = get_settings()
        word_count = len(story_text.split())
        estimated_duration = word_count / 150.0 * 60.0  # seconds

        return {
            "title": f"Dream Flow: {theme}",
            "description": story_text[:500] + ("..." if len(story_text) > 500 else ""),
            "tags": ["dreamflow", "bedtime story", "calm", "meditation", theme.lower()],
            "category": "Entertainment",
            "duration_seconds": int(estimated_duration),
            "num_scenes": num_scenes,
        }

    async def _download_file(self, url: str, dest_path: str) -> str:
        """Download file from URL to local path."""
        if url.startswith("http"):
            async with httpx.AsyncClient() as client:
                response = await client.get(url)
                response.raise_for_status()
                with open(dest_path, "wb") as f:
                    f.write(response.content)
        else:
            # Local file, copy it
            import shutil

            shutil.copy2(url, dest_path)
        return dest_path
