# Model Conversion Guide

This guide explains how to convert ML models for use in the Dream Flow app on Android (TFLite) and iOS (Core ML).

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Story Model Conversion](#story-model-conversion)
3. [Image Model Conversion](#image-model-conversion)
4. [Troubleshooting](#troubleshooting)
5. [Performance Optimization](#performance-optimization)

## Prerequisites

### Install Dependencies

```bash
cd dream-flow-app/app/scripts
pip install -r requirements_conversion.txt
```

### Required Tools

- **Python 3.8+**
- **TensorFlow 2.13+** (for TFLite conversion)
- **coremltools 7.0+** (for Core ML conversion)
- **PyTorch 2.0+** (for model loading)
- **Xcode** (recommended for iOS, helps with Core ML tools)

## Story Model Conversion

### Android (TFLite)

Convert a Hugging Face model to TFLite:

```bash
python scripts/convert_story_to_tflite.py \
    --model distilgpt2 \
    --output models/gpt2_tiny.tflite \
    --quantize \
    --max-seq-length 128
```

**Options:**
- `--model`: Hugging Face model name (e.g., `gpt2`, `distilgpt2`, `gpt2-tiny`)
- `--output`: Output path for TFLite model
- `--quantize`: Enable INT8 quantization (reduces size by ~4x)
- `--no-quantize`: Disable quantization (larger but higher quality)
- `--max-seq-length`: Maximum sequence length (default: 128)
- `--target-size`: Target size in MB (default: 50)

**Recommended Models:**
- `distilgpt2` - Good balance of size and quality (~82M parameters)
- `gpt2` - Better quality but larger (~124M parameters)
- Smaller custom models if available

### iOS (Core ML)

Convert a Hugging Face model to Core ML:

```bash
python scripts/convert_story_to_coreml.py \
    --model distilgpt2 \
    --output models/gpt2_tiny.mlmodel \
    --quantize \
    --max-seq-length 128
```

**Options:** Same as TFLite conversion

**Note:** Core ML models can use Neural Engine on supported devices for faster inference.

### After Conversion

1. **Copy models to app:**
   - Android: `cp models/*.tflite android/app/src/main/assets/models/`
   - iOS: Add `.mlmodel` files to Xcode project (`ios/Runner/Resources/Models/`)

2. **Update `model_config.dart`:**
   - Update `StoryModel` class with correct filenames
   - Adjust size estimates if needed

3. **Test in app:**
   - Verify model loads correctly
   - Test story generation
   - Check performance meets targets (<10s per story)

## Image Model Conversion

Image model conversion is more complex because Stable Diffusion consists of multiple components.

### iOS (Core ML) - Recommended Approach

**Use Apple's Official Converter:**

1. **Clone Apple's repository:**
   ```bash
   git clone https://github.com/apple/ml-stable-diffusion.git
   cd ml-stable-diffusion
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Convert model:**
   ```bash
   python -m python_coreml_stable_diffusion.pipeline \
       --convert \
       -i runwayml/stable-diffusion-v1-5 \
       -o ../models/stable_diffusion_ios \
       --compute-unit ALL \
       --attention-implementation ORIGINAL
   ```

4. **This creates:**
   - `TextEncoder.mlpackage`
   - `Unet.mlpackage`
   - `VAEDecoder.mlpackage`
   - `VAEEncoder.mlpackage` (optional)

5. **Add to Xcode project:**
   - Add all `.mlpackage` files to `ios/Runner/Resources/Models/`

**For smaller models (faster inference):**
- Use `stable-diffusion-turbo` instead of `stable-diffusion-v1-5`
- Or search for pre-optimized Core ML models on Hugging Face

### Android (TFLite) - Experimental

Android conversion is more experimental. Consider:

1. **Use TensorFlow Stable Diffusion:**
   ```python
   from diffusers import StableDiffusionPipeline
   import tensorflow as tf
   
   # Convert to TFLite (simplified example)
   # Note: Full conversion requires handling multiple components
   ```

2. **Or use pre-converted models:**
   - Search Hugging Face for "stable-diffusion tflite"
   - May need to convert components separately

3. **Alternative: Use smaller image models:**
   - Consider using GAN-based models (smaller, faster)
   - Or use style transfer models for simpler image generation

## Troubleshooting

### Conversion Fails

**Problem:** Model too large for mobile
- **Solution:** Use a smaller model (e.g., `distilgpt2` instead of `gpt2`)
- **Solution:** Enable quantization (`--quantize`)
- **Solution:** Reduce `--max-seq-length`

**Problem:** Quantization errors
- **Solution:** Try without quantization first (`--no-quantize`)
- **Solution:** Use linear quantization instead of INT8

**Problem:** Core ML conversion fails on macOS
- **Solution:** Ensure Xcode is installed and up to date
- **Solution:** Use macOS 12+ for Core ML tools
- **Solution:** Check Python environment (use conda/virtualenv)

### Model Too Slow

**Problem:** Inference takes >30 seconds
- **Solution:** Use smaller models
- **Solution:** Reduce sequence length
- **Solution:** Optimize inference pipeline (batch processing, caching)
- **Solution:** Use device-specific optimizations (Neural Engine on iOS)

### Model Too Large

**Problem:** Model exceeds app size limits
- **Solution:** Enable quantization
- **Solution:** Use smaller models
- **Solution:** Consider dynamic model downloading (download on first use)

## Performance Optimization

### Target Sizes

- **Story Model:** <50MB (quantized)
- **Image Model:** <1GB total (all components)
- **Total:** <1.2GB for both models

### Target Performance

- **Story Generation:** <10 seconds
- **Image Generation:** <20 seconds (for 4 images)
- **Audio Generation:** <5 seconds (uses native TTS, no model needed)

### Optimization Tips

1. **Quantization:**
   - INT8 quantization reduces size by ~4x
   - May slightly reduce quality
   - Usually acceptable for mobile use

2. **Model Selection:**
   - Smaller models = faster inference
   - Balance quality vs. performance
   - Test on target devices

3. **Sequence Length:**
   - Shorter sequences = faster inference
   - Default: 128 tokens (good balance)

4. **Device-Specific:**
   - iOS: Use Neural Engine when available
   - Android: Use GPU delegate if available
   - CPU: Optimize for CPU-only devices (main target)

## Next Steps

After converting models:

1. ✅ Test models load correctly in app
2. ✅ Verify inference performance meets targets
3. ✅ Test on actual devices (not just emulators)
4. ✅ Update `model_config.dart` with correct paths
5. ✅ Document any model-specific requirements
6. ✅ Consider model versioning for updates

## Resources

- **Apple Core ML Tools:** https://coremltools.readme.io/
- **TensorFlow Lite:** https://www.tensorflow.org/lite
- **Apple Stable Diffusion:** https://github.com/apple/ml-stable-diffusion
- **Hugging Face Models:** https://huggingface.co/models

