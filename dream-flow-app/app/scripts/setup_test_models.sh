#!/bin/bash
# Setup script to download test models for CPU-only devices
# This script helps set up models for testing

set -e

PLATFORM=${1:-android}
MODELS_DIR="models"

echo "Setting up test models for $PLATFORM platform..."
echo ""

# Create models directory
mkdir -p "$MODELS_DIR"

if [ "$PLATFORM" = "android" ]; then
    echo "Android Models Setup"
    echo "==================="
    echo ""
    echo "For Android, you need TensorFlow Lite (.tflite) models:"
    echo ""
    echo "1. Story Generation Model:"
    echo "   - Search Hugging Face: https://huggingface.co/models?search=distilgpt2+tflite"
    echo "   - Or convert using: scripts/convert_to_tflite.py (create this script)"
    echo "   - Expected file: distilgpt2.tflite (~100-150MB quantized)"
    echo ""
    echo "2. Image Generation Models:"
    echo "   - Text Encoder: sd_text_encoder.tflite"
    echo "   - UNet: sd_unet.tflite"
    echo "   - VAE Decoder: sd_vae.tflite"
    echo "   - Search Hugging Face: https://huggingface.co/models?search=stable-diffusion+tflite"
    echo "   - Total size: ~1-2GB"
    echo ""
    echo "Place downloaded .tflite files in: android/app/src/main/assets/models/"
    
elif [ "$PLATFORM" = "ios" ]; then
    echo "iOS Models Setup"
    echo "================"
    echo ""
    echo "For iOS, you need Core ML (.mlmodel or .mlpackage) models:"
    echo ""
    echo "1. Story Generation Model:"
    echo "   - Search Hugging Face: https://huggingface.co/models?search=distilgpt2+coreml"
    echo "   - Or convert using coremltools"
    echo "   - Expected file: distilgpt2.mlmodel (~100-150MB quantized)"
    echo ""
    echo "2. Image Generation Model:"
    echo "   - Use Apple's Stable Diffusion Core ML: https://github.com/apple/ml-stable-diffusion"
    echo "   - Expected file: stable_diffusion.mlpackage (~1-2GB)"
    echo ""
    echo "Place downloaded .mlmodel/.mlpackage files in: ios/Runner/Resources/Models/"
    
else
    echo "Unknown platform: $PLATFORM"
    echo "Usage: ./setup_test_models.sh [android|ios]"
    exit 1
fi

echo ""
echo "📝 Next steps:"
echo "1. Download or convert models using the resources above"
echo "2. Copy models to the appropriate directory"
echo "3. Update model_config.dart URLs if using remote models"
echo "4. Test the app!"
echo ""
echo "For detailed instructions, see: scripts/download_models.md"

