# Model Download Instructions

## Important Note

**Ready-to-download models are not directly available** because:
1. Models need to be converted to TFLite (Android) or Core ML (iOS) format
2. Pre-converted models are not always publicly hosted
3. Models are large (100MB - 2GB) and require proper hosting

## What You Need

For testing on phones **without Tensor/Neural Engine chips**, you need:

1. **Story Model**: DistilGPT-2 (quantized) - ~150MB
2. **Image Model**: Stable Diffusion Turbo - ~1.5GB  
3. **TTS**: Native APIs (no download needed) ✅

## Options to Get Models

### Option 1: Use Placeholder Implementation (Fastest for Testing)

The app **already works** with placeholder implementations:
- ✅ Story generation uses template text
- ✅ Image generation returns empty list (UI still works)
- ✅ TTS uses native device APIs

**You can test immediately without any models!**

### Option 2: Convert Models Yourself (Recommended for Production)

#### For Android (TensorFlow Lite):

```bash
# 1. Install TensorFlow
pip install tensorflow

# 2. Convert DistilGPT-2 to TFLite
# See scripts/download_models.md for conversion code

# 3. Convert Stable Diffusion (requires more work)
# Follow: https://huggingface.co/docs/diffusers/optimization/tflite
```

#### For iOS (Core ML):

```bash
# 1. Install coremltools
pip install coremltools

# 2. Convert DistilGPT-2 to Core ML
# See scripts/download_models.md for conversion code

# 3. Use Apple's Stable Diffusion Core ML converter
# Follow: https://github.com/apple/ml-stable-diffusion
```

### Option 3: Search for Pre-converted Models

1. **Hugging Face Model Hub**: https://huggingface.co/models
   - Search: "distilgpt2 tflite" or "distilgpt2 coreml"
   - Search: "stable-diffusion tflite" or "stable-diffusion coreml"
   
2. **GitHub Repositories**:
   - Search GitHub for "distilgpt2 tflite" or "distilgpt2 coreml"
   - Check model conversion repositories

3. **Model Zoos**:
   - TensorFlow Lite Model Zoo
   - Apple Core ML Model Zoo

## Quick Setup (If You Have Models)

Once you have model files:

1. **Place them in the app**:
   - Android: `android/app/src/main/assets/models/`
   - iOS: `ios/Runner/Resources/Models/`

2. **Or update download URLs** in `lib/core/model_config.dart`:
   ```dart
   String get androidDownloadUrl => 'https://your-cdn.com/models/distilgpt2.tflite';
   ```

3. **The app will download them** on first launch automatically

## Recommended Approach for Testing

1. **Start with placeholders** - Test the app UI/UX immediately
2. **Convert story model first** - Smaller and easier (150MB)
3. **Test story generation** - Verify the pipeline works
4. **Convert image model later** - Larger and more complex (1.5GB)

## Need Help?

- See `scripts/download_models.md` for detailed conversion instructions
- See `README_MODEL_SETUP.md` for setup overview
- Check `ON_DEVICE_ML_IMPLEMENTATION.md` for implementation details

## Current Status

✅ **Infrastructure is ready** - All code is in place  
✅ **Placeholder implementations work** - You can test now  
⏳ **Model files needed** - For actual AI inference  
⏳ **Model conversion needed** - If you want real inference  

The app is fully functional with placeholders and will work with real models once you add them!

