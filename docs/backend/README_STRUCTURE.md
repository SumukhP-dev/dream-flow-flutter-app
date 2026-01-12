# Backend Structure

## Overview

The backend is organized as a monorepo with clear separation between:
- **Shared utilities** (`shared/`) - Configuration, auth, database, exceptions
- **Core AI services** (`core/`) - Story, narration, and visual generation
- **Dream Flow app** (`dreamflow/`) - Main consumer app endpoints
- **Studio app** (`studio/`) - Creator/professional app endpoints

## Directory Structure

```
backend_fastapi/app/
│
├── 📄 main.py                # Root entry point
│
├── 📁 shared/                # 🔧 Shared Utilities
│   ├── config.py            # Settings & configuration
│   ├── exceptions.py        # Custom exceptions
│   ├── supabase_client.py   # Database client
│   └── auth.py              # Authentication
│
├── 📁 core/                  # 🤖 Shared AI Model Infrastructure
│   ├── services.py          # StoryGenerator, NarrationGenerator, VisualGenerator
│   ├── prompting.py         # PromptBuilder (BEDTIME_STORY, ASMR, MINDFULNESS, etc.)
│   ├── guardrails.py        # ContentGuard (BEDTIME_SAFETY, BRAND_COMPLIANCE)
│   └── story_presets.json    # Theme presets
│
├── 📁 dreamflow/             # 🌙 Dream Flow App
│   ├── main.py              # API endpoints (/api/v1/story, /api/v1/history, etc.)
│   ├── schemas.py           # Request/response models
│   ├── subscription_service.py
│   ├── notification_service.py
│   └── recommendation_engine.py
│
└── 📁 studio/                # 🎬 Dreamflow AI Studio
    ├── main.py              # API endpoints (/api/v1/studio/*)
    ├── output_formats.py   # Multi-format generation
    ├── batch_processor.py  # Batch job queue
    ├── template_service.py # Template management
    └── analytics_service.py # Creator analytics
```

## Key Benefits

✅ **Clear Organization**: All folders at the same level - easy to scan  
✅ **Consistent Structure**: `shared/`, `core/`, `dreamflow/`, `studio/` are all siblings  
✅ **Shared Core**: AI services used by both products  
✅ **Scalable**: Easy to add more products or features

## Import Examples

### From shared (utilities)
```python
from app.shared.config import Settings, get_settings
from app.shared.exceptions import HuggingFaceError
from app.shared.supabase_client import SupabaseClient
from app.shared.auth import get_authenticated_user_id
```

### From core (AI services)
```python
from app.core.services import StoryGenerator, NarrationGenerator
from app.core.prompting import PromptBuilder, PromptBuilderMode
from app.core.guardrails import ContentGuard, GuardrailMode
```

### From dreamflow
```python
from app.dreamflow.schemas import StoryRequest, StoryResponse
from app.dreamflow.subscription_service import SubscriptionService
```

### From studio
```python
from app.studio.batch_processor import BatchProcessor
from app.studio.output_formats import OutputFormatService
```

## Running the Application

```bash
cd backend_fastapi
uvicorn app.main:app --reload --port 8080
```

This serves both apps:
- **Dream Flow**: `/api/v1/story`, `/api/v1/history`, etc.
- **Studio**: `/api/v1/studio/batch`, `/api/v1/studio/templates`, etc.

