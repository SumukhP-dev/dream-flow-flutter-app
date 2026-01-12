# Actual Model Download URLs

## Story Generation Models

### Android (TensorFlow Lite)

**Option 1: GPT-2 Tiny (Recommended - Fastest)**
- Search: https://huggingface.co/models?search=gpt2+tiny+tflite
- Alternative: Convert from https://huggingface.co/kumarvikram/gpt2-tiny
- Expected size: ~30-50MB
- Format: `.tflite`

**Option 2: MobileBERT (Alternative)**
- Search: https://huggingface.co/models?search=mobilebert+tflite
- Expected size: ~25-40MB
- Format: `.tflite`

**Option 3: TinyLlama (If others unavailable)**
- URL: https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF
- File: `tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf`
- **Note:** This is GGUF format, needs conversion to TFLite
- Expected size: ~650MB (larger but faster inference)

### iOS (Core ML)

**Option 1: GPT-2 Tiny**
- Search: https://huggingface.co/models?search=gpt2+tiny+coreml
- Alternative: Convert from https://huggingface.co/kumarvikram/gpt2-tiny
- Expected size: ~30-50MB
- Format: `.mlmodel` or `.mlpackage`

**Option 2: MobileBERT**
- Search: https://huggingface.co/models?search=mobilebert+coreml
- Expected size: ~25-40MB
- Format: `.mlmodel`

## Image Generation Models

### Android (TensorFlow Lite)

**Stable Diffusion Turbo Lite**
- Base model: https://huggingface.co/stabilityai/sdxl-turbo
- Search for TFLite conversion: https://huggingface.co/models?search=stable-diffusion+tflite
- Need 3 files:
  1. Text encoder (`.tflite`)
  2. UNet (`.tflite`)
  3. VAE decoder (`.tflite`)
- Total size: ~800MB-1GB

**Alternative: Lightweight Diffusion Models**
- Search for mobile-optimized variants
- Look for "lite" or "mobile" in model names

### iOS (Core ML)

**Apple's Stable Diffusion Converter** (Recommended)
- Repository: https://github.com/apple/ml-stable-diffusion
- Official Apple converter for iOS
- Output: `.mlpackage` format
- Follow their conversion guide

**Alternative: Pre-converted Core ML**
- Search: https://huggingface.co/models?search=stable-diffusion+coreml
- May find pre-converted `.mlpackage` files

## Download Instructions

### Step 1: Story Model (Start Here - Smaller)

1. Visit Hugging Face Model Hub
2. Search for models using terms above
3. Download the model file
4. Place in:
   - Android: `android/app/src/main/assets/models/`
   - iOS: `ios/Runner/Resources/Models/`

### Step 2: Image Model (Larger, More Complex)

1. Consider if needed for MVP (app works without it)
2. If needed, use conversion tools or Apple's converter
3. Place in assets directory

### Step 3: Update Configuration

If using remote downloads, update `lib/core/model_config.dart`:

```dart
String get androidDownloadUrl => 'YOUR_ACTUAL_URL_HERE';
```

## Testing Without Models

**You can test immediately:**
- ✅ App runs with placeholders
- ✅ UI/UX fully functional
- ✅ TTS works (native APIs)
- ✅ All app flows work

Models are only needed for actual AI generation.

## Help Finding Models

If models aren't available for direct download:

1. **Check Hugging Face**: Search with format + platform (e.g., "gpt2 tflite android")
2. **GitHub**: Search repositories for "model conversion" + your platform
3. **Convert Yourself**: See conversion guides in `scripts/download_models.md`
4. **Use Backend**: Fall back to server-side generation if needed

## Current Recommendation

**For fastest testing:**
1. Use placeholder implementations (already working)
2. Test app functionality
3. Convert story model when ready (smaller, easier)
4. Convert image model later if needed

The infrastructure is ready - models just need to be added when available!

