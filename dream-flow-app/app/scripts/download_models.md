# Model Download Guide - Practical Steps

## Important Note

**Pre-converted models for mobile are not always readily available for direct download.** Most models need to be converted from their original format (PyTorch/TensorFlow) to mobile formats (TFLite/Core ML).

## Quick Download Options

### Option 1: Use Download Script (Recommended First Try)

```bash
# For Android
python scripts/download_models_now.py android

# For iOS  
python scripts/download_models_now.py ios

# Or use shell script
bash scripts/download_models_simple.sh android
```

**Note:** These scripts attempt to download from Hugging Face, but models may not be available at those exact URLs.

### Option 2: Manual Download from Hugging Face

1. **Story Model (GPT-2 Tiny or similar):**
   - Visit: https://huggingface.co/models?search=gpt2+tiny+tflite
   - Or: https://huggingface.co/models?search=mobilebert+tflite
   - Download the `.tflite` file (Android) or `.mlmodel` (iOS)

2. **Image Model (Stable Diffusion):**
   - This is more complex - see conversion guide below
   - Or search: https://huggingface.co/models?search=stable-diffusion+tflite

### Option 3: Use Placeholder Models (Fastest)

The app **works immediately** with placeholder implementations. You can test everything except actual AI generation:
- ✅ UI/UX testing
- ✅ App flow
- ✅ TTS (uses native APIs)
- ⏳ Real story generation (uses template)
- ⏳ Real image generation (returns empty)

## Model Requirements Summary

| Model | Size | Target Time | Format |
|-------|------|-------------|--------|
| Story (GPT-2 Tiny) | ~30-50MB | <10s | TFLite (Android) / Core ML (iOS) |
| Images (SD Turbo Lite) | ~800MB | <20s | TFLite (Android) / Core ML (iOS) |
| TTS | 0MB | <5s | Native APIs (no download) |

**Total:** ≤1.2GB, ≤30s generation time

## Why Direct Download Is Difficult

1. **Conversion Required**: Models need conversion to mobile formats
2. **Large Files**: 100MB-1GB files need proper hosting/CDN
3. **Platform Specific**: Different formats for Android (TFLite) vs iOS (Core ML)
4. **Quantization**: Models should be quantized for mobile (INT8)

## Recommended Approach

### For Immediate Testing:
1. ✅ Use placeholder implementations (already working)
2. ✅ Test app UI/UX flow
3. ✅ Verify parallel execution logic

### For Production:
1. Convert story model first (smaller, easier)
2. Test story generation
3. Convert image model later (larger, more complex)

## Conversion Resources

See `scripts/download_models.md` for detailed conversion instructions using:
- TensorFlow Lite Converter (Android)
- Core ML Tools (iOS)

## Alternative: Use Backend Models

If on-device models are too slow/large, you can:
- Use the existing FastAPI backend models
- Generate on server, stream to device
- Trade-off: Requires internet connection

## Current Status

✅ **Infrastructure ready** - All code implemented  
✅ **Placeholders working** - App is testable now  
⏳ **Model files needed** - For actual AI inference  
⏳ **Conversion required** - Most models need format conversion  

The app is fully functional with placeholders and will automatically use real models once you add them!
