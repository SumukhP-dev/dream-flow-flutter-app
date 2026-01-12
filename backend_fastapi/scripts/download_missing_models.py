#!/usr/bin/env python3
"""
Download missing models for testing purposes.
Downloads the Q2_K phone-optimized model that's needed for ultra-fast phone generation.
"""

import os
import sys
from pathlib import Path

# Add parent directory to path so we can import app modules
sys.path.insert(0, str(Path(__file__).parent))

import requests

try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False

# Model download URLs
PHONE_TINYLLAMA_Q2_URL = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
PHONE_TINYLLAMA_Q2_FILENAME = "tinyllama-1.1b-chat-v1.0.Q2_K.gguf"

def download_file(url: str, filepath: Path, description: str) -> bool:
    """Download a file with progress bar."""
    if filepath.exists():
        size_mb = filepath.stat().st_size / (1024 * 1024)
        print(f"[OK] {description} already exists ({size_mb:.2f} MB)")
        return True
    
    print(f"[DOWNLOAD] Downloading {description}...")
    print(f"   URL: {url}")
    print(f"   Destination: {filepath}")
    
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        if HAS_TQDM and total_size > 0:
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
                        downloaded += len(chunk)
                        pbar.update(len(chunk))
        else:
            # Fallback to simple progress without tqdm
            with open(filepath, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\rDownloading: {percent:.1f}% ({downloaded / (1024*1024):.1f} MB / {total_size / (1024*1024):.1f} MB)", end="", flush=True)
                if total_size > 0:
                    print()  # New line after progress
        
        size_mb = filepath.stat().st_size / (1024 * 1024)
        print(f"[OK] {description} downloaded successfully ({size_mb:.2f} MB)")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to download {description}: {e}")
        if filepath.exists():
            filepath.unlink()  # Remove partial download
        return False

def main():
    """Download all missing models."""
    print("=" * 60)
    print("Model Download Script")
    print("=" * 60)
    print()
    
    # Get models directory
    project_root = Path(__file__).parent
    models_dir = project_root / "models"
    models_dir.mkdir(exist_ok=True)
    
    print(f"Models directory: {models_dir}")
    print()
    
    # List of models to download
    models_to_download = [
        {
            "url": PHONE_TINYLLAMA_Q2_URL,
            "filename": PHONE_TINYLLAMA_Q2_FILENAME,
            "description": "TinyLlama Q2_K (Phone Optimized) - Ultra-fast phone generation",
        },
    ]
    
    print("Checking existing models...")
    print()
    
    # Check what's already there
    existing_models = list(models_dir.glob("*.gguf"))
    if existing_models:
        print("Existing models:")
        for model in existing_models:
            size_mb = model.stat().st_size / (1024 * 1024)
            print(f"  [OK] {model.name} ({size_mb:.2f} MB)")
        print()
    
    # Download missing models
    success_count = 0
    for model_info in models_to_download:
        model_path = models_dir / model_info["filename"]
        
        if download_file(
            model_info["url"],
            model_path,
            model_info["description"]
        ):
            success_count += 1
        print()
    
    print("=" * 60)
    if success_count == len(models_to_download):
        print("[SUCCESS] All models downloaded successfully!")
    else:
        print(f"[WARNING] {success_count}/{len(models_to_download)} models downloaded")
    print("=" * 60)
    
    # Show final status
    print()
    print("Final model status:")
    all_models = sorted(models_dir.glob("*.gguf"))
    total_size = 0
    for model in all_models:
        size_mb = model.stat().st_size / (1024 * 1024)
        total_size += size_mb
        print(f"  [OK] {model.name} ({size_mb:.2f} MB)")
    
    if all_models:
        print(f"\nTotal: {len(all_models)} models, {total_size:.2f} MB")
    
    return 0 if success_count == len(models_to_download) else 1

if __name__ == "__main__":
    sys.exit(main())


