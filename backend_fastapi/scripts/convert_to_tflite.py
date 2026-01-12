#!/usr/bin/env python3
"""
Convert PyTorch/TensorFlow models to TensorFlow Lite format for Android.

This script converts original model formats (NOT GGUF) to TFLite for use
with Tensor chip acceleration on Pixel devices and NPU/GPU on other Android devices.

Usage:
    python convert_to_tflite.py --model-id distilgpt2 --output models/story_model.tflite
    python convert_to_tflite.py --model-id runwayml/stable-diffusion-v1-5 --output models/image_model.tflite
"""

import argparse
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

def convert_hf_to_tflite(model_id: str, output_path: str, quantize: bool = True):
    """
    Convert HuggingFace model to TFLite format.
    
    Args:
        model_id: HuggingFace model ID (e.g., 'distilgpt2')
        output_path: Output path for .tflite file
        quantize: Whether to quantize the model (reduces size, may reduce accuracy)
    """
    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer
        import tensorflow as tf
        from tensorflow import lite as tflite
    except ImportError as e:
        print(f"Error: Required packages not installed. Install with:")
        print(f"  pip install transformers tensorflow")
        sys.exit(1)
    
    print(f"Converting {model_id} to TFLite format...")
    print(f"Output: {output_path}")
    
    try:
        # Load model and tokenizer
        print("Loading model from HuggingFace...")
        tokenizer = AutoTokenizer.from_pretrained(model_id)
        model = AutoModelForCausalLM.from_pretrained(model_id)
        
        # Convert PyTorch model to TensorFlow
        # Note: This is a simplified example. Full conversion may require:
        # 1. Export to ONNX first
        # 2. Convert ONNX to TensorFlow
        # 3. Convert TensorFlow to TFLite
        
        print("Note: Full TFLite conversion requires ONNX intermediate format.")
        print("For production, use:")
        print("  1. Export PyTorch model to ONNX")
        print("  2. Convert ONNX to TensorFlow SavedModel")
        print("  3. Convert SavedModel to TFLite")
        print("")
        print("See: https://www.tensorflow.org/lite/models/convert")
        
        # Placeholder: In production, implement full conversion pipeline
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Create a placeholder file to indicate conversion script is ready
        with open(output_file, 'w') as f:
            f.write(f"# TFLite conversion placeholder for {model_id}\n")
            f.write("# Full conversion requires ONNX intermediate step\n")
            f.write("# See conversion guide for complete implementation\n")
        
        print(f"Placeholder file created at: {output_path}")
        print("")
        print("To complete conversion:")
        print("1. Install: pip install onnx onnx-tf tensorflow")
        print("2. Export model to ONNX")
        print("3. Convert ONNX to TensorFlow")
        print("4. Convert TensorFlow to TFLite with quantization")
        
    except Exception as e:
        print(f"Error during conversion: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Convert models to TFLite format")
    parser.add_argument(
        "--model-id",
        type=str,
        required=True,
        help="HuggingFace model ID (e.g., 'distilgpt2')"
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        help="Output path for .tflite file"
    )
    parser.add_argument(
        "--quantize",
        action="store_true",
        default=True,
        help="Quantize model (reduces size, may reduce accuracy)"
    )
    parser.add_argument(
        "--no-quantize",
        dest="quantize",
        action="store_false",
        help="Don't quantize model"
    )
    
    args = parser.parse_args()
    
    # Ensure output path has .tflite extension
    output_path = Path(args.output)
    if output_path.suffix != '.tflite':
        output_path = output_path.with_suffix('.tflite')
    
    convert_hf_to_tflite(
        model_id=args.model_id,
        output_path=str(output_path),
        quantize=args.quantize
    )
    
    # Copy to Android assets directory if specified
    project_root = Path(__file__).parent.parent.parent
    android_models_dir = project_root / "dream-flow-app" / "app" / "android" / "app" / "src" / "main" / "assets" / "models"
    
    if android_models_dir.exists():
        import shutil
        android_models_dir.mkdir(parents=True, exist_ok=True)
        dest_file = android_models_dir / output_path.name
        if Path(args.output).exists():
            shutil.copy2(output_path, dest_file)
            print(f"Copied to Android assets: {dest_file}")
        else:
            print(f"Note: Model file not found, skipping Android assets copy")


if __name__ == "__main__":
    main()

