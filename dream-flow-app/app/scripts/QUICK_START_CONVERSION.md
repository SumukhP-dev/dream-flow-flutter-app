# Quick Start: Model Conversion

Get started converting models in 3 steps!

## Step 1: Install Dependencies

```bash
cd dream-flow-app/app/scripts
pip install -r requirements_conversion.txt
```

## Step 2: Convert Story Model

### For Android:
```bash
python convert_story_to_tflite.py \
    --model distilgpt2 \
    --output ../models/gpt2_tiny.tflite \
    --quantize
```

### For iOS:
```bash
python convert_story_to_coreml.py \
    --model distilgpt2 \
    --output ../models/gpt2_tiny.mlmodel \
    --quantize
```

## Step 3: Copy to App

### Android:
```bash
# Create assets directory
mkdir -p ../android/app/src/main/assets/models

# Copy model
cp ../models/gpt2_tiny.tflite ../android/app/src/main/assets/models/
```

### iOS:
1. Open Xcode project: `ios/Runner.xcworkspace`
2. Right-click `Runner/Resources/Models/` folder
3. "Add Files to Runner..."
4. Select `models/gpt2_tiny.mlmodel`

## That's It!

The model is now ready to use. Update `model_config.dart` if the filename differs.

## Image Models

Image models are more complex. See `MODEL_CONVERSION_GUIDE.md` for detailed instructions, or use Apple's official converter for iOS:
https://github.com/apple/ml-stable-diffusion

## Troubleshooting

**Model too large?** Try:
- Smaller model: `--model distilgpt2` (instead of `gpt2`)
- More quantization: `--quantize` (already enabled)
- Shorter sequences: `--max-seq-length 64`

**Conversion fails?** See `MODEL_CONVERSION_GUIDE.md` for detailed troubleshooting.

