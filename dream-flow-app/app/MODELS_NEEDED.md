# Models Needed Summary

## ✅ Only 2 Models Required

### 1. Story Generation Model
- **Purpose**: Generate bedtime story text
- **Model**: GPT-2 Tiny or MobileBERT (recommended for speed)
- **Format**: 
  - Android: TensorFlow Lite (`.tflite`)
  - iOS: Core ML (`.mlmodel` or `.mlpackage`)
- **Size**: ~30-50MB (quantized)
- **Target Time**: <10 seconds per story
- **Required**: ✅ Yes

### 2. Image Generation Model
- **Purpose**: Generate story illustration images
- **Model**: Stable Diffusion Turbo Lite (lightweight variant)
- **Format**: 
  - Android: TensorFlow Lite (`.tflite` files - 3 components: text encoder, UNet, VAE decoder)
  - iOS: Core ML (`.mlpackage`)
- **Size**: ~800MB-1GB total
- **Target Time**: <20 seconds for 4 images (runs in parallel with audio)
- **Required**: ✅ Yes (for image generation feature)

### 3. TTS/Narration ❌ NO MODEL NEEDED
- **Purpose**: Convert story text to speech
- **Implementation**: Native device APIs
  - iOS: `AVSpeechSynthesizer` (built-in)
  - Android: Android TTS API (built-in)
- **Size**: 0MB (no download needed)
- **Target Time**: <5 seconds
- **Required**: ❌ No - Already works!

## Total Requirements

| Component | Model Size | Download Needed? |
|-----------|------------|------------------|
| Story Model | ~50MB | ✅ Yes |
| Image Model | ~800MB | ✅ Yes |
| TTS | 0MB | ❌ No (native APIs) |
| **Total** | **~850MB** | **2 models** |

## Quick Reference

### What You Need to Download/Convert:
1. ✅ Story generation model (GPT-2 Tiny TFLite/Core ML)
2. ✅ Image generation model (Stable Diffusion Turbo Lite)

### What You DON'T Need:
- ❌ TTS model - Uses native device TTS APIs
- ❌ Audio generation model - Not needed
- ❌ Any other models - Just these 2!

## Storage Requirements

- **Minimum**: ~850MB for both models
- **Recommended**: ~1.2GB total (includes app + models)
- **Fits on phone**: ✅ Yes (well within phone storage limits)

## Performance

With these 2 models:
- Story generation: <10s (sequential)
- Image generation: <20s (parallel with audio)
- Audio generation: <5s (parallel with images, uses native APIs)
- **Total**: ≤30s ✅ Meets requirement

## Next Steps

1. Download/convert story model (start here - smaller, easier)
2. Download/convert image model (larger, more complex)
3. TTS - Already works! No setup needed

See `scripts/DOWNLOAD_MODELS.md` for download instructions.

