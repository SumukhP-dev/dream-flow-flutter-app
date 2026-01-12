#!/bin/bash
# Simple script to download models using curl/wget
# For CPU-only devices, optimized for <30s generation

PLATFORM=${1:-android}
MODELS_DIR="models"

echo "Downloading models for $PLATFORM platform..."
echo "=========================================="
echo ""

mkdir -p "$MODELS_DIR"

if [ "$PLATFORM" = "android" ]; then
    echo "Android Models:"
    echo "==============="
    echo ""
    
    # Story Model - Try GPT-2 Tiny TFLite
    echo "1. Story Generation Model (GPT-2 Tiny)..."
    STORY_URL="https://huggingface.co/kumarvikram/gpt2-tiny/resolve/main/model.tflite"
    STORY_FILE="$MODELS_DIR/gpt2_tiny.tflite"
    
    if [ -f "$STORY_FILE" ]; then
        echo "   ⏭️  Already exists: $STORY_FILE"
    else
        echo "   📥 Downloading from Hugging Face..."
        curl -L -o "$STORY_FILE" "$STORY_URL" || {
            echo "   ❌ Download failed"
            echo "   💡 Note: Model may not be available at this URL"
            echo "   💡 Try: Search Hugging Face for 'gpt2 tiny tflite'"
        }
    fi
    
    echo ""
    echo "2. Image Generation Models (Stable Diffusion)..."
    echo "   ⚠️  Large files (1GB+), manual download recommended"
    echo "   📝 See: https://huggingface.co/models?search=stable-diffusion+tflite"
    echo ""
    
elif [ "$PLATFORM" = "ios" ]; then
    echo "iOS Models:"
    echo "==========="
    echo ""
    
    # Story Model - Try GPT-2 Tiny Core ML
    echo "1. Story Generation Model (GPT-2 Tiny)..."
    STORY_URL="https://huggingface.co/kumarvikram/gpt2-tiny/resolve/main/model.mlmodel"
    STORY_FILE="$MODELS_DIR/gpt2_tiny.mlmodel"
    
    if [ -f "$STORY_FILE" ]; then
        echo "   ⏭️  Already exists: $STORY_FILE"
    else
        echo "   📥 Downloading from Hugging Face..."
        curl -L -o "$STORY_FILE" "$STORY_URL" || {
            echo "   ❌ Download failed"
            echo "   💡 Note: Model may not be available at this URL"
            echo "   💡 Try: Search Hugging Face for 'gpt2 tiny coreml'"
        }
    fi
    
    echo ""
    echo "2. Image Generation Model (Stable Diffusion)..."
    echo "   📝 Use Apple's converter: https://github.com/apple/ml-stable-diffusion"
    echo ""
fi

echo ""
echo "📋 Summary:"
echo "   Models directory: $MODELS_DIR"
echo ""
echo "✅ Story model download attempted"
echo "⏳ Image models: See manual setup instructions"
echo ""
echo "📝 Next steps:"
echo "   1. Check if models downloaded successfully"
echo "   2. Copy to app assets directory"
echo "   3. Or update model_config.dart with download URLs"
echo ""

