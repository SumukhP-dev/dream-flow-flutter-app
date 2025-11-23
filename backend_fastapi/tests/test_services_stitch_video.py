"""
Unit tests for stitch_video function.

Tests ensure:
- Video stitching works with URLs and local paths
- Supabase Storage upload works correctly
- Local fallback works when no Supabase client
- Error handling works correctly
"""

import asyncio
import io
import os
import tempfile
import pytest
from unittest.mock import MagicMock, patch, AsyncMock
from uuid import uuid4
from pathlib import Path

from PIL import Image
import httpx

from app.services import stitch_video
from app.config import Settings


class TestStitchVideo:
    """Tests for stitch_video function."""

    @pytest.mark.asyncio
    async def test_stitch_video_with_urls_and_supabase(self):
        """Test stitching video with URLs and uploading to Supabase."""
        # Create mock image and audio data
        image = Image.new("RGB", (1280, 720), color=(255, 0, 0))
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        image_bytes = buffer.getvalue()
        
        # Create minimal WAV file
        audio_bytes = b"RIFF" + b"\x00" * 36  # Minimal WAV header
        
        # Mock Supabase client
        mock_supabase = MagicMock()
        mock_supabase.upload_video.return_value = "https://supabase.co/storage/video/test.mp4"
        
        # Mock HTTP responses for downloading
        async def mock_get(url):
            mock_response = MagicMock()
            mock_response.status_code = 200
            if "frame" in url:
                mock_response.content = image_bytes
            elif "audio" in url:
                mock_response.content = audio_bytes
            mock_response.raise_for_status = MagicMock()
            return mock_response
        
        # Mock AudioFileClip to return a duration
        mock_audio = MagicMock()
        mock_audio.duration = 10.0  # 10 seconds
        mock_audio_file_clip = MagicMock(return_value=mock_audio)
        
        with patch('httpx.AsyncClient.get', side_effect=mock_get):
            with patch('app.services.AudioFileClip', mock_audio_file_clip):
                with patch('app.services.ImageClip') as mock_image_clip:
                    mock_clip = MagicMock()
                    mock_clip.set_duration.return_value = mock_clip
                    mock_clip.resize.return_value = mock_clip
                    mock_image_clip.return_value = mock_clip
                    
                    with patch('app.services.concatenate_videoclips') as mock_concat:
                        mock_video = MagicMock()
                        mock_video.set_audio.return_value = mock_video
                        # Mock write_videofile to create a file
                        def mock_write_videofile(path, **kwargs):
                            # Create the file
                            with open(path, "wb") as f:
                                f.write(b"fake_video_data")
                        mock_video.write_videofile = mock_write_videofile
                        mock_concat.return_value = mock_video
                        
                        frame_urls = [
                            "https://supabase.co/storage/frames/frame1.png",
                            "https://supabase.co/storage/frames/frame2.png",
                        ]
                        audio_url = "https://supabase.co/storage/audio/test.wav"
                        
                        result = await stitch_video(
                            frame_paths=frame_urls,
                            audio_path=audio_url,
                            supabase_client=mock_supabase
                        )
        
        assert result.startswith("https://")
        assert mock_supabase.upload_video.called

    @pytest.mark.asyncio
    async def test_stitch_video_with_local_paths(self):
        """Test stitching video with local file paths."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create test image files
            frame1_path = os.path.join(temp_dir, "frame1.png")
            frame2_path = os.path.join(temp_dir, "frame2.png")
            audio_path = os.path.join(temp_dir, "audio.wav")
            
            # Create valid image files
            image = Image.new("RGB", (1280, 720), color=(255, 0, 0))
            image.save(frame1_path)
            image.save(frame2_path)
            
            # Create audio file (minimal WAV header)
            with open(audio_path, "wb") as f:
                f.write(b"RIFF" + b"\x00" * 36)  # Minimal WAV header
            
            # Mock AudioFileClip and video processing
            mock_audio = MagicMock()
            mock_audio.duration = 10.0
            mock_audio_file_clip = MagicMock(return_value=mock_audio)
            
            with patch('app.services.AudioFileClip', mock_audio_file_clip):
                with patch('app.services.ImageClip') as mock_image_clip:
                    mock_clip = MagicMock()
                    mock_clip.set_duration.return_value = mock_clip
                    mock_clip.resize.return_value = mock_clip
                    mock_image_clip.return_value = mock_clip
                    
                    with patch('app.services.concatenate_videoclips') as mock_concat:
                        mock_video = MagicMock()
                        mock_video.set_audio.return_value = mock_video
                        mock_concat.return_value = mock_video
                        
                        # Mock settings for local fallback
                        with patch('app.services.settings') as mock_settings:
                            mock_settings.video_dir = Path(temp_dir)
                            
                            # Mock file write
                            with patch('builtins.open', create=True) as mock_open:
                                mock_file = MagicMock()
                                mock_file.read.return_value = b"fake_video_data"
                                mock_open.return_value.__enter__.return_value = mock_file
                                
                                result = await stitch_video(
                                    frame_paths=[frame1_path, frame2_path],
                                    audio_path=audio_path,
                                    supabase_client=None
                                )
            
            assert isinstance(result, str)
            assert not result.startswith("http")

    @pytest.mark.asyncio
    async def test_stitch_video_mixed_urls_and_paths(self):
        """Test stitching video with mix of URLs and local paths."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create local frame
            local_frame = os.path.join(temp_dir, "local_frame.png")
            image = Image.new("RGB", (1280, 720), color=(255, 0, 0))
            image.save(local_frame)
            
            # Mock URL frame
            image_bytes = io.BytesIO()
            image.save(image_bytes, format="PNG")
            
            async def mock_get(url):
                mock_response = MagicMock()
                mock_response.status_code = 200
                mock_response.content = image_bytes.getvalue()
                mock_response.raise_for_status = MagicMock()
                return mock_response
            
            audio_path = os.path.join(temp_dir, "audio.wav")
            with open(audio_path, "wb") as f:
                f.write(b"RIFF" + b"\x00" * 36)
            
            # Mock AudioFileClip and video processing
            mock_audio = MagicMock()
            mock_audio.duration = 10.0
            mock_audio_file_clip = MagicMock(return_value=mock_audio)
            
            with patch('httpx.AsyncClient.get', side_effect=mock_get):
                with patch('app.services.AudioFileClip', mock_audio_file_clip):
                    with patch('app.services.ImageClip') as mock_image_clip:
                        mock_clip = MagicMock()
                        mock_clip.set_duration.return_value = mock_clip
                        mock_clip.resize.return_value = mock_clip
                        mock_image_clip.return_value = mock_clip
                        
                        with patch('app.services.concatenate_videoclips') as mock_concat:
                            mock_video = MagicMock()
                            mock_video.set_audio.return_value = mock_video
                            mock_concat.return_value = mock_video
                            
                            with patch('app.services.settings') as mock_settings:
                                mock_settings.video_dir = Path(temp_dir)
                                
                                with patch('builtins.open', create=True) as mock_open:
                                    mock_file = MagicMock()
                                    mock_file.read.return_value = b"fake_video_data"
                                    mock_open.return_value.__enter__.return_value = mock_file
                                    
                                    result = await stitch_video(
                                        frame_paths=["https://test.com/frame.png", local_frame],
                                        audio_path=audio_path,
                                        supabase_client=None
                                    )
            
            assert isinstance(result, str)

    @pytest.mark.asyncio
    async def test_stitch_video_http_error(self):
        """Test stitching video handles HTTP errors when downloading."""
        mock_supabase = MagicMock()
        
        async def mock_get(url):
            mock_response = MagicMock()
            mock_response.status_code = 404
            mock_response.raise_for_status.side_effect = httpx.HTTPStatusError(
                "Not found", request=MagicMock(), response=mock_response
            )
            return mock_response
        
        with patch('httpx.AsyncClient.get', side_effect=mock_get):
            with pytest.raises(httpx.HTTPStatusError):
                await stitch_video(
                    frame_paths=["https://test.com/missing.png"],
                    audio_path="https://test.com/missing.wav",
                    supabase_client=mock_supabase
                )

    @pytest.mark.asyncio
    async def test_stitch_video_with_supabase_upload_error(self):
        """Test stitching video handles Supabase upload errors."""
        image = Image.new("RGB", (1280, 720), color=(255, 0, 0))
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        image_bytes = buffer.getvalue()
        
        audio_bytes = b"RIFF" + b"\x00" * 36  # Minimal WAV header
        
        mock_supabase = MagicMock()
        mock_supabase.upload_video.side_effect = Exception("Upload failed")
        
        async def mock_get(url):
            mock_response = MagicMock()
            mock_response.status_code = 200
            if "frame" in url:
                mock_response.content = image_bytes
            elif "audio" in url:
                mock_response.content = audio_bytes
            mock_response.raise_for_status = MagicMock()
            return mock_response
        
        # Mock AudioFileClip and video processing
        mock_audio = MagicMock()
        mock_audio.duration = 10.0
        mock_audio_file_clip = MagicMock(return_value=mock_audio)
        
        with patch('httpx.AsyncClient.get', side_effect=mock_get):
            with patch('app.services.AudioFileClip', mock_audio_file_clip):
                with patch('app.services.ImageClip') as mock_image_clip:
                    mock_clip = MagicMock()
                    mock_clip.set_duration.return_value = mock_clip
                    mock_clip.resize.return_value = mock_clip
                    mock_image_clip.return_value = mock_clip
                    
                    with patch('app.services.concatenate_videoclips') as mock_concat:
                        mock_video = MagicMock()
                        mock_video.set_audio.return_value = mock_video
                        mock_concat.return_value = mock_video
                        
                        with patch('builtins.open', create=True) as mock_open:
                            mock_file = MagicMock()
                            mock_file.read.return_value = b"fake_video_data"
                            mock_open.return_value.__enter__.return_value = mock_file
                            
                            with pytest.raises(Exception, match="Upload failed"):
                                await stitch_video(
                                    frame_paths=["https://test.com/frame.png"],
                                    audio_path="https://test.com/audio.wav",
                                    supabase_client=mock_supabase
                                )

