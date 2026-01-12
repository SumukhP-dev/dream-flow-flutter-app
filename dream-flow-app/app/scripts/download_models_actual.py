#!/usr/bin/env python3
"""
Actual model download script - attempts to download real models
For CPU-only devices, optimized for <30s generation time
"""

import os
import sys
import requests
from pathlib import Path
from urllib.parse import urlparse

def download_file(url: str, filepath: Path, description: str) -> bool:
    """Download a file with progress tracking"""
    try:
        print(f"\nDownloading {description}...")
        print(f"   URL: {url}")
        print(f"   Save to: {filepath}")
        
        # Check if file already exists
        if filepath.exists():
            size_mb = filepath.stat().st_size / (1024 * 1024)
            print(f"   Already exists ({size_mb:.1f} MB)")
            return True
        
        response = requests.get(url, stream=True, timeout=60, allow_redirects=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        print(f"\r   Progress: {percent:.1f}% ({downloaded/(1024*1024):.1f} MB)", end='', flush=True)
        
        print()  # New line after progress
        final_size = filepath.stat().st_size / (1024 * 1024)
        print(f"   Downloaded: {final_size:.1f} MB")
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"\n   Download failed: {e}")
        if filepath.exists():
            filepath.unlink()
        return False
    except Exception as e:
        print(f"\n   Error: {e}")
        if filepath.exists():
            filepath.unlink()
        return False

def main():
    platform = sys.argv[1] if len(sys.argv) > 1 else 'android'
    
    if platform not in ['android', 'ios']:
        print("Usage: python scripts/download_models_actual.py [android|ios]")
        sys.exit(1)
    
    print(f"Downloading models for {platform.upper()} platform")
    print("=" * 60)
    
    script_dir = Path(__file__).parent.parent
    models_dir = script_dir / 'models'
    models_dir.mkdir(exist_ok=True)
    
    success_count = 0
    total_count = 0
    
    if platform == 'android':
        # Story Model - Try multiple sources
        print("\n1. Story Generation Model (GPT-2 Tiny)")
        print("-" * 60)
        
        story_urls = [
            # Hugging Face direct download (may work if model exists)
            ('https://huggingface.co/kumarvikram/gpt2-tiny/resolve/main/model.tflite', 'gpt2_tiny.tflite'),
            # Alternative: Try TinyLlama (larger but may be available)
            ('https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf', 'tinyllama_q2.gguf'),
        ]
        
        story_downloaded = False
        for url, filename in story_urls:
            total_count += 1
            filepath = models_dir / filename
            if download_file(url, filepath, f"Story model ({filename})"):
                success_count += 1
                story_downloaded = True
                print(f"   Story model downloaded: {filename}")
                break
        
        if not story_downloaded:
            print("\n   WARNING: Story model not available at these URLs")
            print("   You can convert from Hugging Face using:")
            print("      python scripts/convert_story_to_tflite.py --model distilgpt2 --output models/gpt2_tiny.tflite --quantize")
            print("   See scripts/QUICK_START_CONVERSION.md for details")
            print("   Or use placeholder implementation (app works without it)")
        
        # Image Model - Large files, may not be directly downloadable
        print("\n2. Image Generation Model (Stable Diffusion)")
        print("-" * 60)
        print("   WARNING: Image models are large (800MB-1GB+) and require conversion")
        print("   Recommended approach:")
        print("      1. iOS: Use Apple's converter (see MODEL_CONVERSION_GUIDE.md)")
        print("      2. Android: Convert using TensorFlow Lite (see MODEL_CONVERSION_GUIDE.md)")
        print("      3. Or search Hugging Face: https://huggingface.co/models?search=stable-diffusion+tflite")
        print("   For testing, you can use the app without image models (uses placeholders)")
        
    else:  # iOS
        print("\n1. Story Generation Model (GPT-2 Tiny Core ML)")
        print("-" * 60)
        
        story_urls = [
            ('https://huggingface.co/kumarvikram/gpt2-tiny/resolve/main/model.mlmodel', 'gpt2_tiny.mlmodel'),
        ]
        
        story_downloaded = False
        for url, filename in story_urls:
            total_count += 1
            filepath = models_dir / filename
            if download_file(url, filepath, f"Story model ({filename})"):
                success_count += 1
                story_downloaded = True
                break
        
        if not story_downloaded:
            print("\n   WARNING: Story model not available at this URL")
            print("   You can convert from Hugging Face using:")
            print("      python scripts/convert_story_to_coreml.py --model distilgpt2 --output models/gpt2_tiny.mlmodel --quantize")
            print("   See scripts/QUICK_START_CONVERSION.md for details")
        
        print("\n2. Image Generation Model (Stable Diffusion Core ML)")
        print("-" * 60)
        print("   Use Apple's official converter:")
        print("      https://github.com/apple/ml-stable-diffusion")
        print("   For testing, you can use the app without image models")
    
    print("\n" + "=" * 60)
    print(f"Summary: {success_count}/{total_count} models downloaded")
    
    if success_count > 0:
        print(f"\nDownloaded models saved to: {models_dir}")
        print("\nNext steps:")
        print("   1. Copy models to app assets:")
        if platform == 'android':
            print(f"      cp models/*.tflite android/app/src/main/assets/models/")
        else:
            print(f"      cp models/*.mlmodel ios/Runner/Resources/Models/")
        print("   2. Or update model_config.dart with local file paths")
        print("   3. Test the app!")
    else:
        print("\nAlternative: The app works with placeholder implementations")
        print("   You can test everything except actual AI generation")
        print("   Models can be added later when available/converted")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nDownload cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)

