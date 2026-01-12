# Azure Integration Guide

This document describes the Azure services integrated into Dream Flow for Microsoft Imagine Cup 2026.

## ⚠️ Important: Azure App Service is Optional

**If your backend runs on-device (bundled in the mobile app)**, you do NOT need Azure App Service. Azure App Service is only required if you want to deploy a shared cloud backend server.

**What you DO need** (even for on-device backend):
- ✅ Azure Content Safety API (for content moderation)
- ✅ Azure Computer Vision API (for image analysis)

**What you DON'T need** (for on-device backend):
- ❌ Azure App Service (only needed for cloud backend deployment)
- ❌ Azure Blob Storage (optional, Supabase Storage is used instead)

## Overview

Dream Flow uses a hybrid approach combining on-device local AI models with Azure cloud services:

- **Local Models**: Story generation, image generation, and TTS run on-device for privacy and offline capability
- **Azure Services**: Cloud-based safety, quality assurance, and infrastructure services (optional cloud backend)

## Azure AI Services

### 1. Azure Content Safety

**Purpose**: AI-powered content moderation for text and images

**Integration Points**:

- Text moderation in `ContentGuard.check_story()` method (`backend_fastapi/app/core/guardrails.py`)
- Image moderation in `VisualGenerator.create_frames()` method (`backend_fastapi/app/core/services.py`)
- Image moderation in `LocalVisualGenerator.create_frames()` method (`backend_fastapi/app/core/local_services.py`)

**Configuration**:

```bash
AZURE_CONTENT_SAFETY_ENABLED=true
AZURE_CONTENT_SAFETY_ENDPOINT=https://your-region.api.cognitive.microsoft.com/
AZURE_CONTENT_SAFETY_KEY=your-api-key
AZURE_CONTENT_SAFETY_SEVERITY_THRESHOLD=2  # 0-7 scale, 2 is Medium severity
```

**Usage**:

- Post-generation safety checks (local models generate, Azure validates)
- Stricter thresholds for child mode content
- Fail-open approach (continues with keyword-based checks if Azure service unavailable)

**Benefits**:

- More sophisticated than keyword-based filtering
- Text AND image moderation
- Built-in support for different severity levels
- Perfect for child-safe content requirements
- Demonstrates responsible AI usage

### 2. Azure Computer Vision

**Purpose**: Image analysis and accessibility enhancements

**Integration Points**:

- Image description generation in `VisualGenerator.create_frames()` (`backend_fastapi/app/core/services.py`)
- Image analysis in `LocalVisualGenerator.create_frames()` (`backend_fastapi/app/core/local_services.py`)

**Configuration**:

```bash
AZURE_COMPUTER_VISION_ENABLED=true
AZURE_COMPUTER_VISION_ENDPOINT=https://your-region.cognitiveservices.azure.com/
AZURE_COMPUTER_VISION_KEY=your-api-key
```

**Features**:

- Image caption generation for accessibility (screen readers)
- Image tagging for search and recommendations
- Object detection for content validation
- Scene analysis for story coherence checking

**Benefits**:

- Enhances accessibility (image descriptions for visually impaired)
- Validates local model output quality
- Demonstrates comprehensive AI integration
- Supports Education category (accessibility is a key factor)

## Azure Infrastructure Services

### 3. Azure App Service (Optional - Cloud Deployment Only)

**Purpose**: Cloud deployment platform for the FastAPI backend

**⚠️ Important**: Azure App Service is **NOT needed** if the backend runs on-device (bundled in the mobile app). This service is only required if you want to deploy a shared cloud backend server.

**When to Use**:
- ✅ You want a shared backend server accessible by multiple users
- ✅ You need centralized processing and storage
- ✅ You're deploying a web dashboard that needs a backend API

**When NOT to Use** (On-Device Architecture):
- ❌ Backend is bundled into the mobile app and runs on user's phone
- ❌ All processing happens locally on the device
- ❌ You want offline-first functionality

**Configuration** (if using cloud deployment):

- Infrastructure as Code: `azure/app-service.bicep`
- GitHub Actions workflow: `.github/workflows/deploy-azure-app-service.yml`
- Documentation: `azure/README.md`

**Features**:

- Containerized deployment (uses existing Dockerfile)
- Automatic scaling
- HTTPS/SSL support
- Application Insights integration
- Environment variable management

**Note**: Azure Content Safety and Computer Vision can still be used from an on-device backend - they are cloud APIs that can be called from mobile devices. Azure App Service is only for hosting the backend server itself.

### 4. Azure Blob Storage (Optional)

**Purpose**: Scalable asset storage alternative to Supabase Storage

**Configuration**:

```bash
AZURE_BLOB_STORAGE_ENABLED=true
AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;AccountName=...
AZURE_BLOB_STORAGE_CONTAINER_NAME=dream-flow-assets
```

**Implementation**: `backend_fastapi/app/core/azure_blob_storage.py`

**Note**: Currently Supabase Storage is used in production. Azure Blob Storage is available as an alternative for Azure-native deployments.

### 5. Azure Key Vault (Referenced)

**Purpose**: Secure secret management

**Configuration**: Already supported in `backend_fastapi/app/shared/config.py`

- Service-role keys can be loaded from Azure Key Vault
- Configured via `AZURE_KEY_VAULT_URL` environment variable

## Architecture

### On-Device Architecture (Primary - No Azure App Service Needed)

```
┌─────────────────────────────────────────────────────────┐
│              Dream Flow Mobile App                       │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Flutter App (On-Device Backend)                 │  │
│  │  ┌────────────────────────────────────────────┐  │  │
│  │  │  LocalBackendService (HTTP Server)        │  │  │
│  │  │  ┌──────────────────────────────────────┐ │  │  │
│  │  │  │  Story Generation Pipeline           │ │  │  │
│  │  │  │  1. Local LLM (Story Text) ──┐       │ │  │  │
│  │  │  │  2. Azure Content Safety ◄───┘       │ │  │  │
│  │  │  │  3. Local TTS (Audio)                 │ │  │  │
│  │  │  │  4. Local Image Gen ──┐              │ │  │  │
│  │  │  │  5. Azure Content Safety ◄───┘        │ │  │  │
│  │  │  │  6. Azure Computer Vision ◄───┘      │ │  │  │
│  │  │  └──────────────────────────────────────┘ │  │  │
│  │  └────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
└───────────┬─────────────────────────┬──────────────────┘
            │                         │
    ┌───────┴──────┬──────────┬───────┴──────┐
    │              │          │              │
┌───▼────┐  ┌─────▼────┐  ┌──▼──────┐  ┌───▼──────┐
│Supabase│  │Azure Key │  │Azure    │  │Azure     │
│  DB    │  │  Vault   │  │Content  │  │Computer  │
│        │  │          │  │ Safety  │  │ Vision   │
└────────┘  └──────────┘  └─────────┘  └──────────┘
```

**Note**: Azure Content Safety and Computer Vision are cloud APIs called from the on-device backend. Azure App Service is NOT used in this architecture.

### Cloud Architecture (Optional - Requires Azure App Service)

```
┌─────────────────────────────────────────────────────────┐
│                    Dream Flow App                       │
│  ┌─────────────────┐      ┌──────────────────┐        │
│  │  Flutter App    │      │   Next.js Web    │        │
│  │  (Local Models) │      │   Dashboard      │        │
│  └────────┬────────┘      └────────┬─────────┘        │
└───────────┼─────────────────────────┼──────────────────┘
            │                         │
            │ HTTP/REST               │
            │                         │
┌───────────▼─────────────────────────▼──────────────────┐
│           FastAPI Backend (Azure App Service)          │
│  ┌──────────────────────────────────────────────────┐ │
│  │  Story Generation Pipeline                      │ │
│  │  1. Local LLM (Story Text) ──┐                  │ │
│  │  2. Azure Content Safety ◄───┘                  │ │
│  │  3. Local TTS (Audio)                           │ │
│  │  4. Local Image Gen ──┐                         │ │
│  │  5. Azure Content Safety ◄──┘                   │ │
│  │  6. Azure Computer Vision ◄───┘                 │ │
│  └──────────────────────────────────────────────────┘ │
└───────────┬─────────────────────────┬──────────────────┘
            │                         │
    ┌───────┴──────┬──────────┬───────┴──────┐
    │              │          │              │
┌───▼────┐  ┌─────▼────┐  ┌──▼──────┐  ┌───▼──────┐
│Supabase│  │Azure Key │  │Azure    │  │Azure     │
│  DB    │  │  Vault   │  │Content  │  │Computer  │
│        │  │          │  │ Safety  │  │ Vision   │
└────────┘  └──────────┘  └─────────┘  └──────────┘
```

**Use this architecture only if you need a shared cloud backend server.**

## Setup Instructions

### 1. Create Azure Resources

**Azure Content Safety** (Required for content moderation):

1. Go to Azure Portal → Create Resource → Azure AI Services
2. Select "Content Safety"
3. Choose pricing tier and region
4. Note the endpoint and key

**Azure Computer Vision** (Required for image analysis):

1. Go to Azure Portal → Create Resource → Azure AI Services
2. Select "Computer Vision"
3. Choose pricing tier and region
4. Note the endpoint and key

**Azure App Service** (Optional - Only if using cloud backend):

⚠️ **Skip this step if your backend runs on-device!**

If you need a cloud backend server:
1. Use the Bicep template: `azure/app-service.bicep`
2. Or create via Azure Portal
3. Configure environment variables

### 2. Configure Environment Variables

Add to your deployment environment (Azure App Service, local `.env`, etc.):

```bash
# Azure Content Safety
AZURE_CONTENT_SAFETY_ENABLED=true
AZURE_CONTENT_SAFETY_ENDPOINT=https://your-region.api.cognitive.microsoft.com/
AZURE_CONTENT_SAFETY_KEY=your-key
AZURE_CONTENT_SAFETY_SEVERITY_THRESHOLD=2

# Azure Computer Vision
AZURE_COMPUTER_VISION_ENABLED=true
AZURE_COMPUTER_VISION_ENDPOINT=https://your-region.cognitiveservices.azure.com/
AZURE_COMPUTER_VISION_KEY=your-key

# Azure Blob Storage (optional)
AZURE_BLOB_STORAGE_ENABLED=false
AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;...
AZURE_BLOB_STORAGE_CONTAINER_NAME=dream-flow-assets
```

### 3. Install Dependencies

The required Azure packages are already in `requirements.txt`:

```bash
pip install -r backend_fastapi/requirements.txt
```

This includes:

- `azure-ai-contentsafety>=1.0.0`
- `azure-cognitiveservices-vision-computervision>=0.9.0`
- `azure-storage-blob>=12.19.0`
- `msrest>=0.7.1`

## Testing Azure Integration

### Test Azure Content Safety

```python
from backend_fastapi.app.core.azure_content_safety import get_content_safety_client

client = get_content_safety_client()
if client:
    # Test text moderation
    result = client.moderate_text("This is a test story about peaceful sleep.")
    print(f"Text is safe: {result['is_safe']}")

    # Test image moderation
    with open("test_image.png", "rb") as f:
        image_data = f.read()
    result = client.moderate_image(image_data)
    print(f"Image is safe: {result['is_safe']}")
```

### Test Azure Computer Vision

```python
from backend_fastapi.app.core.azure_computer_vision import get_computer_vision_client

client = get_computer_vision_client()
if client:
    # Test image description
    with open("test_image.png", "rb") as f:
        image_data = f.read()
    result = client.describe_image(image_data)
    print(f"Image description: {result['captions'][0]['text']}")
    print(f"Tags: {result['tags']}")
```

## Cost Estimation

**Azure Content Safety**:

- Pay-per-use pricing
- Text: ~$1.50 per 1,000 text evaluations
- Images: ~$1.50 per 1,000 image evaluations
- Free tier: First 5,000 evaluations per month

**Azure Computer Vision**:

- Pay-per-use pricing
- Describe Image: ~$1.50 per 1,000 transactions
- Analyze Image: ~$1.50 per 1,000 transactions
- Free tier: First 20 transactions per day

**Azure App Service**:

- Basic (B1): ~$13-15/month (development)
- Standard (S1): ~$70/month (production)

**Estimated Monthly Cost** (for Imagine Cup demo):

- Azure Content Safety: $0-10 (within free tier for small demo)
- Azure Computer Vision: $0-10 (within free tier)
- Azure App Service: $13-70 depending on tier
- **Total**: ~$13-90/month

## Troubleshooting

### Azure Content Safety Not Working

1. Verify endpoint and key are correct
2. Check service is enabled in Azure Portal
3. Review Application Insights logs for API errors
4. Verify `AZURE_CONTENT_SAFETY_ENABLED=true` is set

### Azure Computer Vision Not Working

1. Verify endpoint and key are correct
2. Check service is enabled and active in Azure Portal
3. Review logs for authentication errors
4. Verify image format is supported (PNG, JPEG)

### Import Errors

If you see import errors, ensure dependencies are installed:

```bash
pip install azure-ai-contentsafety azure-cognitiveservices-vision-computervision azure-storage-blob msrest
```

## Code References

- Azure Content Safety client: `backend_fastapi/app/core/azure_content_safety.py`
- Azure Computer Vision client: `backend_fastapi/app/core/azure_computer_vision.py`
- Azure Blob Storage client: `backend_fastapi/app/core/azure_blob_storage.py`
- Configuration: `backend_fastapi/app/shared/config.py`
- Guardrails integration: `backend_fastapi/app/core/guardrails.py`
- Image generation integration: `backend_fastapi/app/core/services.py`, `backend_fastapi/app/core/local_services.py`

## Next Steps

### For On-Device Architecture (Primary):
1. ✅ Configure Azure Content Safety and Computer Vision API keys
2. ✅ Add API keys to mobile app environment variables
3. ✅ Test Azure API calls from on-device backend
4. ✅ Monitor API usage and costs in Azure Portal
5. ❌ **Skip Azure App Service deployment** - not needed for on-device backend

### For Cloud Architecture (Optional):
1. Deploy backend to Azure App Service (see `docs/DEPLOYMENT_AZURE.md`)
2. Configure Azure AI services in Azure Portal
3. Test integration with sample content
4. Monitor costs and usage in Azure Portal
5. Review Application Insights for performance metrics
