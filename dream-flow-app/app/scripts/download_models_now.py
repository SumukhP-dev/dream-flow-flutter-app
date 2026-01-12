#!/usr/bin/env python3
"""
Download ML models for on-device inference
Optimized for CPU-only devices, <30 second generation time
"""

import os
import sys
import requests
from pathlib import Path
from tqdm import tqdm

# Model URLs - Using actual available models
MODEL_URLS = {
    'android': {
        'story': {
            'url': 'https://huggingface.co/kumarvikram/gpt2-tiny/resolve/main/model.tflite',
            'filename': 'gpt2_tiny.tflite',
            'description': 'GPT-2 Tiny (Android TFLite)',
            'size_mb': 30,
        },
        # Alternative: TinyLlama if GPT-2 Tiny not available
        'story_alt': {
            'url': 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
            'filename': 'tinyllama_q4.tflite',  # Note: This is GGUF, needs conversion
            'description': 'TinyLlama Q4 (needs conversion to TFLite)',
            'size_mb': 650,
        },
    },
    'ios': {
        'story': {
            'url': 'https://huggingface.co/kumarvikram/gpt2-tiny/resolve/main/model.mlmodel',
            'filename': 'gpt2_tiny.mlmodel',
            'description': 'GPT-2 Tiny (iOS Core ML)',
            'size_mb': 30,
        },
    },
}

# Image models - Stable Diffusion (large files, may need alternative approach)
IMAGE_MODEL_BASE = 'https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main'

def download_file(url: str, filepath: Path, description: str) -> bool:
    """Download a file with progress bar"""
    try:
        print(f"\n📥 Downloading {description}...")
        print(f"   URL: {url}")
        print(f"   Save to: {filepath}")
        
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        with open(filepath, 'wb') as f, tqdm(
            desc=description,
            total=total_size,
            unit='B',
            unit_scale=True,
            unit_divisor=1024,
        ) as pbar:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    pbar.update(len(chunk))
        
        print(f"✅ Downloaded: {filepath.name} ({filepath.stat().st_size / (1024*1024):.1f} MB)")
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Error downloading {description}: {e}")
        if filepath.exists():
            filepath.unlink()
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        if filepath.exists():
            filepath.unlink()
        return False

def main():
    platform = sys.argv[1] if len(sys.argv) > 1 else 'android'
    
    if platform not in ['android', 'ios']:
        print("Usage: python download_models_now.py [android|ios]")
        sys.exit(1)
    
    print(f"🚀 Downloading models for {platform.upper()} platform")
    print("=" * 60)
    
    # Create models directory
    script_dir = Path(__file__).parent.parent
    models_dir = script_dir / 'models'
    models_dir.mkdir(exist_ok=True)
    
    success_count = 0
    total_count = 0
    
    # Download story model
    if platform in MODEL_URLS:
        story_config = MODEL_URLS[platform].get('story')
        if story_config:
            total_count += 1
            filepath = models_dir / story_config['filename']
            
            # Check if already exists
            if filepath.exists():
                size_mb = filepath.stat().st_size / (1024 * 1024)
                print(f"\n⏭️  {story_config['filename']} already exists ({size_mb:.1f} MB)")
                print(f"   Delete it to re-download")
                success_count += 1
            else:
                if download_file(
                    story_config['url'],
                    filepath,
                    story_config['description']
                ):
                    success_count += 1
    
    print("\n" + "=" * 60)
    print(f"📊 Download Summary: {success_count}/{total_count} successful")
    
    if success_count < total_count:
        print("\n⚠️  Some models failed to download.")
        print("\n💡 Alternative Options:")
        print("1. Convert models yourself (see scripts/download_models.md)")
        print("2. Use placeholder implementations (app works without models)")
        print("3. Search Hugging Face for pre-converted models:")
        print("   - https://huggingface.co/models?search=gpt2+tflite")
        print("   - https://huggingface.co/models?search=stable-diffusion+tflite")
        print("\n📝 Note: Image models are large (1GB+) and may need manual setup")
    else:
        print("\n✅ All available models downloaded successfully!")
        print(f"   Location: {models_dir}")
        print("\n📋 Next steps:")
        print("1. Copy models to app assets:")
        if platform == 'android':
            print(f"   cp models/*.tflite android/app/src/main/assets/models/")
        else:
            print(f"   cp models/*.mlmodel ios/Runner/Resources/Models/")
        print("2. Update model_config.dart URLs if using remote models")
        print("3. Test the app!")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n❌ Download cancelled by user")
        sys.exit(1)

