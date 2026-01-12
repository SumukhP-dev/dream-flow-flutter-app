#!/usr/bin/env python3
"""
Convert image generation models (Stable Diffusion) to Core ML format for iOS.

Uses Apple's official Stable Diffusion converter for best results.

Usage:
    python convert_image_to_coreml.py --model-id runwayml/stable-diffusion-v1-5 --output models/
"""

import argparse
import os
import sys
import subprocess
from pathlib import Path

def check_dependencies():
    """Check if required dependencies are installed."""
    try:
        import coremltools
        import diffusers
        import torch
    except ImportError as e:
        print(f"Error: Missing required dependencies. Install with:")
        print(f"  pip install -r requirements_conversion.txt")
        print(f"\nMissing: {e}")
        return False
    return True

def convert_with_apple_converter(
    model_id: str,
    output_dir: Path,
    compute_unit: str = "all",
    attention_implementation: str = "ORIGINAL",
):
    """
    Convert Stable Diffusion using Apple's official converter.
    
    This is a wrapper that uses Apple's ml-stable-diffusion repository.
    For best results, use Apple's converter directly.
    """
    print("Stable Diffusion to Core ML Converter")
    print("=" * 60)
    print(f"Model: {model_id}")
    print(f"Output: {output_dir}")
    print()
    
    print("⚠️  Apple's Stable Diffusion converter is complex and requires:")
    print("   1. Cloning Apple's ml-stable-diffusion repository")
    print("   2. Following their detailed conversion process")
    print("   3. Converting multiple components (text encoder, UNet, VAE)")
    print()
    print("Recommended approach:")
    print("   1. Visit: https://github.com/apple/ml-stable-diffusion")
    print("   2. Follow the conversion guide there")
    print("   3. Convert model using their provided scripts")
    print()
    
    # Check if Apple's converter is available
    converter_path = Path.home() / "ml-stable-diffusion"
    if converter_path.exists():
        print(f"Found ml-stable-diffusion at: {converter_path}")
        print("You can use their conversion scripts directly.")
    else:
        print("To use Apple's converter:")
        print("  git clone https://github.com/apple/ml-stable-diffusion.git")
        print("  cd ml-stable-diffusion")
        print("  python -m python_coreml_stable_diffusion.pipeline --convert -i <model-id> -o <output-dir>")
    
    print("\n" + "=" * 60)
    print("Alternative: Use pre-converted models from Hugging Face")
    print("Search for: 'stable-diffusion coreml' on Hugging Face")
    
    return False

def convert_simple_diffusion(
    model_id: str,
    output_dir: Path,
):
    """
    Simple conversion attempt (may not work for all models).
    """
    if not check_dependencies():
        return False
    
    try:
        from diffusers import StableDiffusionPipeline
        import coremltools as ct
        import torch
        
        print(f"Loading model: {model_id}")
        pipeline = StableDiffusionPipeline.from_pretrained(model_id)
        pipeline.to("cpu")  # Convert to CPU for mobile
        
        # Note: Full Stable Diffusion conversion is complex
        # This is a placeholder showing the approach
        print("⚠️  Full Stable Diffusion conversion requires converting:")
        print("   - Text Encoder")
        print("   - UNet (diffusion model)")
        print("   - VAE Decoder")
        print("   - VAE Encoder (optional)")
        print()
        print("For production use, use Apple's official converter.")
        
        return False
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description="Convert image generation models to Core ML format"
    )
    parser.add_argument(
        "--model-id",
        type=str,
        default="runwayml/stable-diffusion-v1-5",
        help="Hugging Face model ID",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="models/stable_diffusion",
        help="Output directory for Core ML models",
    )
    parser.add_argument(
        "--compute-unit",
        type=str,
        default="all",
        choices=["all", "cpuAndNeuralEngine", "cpuAndGPU", "cpuOnly"],
        help="Compute unit for Core ML",
    )
    
    args = parser.parse_args()
    
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("\n" + "=" * 60)
    print("Image Model Conversion Guide")
    print("=" * 60)
    print()
    print("Stable Diffusion conversion is complex and best done with Apple's")
    print("official tools. See detailed guide in MODEL_CONVERSION_GUIDE.md")
    print()
    
    # Try simple conversion (will likely redirect to Apple's converter)
    success = convert_with_apple_converter(
        model_id=args.model_id,
        output_dir=output_dir,
        compute_unit=args.compute_unit,
    )
    
    if not success:
        print("\n" + "=" * 60)
        print("Please use Apple's official converter for best results:")
        print("https://github.com/apple/ml-stable-diffusion")
        sys.exit(1)

if __name__ == "__main__":
    main()

