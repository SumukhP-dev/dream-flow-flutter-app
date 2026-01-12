# Backend Structure - Monorepo Organization

This document describes the reorganized monorepo structure for Dream Flow AI and Dreamflow AI Studio.

## Directory Structure

```
backend_fastapi/app/
├── __init__.py
├── main.py                    # Root entry point - routes to dreamflow and studio
│
├── config.py                  # Settings and configuration (shared)
├── exceptions.py              # Custom exception classes (shared)
├── supabase_client.py         # Database client wrapper (shared)
├── auth.py                    # Authentication helpers (shared)
│
├── core/                      # Shared AI model infrastructure
│   ├── __init__.py
│   ├── services.py            # StoryGenerator, NarrationGenerator, VisualGenerator
│   ├── prompting.py           # PromptBuilder with modes (BEDTIME_STORY, ASMR, etc.)
│   ├── guardrails.py          # ContentGuard with modes (BEDTIME_SAFETY, BRAND_COMPLIANCE)
│   └── story_presets.json     # Theme presets
│
├── dreamflow/                 # Dream Flow app
│   ├── __init__.py
│   ├── main.py                # Dream Flow endpoints (/api/v1/story, etc.)
│   ├── schemas.py             # Request/response models
│   ├── subscription_service.py
│   ├── notification_service.py
│   └── recommendation_engine.py
│
└── studio/                    # Dreamflow AI Studio app
    ├── __init__.py
    ├── main.py                # Studio endpoints (/api/v1/studio/*)
    ├── output_formats.py      # Multi-format generation (16:9, 9:16, MP3, etc.)
    ├── batch_processor.py     # Batch job queue system
    ├── template_service.py    # Template management
    └── analytics_service.py   # Creator analytics
```

## API Routes

### Main App Routes
- `POST /api/v1/story` - Generate story
- `GET /api/v1/history` - Get session history
- `GET /api/v1/stories/history` - Paginated story history
- `GET /api/v1/presets` - Get story presets
- `POST /api/v1/feedback` - Submit feedback
- `GET /api/v1/subscription` - Get subscription
- `GET /api/v1/subscription/quota` - Get usage quota
- `POST /api/v1/subscription` - Create subscription
- `POST /api/v1/subscription/cancel` - Cancel subscription
- `GET /api/v1/notifications/preferences` - Get notification preferences
- `PUT /api/v1/notifications/preferences` - Update notification preferences
- `GET /api/v1/recommendations` - Get theme recommendations
- `GET /api/v1/admin/moderation` - List moderation queue (admin)
- `GET /health` - Health check

### Studio Routes
- `POST /api/v1/studio/batch` - Create batch job
- `GET /api/v1/studio/batch` - List batch jobs
- `GET /api/v1/studio/batch/{job_id}` - Get batch job
- `POST /api/v1/studio/batch/{job_id}/cancel` - Cancel batch job
- `POST /api/v1/studio/templates` - Create template
- `GET /api/v1/studio/templates` - List templates
- `GET /api/v1/studio/templates/{template_id}` - Get template
- `GET /api/v1/studio/analytics/overview` - Get analytics overview
- `GET /api/v1/studio/analytics/renders` - Get render statistics
- `GET /api/v1/studio/analytics/templates/{template_id}` - Get template performance
- `POST /api/v1/studio/formats/generate` - Generate multiple output formats

## Import Patterns

### From core (AI services)
```python
from ..core.services import StoryGenerator, NarrationGenerator, VisualGenerator
from ..core.prompting import PromptBuilder, PromptBuilderMode
from ..core.guardrails import ContentGuard, GuardrailMode
```

### From root (shared utilities)
```python
from ..config import Settings, get_settings
from ..exceptions import HuggingFaceError
from ..supabase_client import SupabaseClient
from ..auth import get_authenticated_user_id
```

### From dreamflow (schemas)
```python
from ..dreamflow.schemas import StoryRequest, StoryResponse
```

### From studio (Studio services)
```python
from ..studio.batch_processor import BatchProcessor
from ..studio.template_service import TemplateService
from ..studio.analytics_service import AnalyticsService
from ..studio.output_formats import OutputFormatService
```

## Running the Application

The root `main.py` creates both apps and mounts them:

```bash
# Run from backend_fastapi directory
uvicorn app.main:app --reload --port 8080
```

This will serve:
- Main app routes at `/api/v1/*`
- Studio routes at `/api/v1/studio/*`
- Health check at `/health`

## Key Design Decisions

1. **Shared Core**: All AI model infrastructure (services, prompting, guardrails) is in `core/` and used by both apps
2. **Mode-Based Configuration**: PromptBuilder and ContentGuard use enums to switch behavior (BEDTIME_STORY vs ASMR, etc.)
3. **Separate Endpoints**: Main app and Studio have separate endpoint files but share the same core services
4. **Unified Database**: Both apps use the same Supabase instance with product-specific tables

## Benefits

- **Code Reuse**: 80% of code shared between products
- **Consistent Quality**: Same AI models and infrastructure
- **Easier Maintenance**: One place to update model logic
- **Faster Development**: Studio leverages existing, tested code
- **Single Deployment**: Can deploy both products from one codebase

