# Dream Flow Architecture

## Overview

Dream Flow is a full-stack AI-powered bedtime story platform built as a monorepo. The system generates personalized video stories by orchestrating multiple AI models.

## System Architecture

```
┌─────────────────┐
│   Flutter App   │
│   (Mobile)      │
└────────┬────────┘
         │
         │ HTTP/REST
         │
┌────────▼─────────────────┐
│   Next.js Web App         │
│   (Web Dashboard)         │
└────────┬──────────────────┘
         │
         │ HTTP/REST
         │
┌────────▼──────────────────────────┐
│   FastAPI Backend                  │
│   ┌──────────────────────────────┐ │
│   │  Story Generation Pipeline  │ │
│   │  1. LLM (Story Text)        │ │
│   │  2. Guardrails (Safety)     │ │
│   │  3. TTS (Audio)             │ │
│   │  4. Image Gen (Visuals)     │ │
│   └──────────────────────────────┘ │
└────────┬───────────────────────────┘
         │
    ┌────┴────┬──────────┬────────────┐
    │         │          │           │
┌───▼───┐ ┌──▼───┐ ┌────▼────┐ ┌────▼────┐
│Supabase│ │Hugging│ │ Edge   │ │Storage │
│  DB    │ │ Face  │ │  TTS   │ │(Assets)│
└────────┘ └───────┘ └────────┘ └─────────┘
```

## Components

### Backend (`backend_fastapi/`)

**Core Services:**
- `StoryGenerator`: Orchestrates LLM for story text generation
- `NarrationGenerator`: Converts text to audio using TTS
- `VisualGenerator`: Creates image frames using image generation models
- `ContentGuard`: Applies safety guardrails and content filtering

**API Endpoints:**
- `/api/v1/story` - Generate story
- `/api/v1/story/stream` - Stream story generation
- `/api/v1/history` - Get user story history
- `/api/v1/presets` - Get story themes/presets
- `/api/v1/stories/public` - Get public stories (with moderation)
- `/api/v1/stories/{id}/share` - Share story publicly
- `/api/v1/stories/{id}/like` - Like/unlike story
- `/api/v1/stories/{id}/report` - Report inappropriate story
- `/api/v1/subscription` - Subscription management
- `/api/v1/studio/*` - Creator/studio endpoints

**Key Files:**
- `app/main.py` - FastAPI app entry point
- `app/core/services.py` - AI model orchestration
- `app/core/prompting.py` - Prompt engineering
- `app/core/guardrails.py` - Content safety

### Mobile App (`dream-flow-app/app/`)

**Architecture:**
- **State Management**: Provider pattern + SharedPreferences
- **Services**: Auth, Story, Audio, Video services
- **Screens**: Home, Session, Login, Settings, etc.

**Key Features:**
- Offline video caching
- Multi-language support (i18n)
- Accessibility features
- Family mode with child profiles
- Backend-based story sharing (Supabase)
- Public story discovery with content moderation

### Web App (`dream-flow-app/website/`)

**Architecture:**
- **Framework**: Next.js 14 (App Router)
- **State**: Zustand + React Query
- **Styling**: Design system tokens
- **Auth**: Supabase Auth

**Key Features:**
- Server-side rendering (SSR)
- Progressive story loading
- Real-time updates

## Data Flow

### Story Generation Flow

1. **User Input**: Prompt + Profile (mood, routine, preferences)
2. **Story Generation**: LLM generates story text
3. **Content Guardrails**: Safety checks and filtering
4. **Audio Generation**: TTS converts text to narration
5. **Visual Generation**: Image models create scene frames
6. **Video Assembly**: Frames + audio combined (optional)
7. **Response**: Story text + asset URLs returned

### Authentication Flow

1. User authenticates via Supabase Auth
2. JWT token stored in app
3. Token sent with API requests
4. Backend validates token via Supabase
5. User ID extracted for data operations

### Story Sharing Flow

1. **User Shares Story**: Story marked as `is_public` in Supabase `sessions` table
2. **Content Moderation**: Backend runs content guardrails check
3. **Approval**: Story marked as `is_approved` if passes moderation
4. **Public Discovery**: Approved stories available via `/api/v1/stories/public`
5. **Family Sharing**: Stories shared via `family_libraries` table in Supabase
6. **Safety**: Age ratings, reporting, and like tracking all handled by backend

**Architecture Decision**: All story sharing is backend-based (Supabase) for:
- Content moderation and safety compliance
- Centralized control for child safety
- Efficient queries, pagination, and filtering
- Analytics and engagement tracking
- Reliable availability without peer dependencies

## Technology Choices

### Why FastAPI?
- Async support for AI model calls
- Automatic API documentation
- Type safety with Pydantic
- High performance

### Why Flutter?
- Cross-platform (iOS, Android, Web)
- Single codebase
- Native performance
- Rich ecosystem

### Why Next.js?
- Server-side rendering
- Great DX with TypeScript
- Easy deployment (Vercel)
- React ecosystem

### Why Supabase?
- PostgreSQL database
- Built-in authentication
- Row Level Security
- Real-time subscriptions

## Security

- **Authentication**: Supabase JWT tokens
- **Authorization**: Row Level Security (RLS)
- **Content Safety**: Guardrails and content filtering
- **Input Validation**: Pydantic models
- **Secrets**: Environment variables only

## Scalability Considerations

- **AI Models**: Hugging Face Inference API (scalable)
- **Database**: Supabase (managed PostgreSQL)
- **Storage**: Local storage + CDN (future)
- **Caching**: Story caching for repeat requests
- **Rate Limiting**: Subscription-based quotas

## Future Improvements

- CDN for asset delivery
- Redis for caching
- Queue system for batch processing
- WebSocket for real-time updates
- Edge functions for faster responses

