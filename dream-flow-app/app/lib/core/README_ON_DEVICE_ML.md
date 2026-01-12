# On-Device ML Service

## Overview

The On-Device ML Service enables all AI processing to run directly on the user's device, leveraging:

- **iOS**: Core ML with Neural Engine acceleration
- **Android**: TensorFlow Lite with Tensor chip acceleration (on Pixel devices) or NPU acceleration on other devices

## Architecture

The service provides a unified interface for:
1. **Story Generation**: Text generation using on-device language models
2. **Image Generation**: Image generation using on-device Stable Diffusion or similar models
3. **Text-to-Speech**: Audio generation using on-device TTS models

## Model Requirements

### Story Generation Models

Models should be bundled with the app or downloaded on first launch:

**iOS (Core ML format)**:
- Recommended: DistilGPT-2, GPT-2 Small, or Llama 2/3 quantized models
- Format: `.mlmodel` or `.mlpackage`
- Location: Bundle under `ios/Runner/Resources/` or download to app documents

**Android (TensorFlow Lite format)**:
- Recommended: DistilGPT-2, GPT-2 Small, or quantized Llama models
- Format: `.tflite`
- Location: `android/app/src/main/assets/models/` or download to app documents

### Image Generation Models

**iOS**:
- Core ML Stable Diffusion models
- Format: `.mlpackage` with multiple models (text encoder, UNet, VAE decoder)
- Size: ~4-6GB (recommended to download on first launch)

**Android**:
- TensorFlow Lite Stable Diffusion models
- Format: `.tflite` files for each component
- Size: ~4-6GB (recommended to download on first launch)

### Text-to-Speech Models

**iOS**:
- Use native `AVSpeechSynthesizer` (no model needed) for basic TTS
- Or Core ML TTS models for higher quality

**Android**:
- Use Android TTS API (no model needed) for basic TTS
- Or TensorFlow Lite TTS models for higher quality

## Implementation Status

### Current Implementation (Placeholder)

The current implementation includes:
- ✅ Platform detection (iOS/Android)
- ✅ Service initialization
- ✅ Method stubs for all ML operations
- ✅ Placeholder implementations for testing

### TODO: Complete Implementation

1. **Story Generation**:
   - [ ] Integrate TensorFlow Lite interpreter for Android
   - [ ] Integrate Core ML for iOS (via platform channels or plugin)
   - [ ] Add model loading and tokenization
   - [ ] Implement inference pipeline

2. **Image Generation**:
   - [ ] Integrate Stable Diffusion models
   - [ ] Add model loading for iOS (Core ML) and Android (TFLite)
   - [ ] Implement image generation pipeline
   - [ ] Add model download functionality

3. **Text-to-Speech**:
   - [ ] Use native TTS APIs (AVSpeechSynthesizer on iOS, Android TTS on Android)
   - [ ] Or integrate TTS models for better quality

## Model Bundling

### Option 1: Bundle with App

Add models to app bundle:

**iOS**:
```bash
# Copy .mlmodel files to:
ios/Runner/Resources/Models/
```

**Android**:
```bash
# Copy .tflite files to:
android/app/src/main/assets/models/
```

### Option 2: Download on First Launch

Download models when the app first launches:

1. Check if models exist in app documents directory
2. If not, download from CDN or server
3. Cache models locally
4. Initialize ML service with downloaded models

## Platform-Specific Notes

### iOS (Core ML + Neural Engine)

- Uses Apple's Neural Engine for acceleration (A12 Bionic and later)
- Models are automatically optimized for Neural Engine
- Core ML handles CPU/GPU/Neural Engine selection automatically
- Best performance on iPhone 12 and later, iPad Pro

### Android (TensorFlow Lite + Tensor/NPU)

- Pixel devices use Tensor chip for acceleration
- Other devices use NPU (if available) or GPU/CPU
- NNAPI delegate handles hardware acceleration automatically
- Best performance on Pixel 6 and later, recent flagship devices

## Performance Considerations

- **Model Size**: Larger models = better quality but slower inference
- **Quantization**: Use quantized models (INT8) for faster inference with minimal quality loss
- **Batch Processing**: Process multiple items in batches when possible
- **Caching**: Cache model outputs when appropriate

## Privacy Benefits

- ✅ All processing happens on-device
- ✅ No data sent to external servers
- ✅ Works completely offline
- ✅ User privacy is protected

## Next Steps

1. Choose and prepare models (quantized, optimized for mobile)
2. Implement actual model inference (replace placeholders)
3. Add model download/caching functionality
4. Optimize for performance and memory usage
5. Test on various devices (old and new)

