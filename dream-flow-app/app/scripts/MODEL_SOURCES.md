# Model Sources and Download Links

## Story Generation Model: DistilGPT-2

### Android (TensorFlow Lite)

**Option 1: Convert from Hugging Face**
- Original model: https://huggingface.co/distilgpt2
- Download PyTorch model, then convert to TFLite
- Conversion script: See conversion examples in this directory

**Option 2: Search for Pre-converted**
- Search Hugging Face: https://huggingface.co/models?search=distilgpt2+tflite
- Search GitHub: "distilgpt2 tflite"

**Option 3: Use Alternative Lightweight Model**
- GPT-2 Small (124M): https://huggingface.co/gpt2
- TinyGPT-2: Smaller alternative

### iOS (Core ML)

**Option 1: Convert from Hugging Face**
- Original model: https://huggingface.co/distilgpt2
- Download PyTorch model, then convert using coremltools
- Conversion script: See conversion examples

**Option 2: Search for Pre-converted**
- Search Hugging Face: https://huggingface.co/models?search=distilgpt2+coreml
- Search GitHub: "distilgpt2 coreml" or "distilgpt2 mlmodel"

## Image Generation Model: Stable Diffusion

### Android (TensorFlow Lite)

**Option 1: Convert Stable Diffusion**
- Base model: https://huggingface.co/runwayml/stable-diffusion-v1-5
- Turbo variant: https://huggingface.co/stabilityai/sdxl-turbo
- Conversion guide: https://huggingface.co/docs/diffusers/optimization/tflite

**Option 2: Search for Pre-converted**
- Search Hugging Face: https://huggingface.co/models?search=stable-diffusion+tflite
- Note: Full SD models are large, consider SD-Turbo for mobile

**Components Needed:**
1. Text Encoder (`.tflite`)
2. UNet (`.tflite`)
3. VAE Decoder (`.tflite`)

### iOS (Core ML)

**Best Option: Use Apple's Converter**
- Repository: https://github.com/apple/ml-stable-diffusion
- Official Apple converter for Stable Diffusion to Core ML
- Well-documented and optimized for iOS

**Alternative:**
- Search Hugging Face: https://huggingface.co/models?search=stable-diffusion+coreml
- Note: Core ML packages (.mlpackage) are preferred over .mlmodel

## Text-to-Speech

✅ **No model download needed!**
- Uses native device TTS APIs
- iOS: AVSpeechSynthesizer
- Android: Android TTS API
- Already implemented and working

## Model Size Reference

| Model | Format | Size |
|-------|--------|------|
| DistilGPT-2 (quantized) | TFLite/Core ML | ~150MB |
| Stable Diffusion Turbo | TFLite (3 files) | ~1.5GB total |
| Stable Diffusion Turbo | Core ML package | ~1.5GB |

## Recommended Search Terms

When looking for models, try these search terms:

**For Hugging Face:**
- `distilgpt2 tflite`
- `distilgpt2 coreml`
- `stable-diffusion tflite mobile`
- `stable-diffusion coreml`

**For GitHub:**
- `distilgpt2 tflite android`
- `distilgpt2 coreml ios`
- `stable-diffusion mobile tflite`
- `stable-diffusion coreml converter`

## Notes

- Models must be **quantized** for mobile (INT8 quantization)
- **CPU-only** models work on all devices (no Tensor/Neural Engine required)
- Larger models = better quality but slower inference
- For testing, start with story model only (smallest)

