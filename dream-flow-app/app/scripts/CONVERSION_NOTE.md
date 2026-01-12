# Model Conversion Note

## Current Status

Full PyTorch -> TFLite conversion for GPT models (like DistilGPT-2) is complex and requires:
1. Converting PyTorch -> ONNX -> TensorFlow -> TFLite
2. Handling dynamic shapes and attention mechanisms
3. Quantization calibration

## Recommended Approaches

### Option 1: Use Pre-Converted Models (Easiest)

Search Hugging Face for pre-converted TFLite models:
- https://huggingface.co/models?search=gpt2+tflite
- Download ready-to-use models
- Place in `models/` directory

### Option 2: Use TensorFlow-Native Models

Use models that natively support TensorFlow:
- Convert directly using TensorFlow Lite Converter
- No intermediate conversions needed
- Better compatibility

### Option 3: Manual Conversion (Advanced)

For full control:
1. Export PyTorch model to ONNX
2. Convert ONNX to TensorFlow SavedModel
3. Convert SavedModel to TFLite
4. Apply quantization if needed

See: https://www.tensorflow.org/lite/models/convert

### Option 4: Use Placeholder (For Testing)

The app works with placeholder implementations for testing:
- Story generation uses placeholder text
- Image generation uses placeholder images
- TTS uses native APIs (works without models)

## For iOS (Core ML)

Core ML conversion is more straightforward:
```bash
python scripts/convert_story_to_coreml.py --model distilgpt2 --output models/gpt2_tiny.mlmodel --quantize
```

Core ML tools handle PyTorch models better than TFLite.

## Next Steps

1. **For immediate testing**: Use placeholder implementations (app works now)
2. **For production**: 
   - Search for pre-converted models on Hugging Face
   - Or use Core ML for iOS (easier conversion)
   - Or follow TensorFlow's official conversion guide

The app is designed to work without models for testing, and can load models when available.

