# AI Inference Mode Configuration

## Unified AI Inference Control

The Dream Flow backend now supports a unified `AI_INFERENCE_MODE` environment variable that controls all inference modes with clear fallback behavior.

## Configuration Options

### Fallback Modes (Recommended)

- **`AI_INFERENCE_MODE=cloud_first`**
  - **Strategy**: Cloud APIs → Server Local → Phone Local
  - **Best For**: Fast multimedia features with reliable fallback
  - **Performance**: 5-10 seconds with cloud APIs
  - **Features**: Full translations, images, narration
  - **Fallback**: If cloud fails, automatically tries server GGUF models, then native mobile

- **`AI_INFERENCE_MODE=server_first`** *(Default)*
  - **Strategy**: Server Local → Cloud APIs → Phone Local  
  - **Best For**: Balanced performance and privacy
  - **Performance**: Variable (fast if local models available)
  - **Features**: Full features with mixed performance
  - **Fallback**: If server local fails, automatically tries cloud APIs, then native mobile

- **`AI_INFERENCE_MODE=phone_first`**
  - **Strategy**: Phone Local → Server Local → Cloud APIs
  - **Best For**: Mobile-optimized deployment
  - **Performance**: Optimized for phone constraints
  - **Features**: Mobile-friendly processing
  - **Fallback**: If phone fails, automatically tries server GGUF models, then cloud

### Single Modes (No Fallback)

- **`AI_INFERENCE_MODE=cloud_only`**
  - **Strategy**: Only HuggingFace APIs, no fallback
  - **Best For**: Guaranteed fast multimedia features
  - **Performance**: 5-10 seconds consistently
  - **Features**: Full cloud translations, images, narration
  - **Requirements**: HuggingFace API token required
  - **Fallback**: DISABLED - will fail if cloud APIs are unavailable

- **`AI_INFERENCE_MODE=server_only`**
  - **Strategy**: Only Server Local models, no fallback
  - **Best For**: Complete privacy, no external API calls
  - **Performance**: 60+ seconds (CPU inference)
  - **Features**: Full features but slow processing
  - **Fallback**: DISABLED - will fail if local models are unavailable

- **`AI_INFERENCE_MODE=phone_only`**
  - **Strategy**: Only Phone Local models, no fallback
  - **Best For**: Completely offline mobile deployment
  - **Performance**: Mobile-optimized
  - **Features**: Limited to phone capabilities
  - **Fallback**: DISABLED - will fail if phone ML is unavailable

## Graceful Fallback System

The backend implements a comprehensive fallback system at two levels:

### 1. Initialization Fallback (get_generators)
When the app starts, it tries to initialize generators in the configured order:
- Attempts primary mode first
- If initialization fails, tries next option in fallback chain
- Continues until successful or chain exhausted

### 2. Runtime Fallback (during generation)
Even after successful initialization, if generation fails at runtime:
- **Story Generation**: Automatically tries fallback story generators
- **Narration Generation**: Automatically tries fallback narration generators  
- **Visual Generation**: Automatically tries fallback visual generators
- Each respects the configured fallback chain order
- Last resort: placeholder images for visual generation

### Fallback Chain Examples

**cloud_first mode:**
```
Story fails on Cloud → tries Server Local → tries Native Mobile → error
Audio fails on Cloud → tries Server Local → tries Native Mobile → returns empty (audio optional)
Visual fails on Cloud → tries Server Local → tries Native Mobile → tries placeholders
```

**server_first mode (default):**
```
Story fails on Server Local → tries Cloud → tries Native Mobile → error
Audio fails on Server Local → tries Cloud → tries Native Mobile → returns empty
Visual fails on Server Local → tries Cloud → tries Native Mobile → tries placeholders
```

## Configuration Requirements

### For Cloud Inference (HuggingFace)
```env
HUGGINGFACE_API_TOKEN=hf_your_token_here
```

### For Server Local Inference (GGUF models)
```env
LOCAL_INFERENCE=true
LOCAL_MODEL_PATH=./models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
LOCAL_STORY_MODEL=tinyllama  # or llama-3.2-3b
```

### For Ollama Support (optional)
```env
USE_LOCAL_MODELS=true
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_STORY_MODEL=llama3.2:1b
```

### For Native Mobile Inference
```env
# Requires Flutter ML server running on localhost:8081
# No additional backend config needed
```

## Example Configuration

```env
# For fast multimedia features with reliable fallback (recommended)
AI_INFERENCE_MODE=cloud_first
HUGGINGFACE_API_TOKEN=your_token_here

# For balanced performance with privacy preference
AI_INFERENCE_MODE=server_first
HUGGINGFACE_API_TOKEN=your_token_here  # Fallback only
LOCAL_INFERENCE=true

# For complete privacy (no cloud calls)
AI_INFERENCE_MODE=server_only
LOCAL_INFERENCE=true
```

## Usage

Set in your `backend_fastapi/.env` file:

```env
AI_INFERENCE_MODE=cloud_first
HUGGINGFACE_API_TOKEN=hf_your_token_here
```

Then restart the backend:

```bash
cd backend_fastapi
python -m uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
```

## Migration from Legacy Settings

The new system replaces:
- `INFERENCE_VERSION` (deprecated)
- `LOCAL_INFERENCE` (deprecated - still used for enabling local models)  
- `DISABLE_LOCAL_MODELS` (deprecated)

Legacy settings are still supported for backward compatibility but will be overridden by `AI_INFERENCE_MODE`.

## Troubleshooting

### Issue: "All inference options failed"
**Solution**: Check that at least one inference mode is properly configured:
- For cloud: `HUGGINGFACE_API_TOKEN` is set
- For local: `LOCAL_INFERENCE=true` and model files exist
- For mobile: Flutter ML server is running on port 8081

### Issue: Fallback not working
**Solution**: 
- Check you're using a fallback mode (cloud_first/server_first/phone_first), not a single mode (*_only)
- Check logs for detailed fallback attempt messages
- Ensure fallback modes are properly configured

### Issue: Always using placeholders for images
**Solution**:
- Set `USE_PLACEHOLDERS_ONLY=false`
- Ensure `LOCAL_IMAGE_ENABLED=true`
- Check that torch/diffusers are installed for local image generation