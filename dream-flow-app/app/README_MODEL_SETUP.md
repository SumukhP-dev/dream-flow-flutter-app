# Model Setup for Testing

This document explains how to set up the three ML models for testing on phones without specialized AI chips (Tensor/Neural Engine).

## Overview

The app requires three models for on-device inference:

1. **Story Generation Model** (DistilGPT-2) - ~150MB
2. **Image Generation Model** (Stable Diffusion Turbo) - ~1.5GB
3. **Text-to-Speech** - Uses native APIs (no download needed)

## Quick Setup Options

### Option A: Use Pre-converted Models from Hugging Face (Easiest)

1. Visit [Hugging Face Model Hub](https://huggingface.co/models)
2. Search for pre-converted models:
   - **Android**: Search "distilgpt2 tflite" and "stable-diffusion tflite"
   - **iOS**: Search "distilgpt2 coreml" and check [Apple's Stable Diffusion repo](https://github.com/apple/ml-stable-diffusion)

3. Download models and place them in:
   - **Android**: `android/app/src/main/assets/models/`
   - **iOS**: `ios/Runner/Resources/Models/`

4. Update `lib/core/model_config.dart` with the correct file paths

### Option B: Download on First Launch (Recommended for Testing)

The app is configured to download models automatically on first launch. You just need to:

1. Update the model URLs in `lib/core/model_config.dart` to point to hosted model files
2. Run the app - models will download automatically
3. Models are cached locally after first download

### Option C: Convert Models Yourself

See `scripts/download_models.md` for detailed conversion instructions using:
- TensorFlow Lite Converter (Android)
- Core ML Tools (iOS)

## Current Status

The app includes placeholder implementations that work without actual models:
- ✅ Story generation uses placeholder text (works for testing UI)
- ✅ Image generation returns empty list (UI still works)
- ✅ TTS uses native device APIs (works without models)

## Testing Without Models

You can test the app immediately without downloading models - it will use placeholders. Models are only needed for:
- Actual AI story generation
- Image generation
- Production-ready deployment

## Model URLs Configuration

Update these URLs in `lib/core/model_config.dart` when you have model files:

```dart
// Story Model
String get androidDownloadUrl => 'YOUR_URL_HERE/distilgpt2.tflite';
String get iosDownloadUrl => 'YOUR_URL_HERE/distilgpt2.mlmodel';

// Image Models (Android)
String get androidTextEncoderUrl => 'YOUR_URL_HERE/sd_text_encoder.tflite';
String get androidUNetUrl => 'YOUR_URL_HERE/sd_unet.tflite';
String get androidVAEUrl => 'YOUR_URL_HERE/sd_vae.tflite';
```

## Next Steps

1. Choose a setup option above
2. Download/convert models
3. Update configuration
4. Test the app!

For more details, see `scripts/download_models.md`

