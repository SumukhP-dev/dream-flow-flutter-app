# Model Acquisition and Conversion Guide

## Overview
This guide provides detailed instructions for obtaining and converting the required ML models for the Dream Flow app.

## Required Models

### 1. Story Generation Model (GPT-2 Tiny)
**Target**: ~50MB TFLite model for both Android and iOS
**Purpose**: Generate bedtime story text on-device

### 2. Image Generation Models (Stable Diffusion)
**Target**: 3 TFLite models (~800MB total) for Android, 1 Core ML package for iOS
**Purpose**: Generate story illustrations on-device

---

## Story Model Acquisition

### Option A: Download Pre-Converted TFLite Model (Recommended)

**Search Hugging Face for ready-to-use models:**

```bash
# Search for GPT-2 TFLite models
https://huggingface.co/models?search=gpt2+tflite

# Recommended models:
# 1. gpt2-tflite (smallest, fastest)
# 2. distilgpt2-tflite (better quality)
```

**Direct download example:**
```bash
cd dream-flow-app/app
mkdir -p android/app/src/main/offloaded_models

# Download model (example URL - replace with actual model)
curl -L -o android/app/src/main/offloaded_models/gpt2_tiny.tflite \
  "https://huggingface.co/username/gpt2-tflite/resolve/main/model.tflite"
```

### Option B: Convert from PyTorch/Hugging Face

**Prerequisites:**
```bash
pip install transformers tensorflow tf2onnx onnx
```

**Conversion script:**
```python
# convert_gpt2_to_tflite.py
import tensorflow as tf
from transformers import GPT2LMHeadModel, GPT2Tokenizer
import numpy as np

# Load model
model_name = "distilgpt2"  # or "gpt2" for larger model
model = GPT2LMHeadModel.from_pretrained(model_name)
tokenizer = GPT2Tokenizer.from_pretrained(model_name)

# Convert to TensorFlow
class TFGPTModel(tf.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
    
    @tf.function(input_signature=[tf.TensorSpec(shape=[1, 128], dtype=tf.int32)])
    def call(self, input_ids):
        outputs = self.model(input_ids=input_ids)
        return outputs.logits

# Create concrete function
tf_model = TFGPTModel(model)

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_concrete_functions([
    tf_model.call.get_concrete_function()
])

# Optimization
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]  # Use FP16 for smaller size

# Convert
tflite_model = converter.convert()

# Save
with open('gpt2_tiny.tflite', 'wb') as f:
    f.write(tflite_model)

print("✓ Model converted successfully")
print(f"  Size: {len(tflite_model) / (1024*1024):.2f} MB")
```

Run conversion:
```bash
python convert_gpt2_to_tflite.py
mv gpt2_tiny.tflite dream-flow-app/app/android/app/src/main/offloaded_models/
```

### Option C: Use Provided Placeholder

The app currently works with placeholder implementations for testing. Model files are optional until you need actual inference.

---

## Image Model Acquisition

### Android: TFLite Stable Diffusion Models

**Prerequisites:**
```bash
pip install ai-edge-torch torch diffusers transformers
```

**Option A: Use Pre-Converted Models**

Search for TFLite Stable Diffusion models:
```bash
https://huggingface.co/models?search=stable-diffusion+tflite
```

Look for models with these components:
- `sd_text_encoder.tflite` (~200MB)
- `sd_unet.tflite` (~400MB)
- `sd_vae_decoder.tflite` (~200MB)

**Option B: Convert from Stable Diffusion**

```python
# convert_sd_to_tflite.py
from diffusers import StableDiffusionPipeline
import ai_edge_torch
import torch

# Load Stable Diffusion model
model_id = "stabilityai/stable-diffusion-2-1-base"
pipe = StableDiffusionPipeline.from_pretrained(model_id, torch_dtype=torch.float16)

# Convert text encoder
text_encoder = pipe.text_encoder
text_encoder_tflite = ai_edge_torch.convert(
    text_encoder, 
    sample_inputs=(torch.ones(1, 77, dtype=torch.long),)
)
text_encoder_tflite.export("sd_text_encoder.tflite")

# Convert UNet (similar process)
# Convert VAE decoder (similar process)

print("✓ Stable Diffusion models converted")
```

**Place converted models:**
```bash
mv sd_*.tflite dream-flow-app/app/android/app/src/main/offloaded_models/
```

### iOS: Core ML Models

**Prerequisites:**
```bash
pip install coremltools transformers torch
```

**Option A: Use Apple's ml-stable-diffusion Tool**

```bash
# Clone Apple's conversion tool
git clone https://github.com/apple/ml-stable-diffusion.git
cd ml-stable-diffusion

# Convert Stable Diffusion to Core ML
python -m python_coreml_stable_diffusion.torch2coreml \
  --model-version stabilityai/stable-diffusion-2-1-base \
  --convert-unet \
  --convert-text-encoder \
  --convert-vae-decoder \
  --bundle-resources-for-swift-cli \
  --attention-implementation SPLIT_EINSUM \
  -o models/

# This creates .mlpackage files optimized for Neural Engine
```

**Option B: Manual Conversion**

```python
# convert_to_coreml.py
import coremltools as ct
import torch
from transformers import GPT2LMHeadModel

# Load PyTorch model
model = GPT2LMHeadModel.from_pretrained("distilgpt2")
model.eval()

# Trace model
example_input = torch.randint(0, 50257, (1, 128))
traced_model = torch.jit.trace(model, example_input)

# Convert to Core ML
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(shape=(1, 128), dtype=np.int32)],
    compute_units=ct.ComputeUnit.ALL,  # Use Neural Engine
)

# Save
mlmodel.save("gpt2_tiny.mlmodel")
print("✓ Core ML model created")
```

**Bundle in iOS app:**
```bash
# Compile model (if .mlmodel format)
xcrun coremlcompiler compile gpt2_tiny.mlmodel gpt2_tiny.mlmodelc

# Move to iOS resources
mv gpt2_tiny.mlmodelc dream-flow-app/app/ios/Runner/Resources/Models/
```

---

## Model Placement Summary

### Android Models
```
dream-flow-app/app/android/app/src/main/offloaded_models/
├── gpt2_tiny.tflite           # Story generation (~50MB)
├── sd_text_encoder.tflite     # SD text encoder (~200MB)
├── sd_unet.tflite             # SD UNet (~400MB)
└── sd_vae_decoder.tflite      # SD VAE decoder (~200MB)
```

### iOS Models
```
dream-flow-app/app/ios/Runner/Resources/Models/
├── gpt2_tiny.mlmodelc         # Story generation (~50MB)
└── stable_diffusion.mlpackage # Complete SD pipeline (~800MB)
```

---

## Verification

After placing models, run shape verification tests:

```bash
cd dream-flow-app/app
flutter test test/model_shape_test.dart
```

Expected output:
```
✓ Story model shapes verified
✓ Text encoder shapes verified
✓ UNet shapes verified
✓ VAE decoder shapes verified
```

---

## Model Size and Performance

| Model | Android Size | iOS Size | Inference Time (Target) |
|-------|--------------|----------|-------------------------|
| Story | ~50MB | ~50MB | <10s |
| Image (all) | ~800MB | ~800MB | <20s (4 images) |
| **Total** | **~850MB** | **~850MB** | **≤30s total** |

---

## Alternative: Use Placeholder Mode

The app works without actual model files for testing:
- Story generation uses placeholder text
- Image generation uses gradient placeholder images
- TTS works normally (uses native APIs)

This allows full app testing before obtaining models.

---

## Troubleshooting

### Model Loading Errors

**"Model file not found"**
- Verify model files are in correct directories
- Check file permissions
- Ensure models are included in build (update build.gradle for Android)

**"Failed to create interpreter"**
- Model format may be incorrect
- Try re-converting with correct TFLite/Core ML version
- Check model compatibility with TFLite Flutter 0.12.1

**"Out of memory"**
- Models too large for device
- Use smaller model variants
- Enable model quantization during conversion

### Conversion Issues

**"Unsupported operation"**
- Not all PyTorch operations convert to TFLite/Core ML
- Use compatible model architectures
- Check conversion tool documentation

**"Shape mismatch"**
- Ensure input shapes match expected format
- Update model config in `model_config.dart` if needed

---

## Resources

- **Hugging Face Models**: https://huggingface.co/models
- **TensorFlow Lite Guide**: https://www.tensorflow.org/lite/models/convert
- **Core ML Tools**: https://coremltools.readme.io/
- **Apple ml-stable-diffusion**: https://github.com/apple/ml-stable-diffusion
- **ai-edge-torch**: https://github.com/google-ai-edge/ai-edge-torch

---

## Next Steps

1. Choose acquisition method (pre-converted vs. manual conversion)
2. Download or convert models
3. Place in correct directories
4. Run verification tests
5. Build and test on physical devices
6. Benchmark performance
