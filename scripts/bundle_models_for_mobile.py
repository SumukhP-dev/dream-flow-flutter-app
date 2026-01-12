#!/usr/bin/env python3
"""
Copy GGUF models to mobile app bundle directories for bundling.
These models will be used by the bundled FastAPI backend running on the device.
"""

import os
import shutil
import sys
from pathlib import Path

def copy_model_to_android(source: Path, dest_dir: Path) -> bool:
    """Copy model to Android assets directory."""
    try:
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_file = dest_dir / source.name
        print(f"  Copying to Android: {dest_file}")
        shutil.copy2(source, dest_file)
        size_mb = dest_file.stat().st_size / (1024 * 1024)
        print(f"    [OK] {source.name} ({size_mb:.2f} MB)")
        return True
    except Exception as e:
        print(f"    [ERROR] Failed to copy to Android: {e}")
        return False

def copy_model_to_ios(source: Path, dest_dir: Path) -> bool:
    """Copy model to iOS Resources directory."""
    try:
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_file = dest_dir / source.name
        print(f"  Copying to iOS: {dest_file}")
        shutil.copy2(source, dest_file)
        size_mb = dest_file.stat().st_size / (1024 * 1024)
        print(f"    [OK] {source.name} ({size_mb:.2f} MB)")
        return True
    except Exception as e:
        print(f"    [ERROR] Failed to copy to iOS: {e}")
        return False

def main():
    """Copy GGUF models to mobile app directories."""
    print("=" * 70)
    print("Bundle GGUF Models for Mobile App")
    print("=" * 70)
    print()
    
    # Get paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    backend_models_dir = script_dir / "models"
    
    android_models_dir = project_root / "dream-flow-app" / "app" / "android" / "app" / "src" / "main" / "assets" / "models"
    ios_models_dir = project_root / "dream-flow-app" / "app" / "ios" / "Runner" / "Resources" / "Models"
    
    print(f"Source models directory: {backend_models_dir}")
    print(f"Android destination: {android_models_dir}")
    print(f"iOS destination: {ios_models_dir}")
    print()
    
    # Check if source directory exists
    if not backend_models_dir.exists():
        print(f"[ERROR] Source models directory not found: {backend_models_dir}")
        return 1
    
    # Find all GGUF models
    gguf_models = list(backend_models_dir.glob("*.gguf"))
    
    if not gguf_models:
        print("[ERROR] No GGUF models found in source directory")
        return 1
    
    print(f"Found {len(gguf_models)} GGUF model(s):")
    for model in gguf_models:
        size_mb = model.stat().st_size / (1024 * 1024)
        print(f"  - {model.name} ({size_mb:.2f} MB)")
    print()
    
    # Copy models
    print("Copying models to mobile app directories...")
    print()
    
    android_success = 0
    ios_success = 0
    
    for model in gguf_models:
        print(f"Processing: {model.name}")
        
        # Copy to Android
        if copy_model_to_android(model, android_models_dir):
            android_success += 1
        
        # Copy to iOS
        if copy_model_to_ios(model, ios_models_dir):
            ios_success += 1
        
        print()
    
    # Summary
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print(f"Android: {android_success}/{len(gguf_models)} models copied")
    print(f"iOS: {ios_success}/{len(gguf_models)} models copied")
    
    if android_success == len(gguf_models) and ios_success == len(gguf_models):
        print()
        print("[SUCCESS] All models bundled successfully!")
        print()
        print("Next steps:")
        print("1. Ensure your bundled FastAPI backend can access these models")
        print("2. Update model paths in backend configuration for mobile")
        print("3. Build the mobile app with the bundled models")
        return 0
    else:
        print()
        print("[WARNING] Some models failed to copy")
        return 1

if __name__ == "__main__":
    sys.exit(main())

