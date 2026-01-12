#!/usr/bin/env python3
"""
Convert PyTorch models to Core ML format for iOS.

This script converts original model formats (NOT GGUF) to Core ML for use
with Neural Engine acceleration on Apple devices (A12 Bionic and later).

Usage:
    python convert_to_coreml.py --model-id distilgpt2 --output models/story_model.mlmodel
    python convert_to_coreml.py --model-id runwayml/stable-diffusion-v1-5 --output models/image_model.mlpackage
"""

import argparse
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

def convert_hf_to_coreml(model_id: str, output_path: str, quantize: bool = True):
    """
    Convert HuggingFace model to Core ML format.
    
    Args:
        model_id: HuggingFace model ID (e.g., 'distilgpt2')
        output_path: Output path for .mlmodel or .mlpackage file
        quantize: Whether to quantize the model (reduces size, may reduce accuracy)
    """
    try:
        import coremltools as ct
        from transformers import AutoModelForCausalLM, AutoTokenizer
        import torch
    except ImportError as e:
        print(f"Error: Required packages not installed. Install with:")
        print(f"  pip install coremltools transformers torch")
        print(f"Note: coremltools requires macOS for full functionality")
        sys.exit(1)
    
    print(f"Converting {model_id} to Core ML format...")
    print(f"Output: {output_path}")
    
    try:
        # Load model and tokenizer
        print("Loading model from HuggingFace...")
        tokenizer = AutoTokenizer.from_pretrained(model_id)
        model = AutoModelForCausalLM.from_pretrained(model_id)
        model.eval()
        
        # Convert to Core ML
        # Note: This is a simplified example. Full conversion requires:
        # 1. Trace the model with example inputs
        # 2. Convert traced model to Core ML
        # 3. Add metadata and optimize for Neural Engine
        
        print("Tracing model...")
        # Example input for tracing
        example_input = tokenizer("Hello", return_tensors="pt")
        input_ids = example_input["input_ids"]
        
        # Trace the model
        traced_model = torch.jit.trace(model, input_ids)
        
        print("Converting to Core ML...")
        # Convert to Core ML
        mlmodel = ct.convert(
            traced_model,
            inputs=[ct.TensorType(name="input_ids", shape=input_ids.shape)],
            outputs=[ct.TensorType(name="logits")],
            compute_units=ct.ComputeUnit.ALL,  # Use Neural Engine, GPU, and CPU
        )
        
        # Add metadata
        mlmodel.author = "Dream Flow"
        mlmodel.short_description = f"Core ML model converted from {model_id}"
        mlmodel.version = "1.0"
        
        # Quantize if requested
        if quantize:
            print("Quantizing model...")
            from coremltools.optimize.coreml import (
                OpLinearQuantizationConfig,
                OptimizationConfig,
                quantize_weights,
            )
            
            op_config = OpLinearQuantizationConfig(
                mode="linear_symmetric",
                weight_threshold=512,
            )
            config = OptimizationConfig(global_config=op_config)
            mlmodel = quantize_weights(mlmodel, config)
        
        # Save model
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        mlmodel.save(str(output_file))
        
        print(f"✅ Core ML model saved to: {output_path}")
        print(f"   Model size: {output_file.stat().st_size / (1024 * 1024):.2f} MB")
        
    except Exception as e:
        print(f"Error during conversion: {e}")
        print("")
        print("Note: Core ML conversion requires:")
        print("  1. macOS (for coremltools)")
        print("  2. PyTorch model in traceable format")
        print("  3. Proper input/output shapes")
        print("")
        print("For Stable Diffusion, use:")
        print("  python -m python_coreml_stable_diffusion.pipeline --convert -i <model-id> -o <output-dir>")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Convert models to Core ML format")
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
        help="Output path for .mlmodel or .mlpackage file"
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
    
    # Ensure output path has correct extension
    output_path = Path(args.output)
    if output_path.suffix not in ['.mlmodel', '.mlpackage']:
        output_path = output_path.with_suffix('.mlmodel')
    
    convert_hf_to_coreml(
        model_id=args.model_id,
        output_path=str(output_path),
        quantize=args.quantize
    )
    
    # Copy to iOS Resources directory if specified
    project_root = Path(__file__).parent.parent.parent
    ios_models_dir = project_root / "dream-flow-app" / "app" / "ios" / "Runner" / "Resources" / "Models"
    
    if ios_models_dir.exists():
        import shutil
        ios_models_dir.mkdir(parents=True, exist_ok=True)
        dest_file = ios_models_dir / output_path.name
        if Path(args.output).exists():
            shutil.copy2(output_path, dest_file)
            print(f"Copied to iOS Resources: {dest_file}")
        else:
            print(f"Note: Model file not found, skipping iOS Resources copy")


if __name__ == "__main__":
    main()

