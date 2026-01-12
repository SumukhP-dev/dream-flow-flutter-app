#!/usr/bin/env python3
"""
Convert story generation models to TensorFlow Lite format for Android.

Supports converting from:
- Hugging Face transformers (GPT-2, DistilGPT-2, etc.)
- PyTorch models
- ONNX models

Usage:
    python convert_story_to_tflite.py --model gpt2 --output gpt2_tiny.tflite --quantize
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import tensorflow as tf
    from transformers import AutoTokenizer, TFAutoModelForCausalLM
    import numpy as np
except ImportError as e:
    print(f"Error: Missing required dependencies. Install with:")
    print(f"  pip install -r requirements_conversion.txt")
    print(f"\nMissing: {e}")
    sys.exit(1)


def convert_hf_to_tflite(
    model_name: str,
    output_path: Path,
    quantize: bool = True,
    max_seq_length: int = 128,
    target_size_mb: int = 50,
):
    """
    Convert a Hugging Face model to TFLite format.
    
    Args:
        model_name: Hugging Face model name (e.g., 'gpt2', 'distilgpt2')
        output_path: Path to save the TFLite model
        quantize: Whether to quantize to INT8 (reduces size, may reduce quality)
        max_seq_length: Maximum sequence length for the model
        target_size_mb: Target size in MB (for guidance)
    """
    print(f"Loading model: {model_name}")
    print("=" * 60)
    
    # Load tokenizer and model
    # Try PyTorch first (more common for GPT models)
    try:
        from transformers import AutoModelForCausalLM
        import torch
        
        print("Loading PyTorch model (will convert to TFLite)...")
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model_pt = AutoModelForCausalLM.from_pretrained(model_name)
        model_pt.eval()
        
        # Convert PyTorch to TensorFlow via ONNX
        print("Converting PyTorch -> ONNX -> TFLite...")
        import tempfile
        import os
        
        # Create temporary ONNX file
        with tempfile.NamedTemporaryFile(suffix='.onnx', delete=False) as tmp_onnx:
            onnx_path = tmp_onnx.name
        
        # Convert to ONNX
        try:
            dummy_input = torch.randint(0, tokenizer.vocab_size, (1, max_seq_length))
            torch.onnx.export(
                model_pt,
                dummy_input,
                onnx_path,
                input_names=['input_ids'],
                output_names=['logits'],
                dynamic_axes={
                    'input_ids': {0: 'batch', 1: 'sequence'},
                    'logits': {0: 'batch', 1: 'sequence'}
                },
                opset_version=13,
            )
            
            # Convert ONNX to TFLite
            print("Converting ONNX to TFLite...")
            import onnx
            from onnx_tf.backend import prepare
            
            onnx_model = onnx.load(onnx_path)
            tf_rep = prepare(onnx_model)
            
            # Convert to TFLite
            converter = tf.lite.TFLiteConverter.from_saved_model(tf_rep.export_graph())
            
            if quantize:
                print("Applying INT8 quantization...")
                converter.optimizations = [tf.lite.Optimize.DEFAULT]
                converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
                converter.inference_input_type = tf.int8
                converter.inference_output_type = tf.int8
            
            tflite_model = converter.convert()
            
            # Save model
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'wb') as f:
                f.write(tflite_model)
            
            # Clean up
            os.unlink(onnx_path)
            
            size_mb = output_path.stat().st_size / (1024 * 1024)
            print(f"\n✓ Conversion successful!")
            print(f"  Output: {output_path}")
            print(f"  Size: {size_mb:.2f} MB")
            
            return True
            
        except Exception as e_onnx:
            print(f"ONNX conversion failed: {e_onnx}")
            if os.path.exists(onnx_path):
                os.unlink(onnx_path)
            raise
            
    except Exception as e:
        print(f"PyTorch conversion failed: {e}")
        print("\nTrying TensorFlow backend...")
        try:
            tokenizer = AutoTokenizer.from_pretrained(model_name)
            # Use TensorFlow backend for TFLite conversion
            model = TFAutoModelForCausalLM.from_pretrained(
                model_name,
                from_pt=False,  # Use TensorFlow weights if available
            )
        except Exception as e2:
            print(f"Error loading TensorFlow model: {e2}")
            print("\nTroubleshooting:")
            print("1. Install tf-keras: pip install tf-keras")
            print("2. Try a different model")
            return False
    
    # Set padding token if not set
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    print(f"Model loaded successfully")
    print(f"Vocabulary size: {len(tokenizer)}")
    print(f"Model parameters: {model.count_params():,}")
    
    # Create a representative dataset for quantization
    def representative_dataset():
        # Sample inputs for quantization calibration
        sample_texts = [
            "Once upon a time",
            "The little girl",
            "In a magical forest",
            "The brave knight",
            "Long ago, there was",
        ]
        
        for text in sample_texts:
            inputs = tokenizer(
                text,
                return_tensors="tf",
                padding="max_length",
                max_length=max_seq_length,
                truncation=True,
            )
            yield [inputs["input_ids"]]
    
    # Convert to TFLite
    print("\nConverting to TFLite...")
    print("=" * 60)
    
    # Create a concrete function for TFLite conversion
    @tf.function
    def model_inference(input_ids):
        outputs = model(input_ids)
        return outputs.logits
    
    # Get concrete function
    sample_input = tokenizer(
        "Hello",
        return_tensors="tf",
        padding="max_length",
        max_length=max_seq_length,
        truncation=True,
    )["input_ids"]
    
    concrete_func = model_inference.get_concrete_function(
        tf.TensorSpec(shape=[1, max_seq_length], dtype=tf.int32)
    )
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    if quantize:
        print("Applying INT8 quantization...")
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative_dataset
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.int8
        converter.inference_output_type = tf.int8
    
    try:
        tflite_model = converter.convert()
        
        # Save model
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        size_mb = output_path.stat().st_size / (1024 * 1024)
        print(f"\n✓ Conversion successful!")
        print(f"  Output: {output_path}")
        print(f"  Size: {size_mb:.2f} MB")
        
        if size_mb > target_size_mb * 1.5:
            print(f"  ⚠️  Warning: Size ({size_mb:.2f} MB) exceeds target ({target_size_mb} MB)")
            print(f"     Consider using a smaller model or more aggressive quantization")
        
        return True
        
    except Exception as e:
        print(f"\n✗ Conversion failed: {e}")
        print("\nTroubleshooting:")
        print("1. Try without quantization: --no-quantize")
        print("2. Use a smaller model (e.g., 'distilgpt2' instead of 'gpt2')")
        print("3. Reduce max_seq_length")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Convert story generation models to TensorFlow Lite format"
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
        default="models/gpt2_tiny.tflite",
        help="Output path for TFLite model",
    )
    parser.add_argument(
        "--quantize",
        action="store_true",
        default=True,
        help="Quantize model to INT8 (default: True)",
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
    
    print("Story Model to TFLite Converter")
    print("=" * 60)
    print(f"Model: {args.model}")
    print(f"Output: {output_path}")
    print(f"Quantize: {args.quantize}")
    print(f"Max sequence length: {args.max_seq_length}")
    print()
    
    success = convert_hf_to_tflite(
        model_name=args.model,
        output_path=output_path,
        quantize=args.quantize,
        max_seq_length=args.max_seq_length,
        target_size_mb=args.target_size,
    )
    
    if success:
        print("\n" + "=" * 60)
        print("Next steps:")
        print(f"1. Copy {output_path} to android/app/src/main/assets/models/")
        print("2. Update model_config.dart with the correct filename")
        print("3. Test the model in the app")
        sys.exit(0)
    else:
        print("\n" + "=" * 60)
        print("Conversion failed. See errors above.")
        sys.exit(1)


if __name__ == "__main__":
    main()

