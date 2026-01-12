#!/usr/bin/env python3
"""
Convert story generation models to Core ML format for iOS.

Supports converting from:
- Hugging Face transformers (GPT-2, DistilGPT-2, etc.)
- PyTorch models
- ONNX models

Usage:
    python convert_story_to_coreml.py --model gpt2 --output gpt2_tiny.mlmodel --quantize
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import coremltools as ct
    from transformers import AutoTokenizer, AutoModelForCausalLM
    import torch
    import numpy as np
except ImportError as e:
    print(f"Error: Missing required dependencies. Install with:")
    print(f"  pip install -r requirements_conversion.txt")
    print(f"\nMissing: {e}")
    sys.exit(1)


def convert_hf_to_coreml(
    model_name: str,
    output_path: Path,
    quantize: bool = True,
    max_seq_length: int = 128,
    target_size_mb: int = 50,
):
    """
    Convert a Hugging Face model to Core ML format.
    
    Args:
        model_name: Hugging Face model name (e.g., 'gpt2', 'distilgpt2')
        output_path: Path to save the Core ML model
        quantize: Whether to quantize (reduces size)
        max_seq_length: Maximum sequence length for the model
        target_size_mb: Target size in MB (for guidance)
    """
    print(f"Loading model: {model_name}")
    print("=" * 60)
    
    # Load tokenizer and model
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForCausalLM.from_pretrained(model_name)
        model.eval()  # Set to evaluation mode
    except Exception as e:
        print(f"Error loading model: {e}")
        return False
    
    # Set padding token if not set
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    print(f"Model loaded successfully")
    print(f"Vocabulary size: {len(tokenizer)}")
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")
    
    # Create example input
    print("\nCreating example input...")
    sample_text = "Once upon a time"
    sample_inputs = tokenizer(
        sample_text,
        return_tensors="pt",
        padding="max_length",
        max_length=max_seq_length,
        truncation=True,
    )
    
    input_ids = sample_inputs["input_ids"]
    
    # Trace the model
    print("Tracing model...")
    try:
        traced_model = torch.jit.trace(model, input_ids)
    except Exception as e:
        print(f"Tracing failed: {e}")
        print("Trying with torch.jit.script instead...")
        try:
            traced_model = torch.jit.script(model)
        except Exception as e2:
            print(f"Scripting also failed: {e2}")
            print("\nTroubleshooting:")
            print("1. Try a different model")
            print("2. Reduce max_seq_length")
            return False
    
    # Convert to Core ML
    print("\nConverting to Core ML...")
    print("=" * 60)
    
    # Define input spec
    input_shape = (1, max_seq_length)  # (batch_size, sequence_length)
    input_spec = ct.TensorType(
        name="input_ids",
        shape=input_shape,
        dtype=np.int32,
    )
    
    try:
        # Convert to Core ML
        mlmodel = ct.convert(
            traced_model,
            inputs=[input_spec],
            outputs=[ct.TensorType(name="logits")],
            compute_units=ct.ComputeUnit.ALL,  # Use all available compute units
            minimum_deployment_target=ct.target.iOS15,  # iOS 15+
        )
        
        # Apply quantization if requested
        if quantize:
            print("Applying quantization...")
            # Use linear 16-bit quantization (good balance of size/quality)
            from coremltools.optimize.coreml import (
                palettize_weights,
                LinearQuantizer,
                QuantizationMode,
            )
            
            # Quantize weights to 8-bit
            quantizer = LinearQuantizer(
                mode=QuantizationMode.LINEAR_SYMMETRIC,
                weight_threshold=512,  # Quantize weights larger than 512 elements
            )
            mlmodel = quantizer.compress(mlmodel)
        
        # Add metadata
        mlmodel.author = "Dream Flow"
        mlmodel.short_description = f"Story generation model: {model_name}"
        mlmodel.version = "1.0"
        
        # Save model
        output_path.parent.mkdir(parents=True, exist_ok=True)
        mlmodel.save(str(output_path))
        
        size_mb = output_path.stat().st_size / (1024 * 1024)
        print(f"\n✓ Conversion successful!")
        print(f"  Output: {output_path}")
        print(f"  Size: {size_mb:.2f} MB")
        
        if size_mb > target_size_mb * 1.5:
            print(f"  ⚠️  Warning: Size ({size_mb:.2f} MB) exceeds target ({target_size_mb} MB)")
            print(f"     Consider using a smaller model or more aggressive quantization")
        
        # Print model info
        print("\nModel Info:")
        print(f"  Input: {input_shape}")
        print(f"  Minimum iOS version: iOS 15")
        print(f"  Compute units: All (CPU, Neural Engine, GPU)")
        
        return True
        
    except Exception as e:
        print(f"\n✗ Conversion failed: {e}")
        print("\nTroubleshooting:")
        print("1. Try without quantization: --no-quantize")
        print("2. Use a smaller model (e.g., 'distilgpt2' instead of 'gpt2')")
        print("3. Reduce max_seq_length")
        print("4. Ensure you have Xcode installed (for Core ML tools)")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Convert story generation models to Core ML format"
    )
    parser.add_argument(
        "--model",
        type=str,
        default="distilgpt2",
        help="Hugging Face model name (e.g., 'gpt2', 'distilgpt2')",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="models/gpt2_tiny.mlmodel",
        help="Output path for Core ML model",
    )
    parser.add_argument(
        "--quantize",
        action="store_true",
        default=True,
        help="Quantize model (default: True)",
    )
    parser.add_argument(
        "--no-quantize",
        dest="quantize",
        action="store_false",
        help="Disable quantization",
    )
    parser.add_argument(
        "--max-seq-length",
        type=int,
        default=128,
        help="Maximum sequence length (default: 128)",
    )
    parser.add_argument(
        "--target-size",
        type=int,
        default=50,
        help="Target size in MB (default: 50)",
    )
    
    args = parser.parse_args()
    
    output_path = Path(args.output)
    
    print("Story Model to Core ML Converter")
    print("=" * 60)
    print(f"Model: {args.model}")
    print(f"Output: {output_path}")
    print(f"Quantize: {args.quantize}")
    print(f"Max sequence length: {args.max_seq_length}")
    print()
    
    success = convert_hf_to_coreml(
        model_name=args.model,
        output_path=output_path,
        quantize=args.quantize,
        max_seq_length=args.max_seq_length,
        target_size_mb=args.target_size,
    )
    
    if success:
        print("\n" + "=" * 60)
        print("Next steps:")
        print(f"1. Add {output_path} to Xcode project (ios/Runner/Resources/Models/)")
        print("2. Update model_config.dart with the correct filename")
        print("3. Test the model in the app")
        sys.exit(0)
    else:
        print("\n" + "=" * 60)
        print("Conversion failed. See errors above.")
        sys.exit(1)


if __name__ == "__main__":
    main()

