#!/usr/bin/env python3
"""
Performance monitoring script for video generation.

This script monitors video generation performance metrics.
"""

import asyncio
import sys
import time
import psutil
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.local_services import _get_optimized_video_settings, _detect_device
from app.shared.config import get_settings


def monitor_system_resources():
    """Monitor current system resources."""
    process = psutil.Process()
    memory_info = process.memory_info()
    
    system_memory = psutil.virtual_memory()
    
    print("=" * 60)
    print("System Resource Monitor")
    print("=" * 60)
    print(f"Process Memory: {memory_info.rss / 1024 / 1024:.2f} MB")
    print(f"System Memory: {system_memory.total / 1024 / 1024 / 1024:.2f} GB")
    print(f"Available Memory: {system_memory.available / 1024 / 1024 / 1024:.2f} GB")
    print(f"Memory Usage: {system_memory.percent:.1f}%")
    print(f"CPU Count: {psutil.cpu_count()}")
    print(f"CPU Usage: {psutil.cpu_percent(interval=1):.1f}%")
    print("=" * 60)


def test_video_settings():
    """Test video quality settings."""
    print("\nVideo Quality Settings:")
    print("-" * 60)
    
    settings = get_settings()
    print(f"Quality Preset: {settings.local_video_quality}")
    print(f"Timeout (fast): {settings.local_video_timeout_fast}s")
    print(f"Timeout (balanced): {settings.local_video_timeout_balanced}s")
    print(f"Timeout (high): {settings.local_video_timeout_high}s")
    print(f"Max Retries: {settings.local_video_max_retries}")
    print(f"Retry Delay: {settings.local_video_retry_delay}s")
    
    video_settings = _get_optimized_video_settings()
    print(f"\nCurrent Settings:")
    print(f"  Frames: {video_settings['frames']}")
    print(f"  Steps: {video_settings['steps']}")
    print(f"  Resolution: {video_settings['resolution']}")
    print(f"  FPS: {video_settings['fps']}")
    
    # Estimate generation time
    estimated_time = (video_settings['steps'] * video_settings['frames']) / 10  # Rough estimate
    print(f"\nEstimated Generation Time: {estimated_time:.1f} seconds")
    print("-" * 60)


def test_device_detection():
    """Test device detection."""
    print("\nDevice Detection:")
    print("-" * 60)
    
    try:
        device, dtype = _detect_device()
        print(f"Device: {device}")
        print(f"Data Type: {dtype}")
        
        if device == "cuda":
            try:
                import torch
                print(f"GPU: {torch.cuda.get_device_name(0)}")
                print(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
            except Exception as e:
                print(f"GPU info error: {e}")
        else:
            print("Using CPU (GPU not available)")
            
    except Exception as e:
        print(f"Device detection error: {e}")
    
    print("-" * 60)


def test_dependencies():
    """Test if all dependencies are available."""
    print("\nDependency Check:")
    print("-" * 60)
    
    dependencies = {
        "torch": "PyTorch",
        "diffusers": "Diffusers",
        "transformers": "Transformers",
        "accelerate": "Accelerate",
        "imageio": "ImageIO",
        "imageio_ffmpeg": "ImageIO-FFmpeg",
    }
    
    for module, name in dependencies.items():
        try:
            mod = __import__(module)
            version = getattr(mod, "__version__", "unknown")
            print(f"✓ {name}: {version}")
        except ImportError:
            print(f"✗ {name}: Not installed")
        except Exception as e:
            print(f"✗ {name}: Error - {e}")
    
    print("-" * 60)


def estimate_memory_requirements():
    """Estimate memory requirements for video generation."""
    print("\nMemory Requirements Estimate:")
    print("-" * 60)
    
    settings = get_settings()
    video_settings = _get_optimized_video_settings()
    
    # Rough estimates based on model size and settings
    base_model_size = 2.7  # GB (Stable Diffusion 1.5 + AnimateDiff adapter)
    resolution_factor = (video_settings['resolution'][0] * video_settings['resolution'][1]) / (512 * 512)
    frames_factor = video_settings['frames'] / 16
    
    estimated_memory = base_model_size * resolution_factor * frames_factor
    
    print(f"Base Model Size: ~{base_model_size} GB")
    print(f"Resolution: {video_settings['resolution']}")
    print(f"Frames: {video_settings['frames']}")
    print(f"Estimated Peak Memory: ~{estimated_memory:.2f} GB")
    print(f"Recommended Available: ~{estimated_memory * 1.5:.2f} GB")
    
    system_memory = psutil.virtual_memory()
    available_gb = system_memory.available / 1024 / 1024 / 1024
    
    if available_gb < estimated_memory:
        print(f"\n⚠ Warning: Available memory ({available_gb:.2f} GB) may be insufficient")
        print("  Consider reducing resolution or frames")
    else:
        print(f"\n✓ Available memory ({available_gb:.2f} GB) should be sufficient")
    
    print("-" * 60)


if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("Video Generation Performance Monitor")
    print("=" * 60 + "\n")
    
    monitor_system_resources()
    test_dependencies()
    test_device_detection()
    test_video_settings()
    estimate_memory_requirements()
    
    print("\n" + "=" * 60)
    print("Monitoring Complete")
    print("=" * 60 + "\n")



