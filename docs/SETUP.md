# Setup Guide

This guide will help you set up Dream Flow for local development.

## Prerequisites

- **Python 3.10+**: [Download](https://www.python.org/downloads/)
- **Node.js 18+**: [Download](https://nodejs.org/)
- **pnpm 8+**: `npm install -g pnpm`
- **Flutter 3.6+**: [Download](https://flutter.dev/docs/get-started/install)
- **Supabase Account**: [Sign up](https://supabase.com/)
- **Hugging Face Account**: [Sign up](https://huggingface.co/)

## Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/dream-flow.git
cd dream-flow
```

## Step 2: Backend Setup

### 2.1 Create Virtual Environment

```bash
cd backend_fastapi
python -m venv .venv

# Windows PowerShell
.\.venv\Scripts\Activate.ps1

# Windows CMD
.venv\Scripts\activate

# Linux/Mac
source .venv/bin/activate
```

### 2.2 Install Dependencies

```bash
pip install -r requirements.txt
```

### 2.3 Configure Environment

Create `.env` file in `backend_fastapi/`:

```bash
# Required
HUGGINGFACE_API_TOKEN=your_huggingface_token
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
BACKEND_URL=http://localhost:8080

# Optional (defaults provided)
STORY_MODEL=meta-llama/Llama-3.2-1B-Instruct
TTS_MODEL=suno/bark-small
IMAGE_MODEL=black-forest-labs/FLUX.1-schnell
MAX_NEW_TOKENS=512
LOCAL_INFERENCE=false
```

### 2.4 Start Backend

```bash
uvicorn app.main:app --reload --port 8080
```

Verify: http://localhost:8080/health

## Step 3: Web App Setup

### 3.1 Install Dependencies

```bash
pnpm install
```

### 3.2 Configure Environment

Create `.env.local` in `dream-flow-app/website/`:

```bash
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
NEXT_PUBLIC_BACKEND_URL=http://localhost:8080
```

### 3.3 Start Web App

```bash
cd dream-flow-app/website
pnpm dev
```

App available at: http://localhost:3000

## Step 4: Mobile App Setup

### 4.1 Install Flutter Dependencies

```bash
cd dream-flow-app/app
flutter pub get
```

### 4.2 Configure Environment

Update `lib/core/config.dart` with your backend URL and Supabase credentials.

### 4.3 Run Mobile App

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Web
flutter run -d chrome
```

## Step 5: Supabase Setup

1. Create a new project at [supabase.com](https://supabase.com/)
2. Run migrations from `backend_supabase/migrations/`
3. Configure Row Level Security (RLS) policies
4. Set up authentication providers

## Step 6: Hugging Face Setup

1. Create account at [huggingface.co](https://huggingface.co/)
2. Generate API token from Settings
3. Add token to backend `.env` file

## Troubleshooting

### Backend Issues

**Port already in use:**

```bash
# Change port
uvicorn app.main:app --reload --port 8081
```

**Missing dependencies:**

```bash
pip install -r requirements.txt --upgrade
```

**Supabase connection errors:**

- Verify credentials in `.env`
- Check Supabase project is active
- Verify RLS policies are configured

### Web App Issues

**Port 3000 in use:**

```bash
# Change port
pnpm dev -- -p 3001
```

**Build errors:**

```bash
# Clear cache
rm -rf .next node_modules
pnpm install
```

### Mobile App Issues

**Flutter dependencies:**

```bash
flutter clean
flutter pub get
```

**iOS build issues:**

```bash
cd ios
pod install
cd ..
flutter run
```

## Verification

1. **Backend Health**: http://localhost:8080/health
2. **API Docs**: http://localhost:8080/docs
3. **Web App**: http://localhost:3000
4. **Mobile App**: Run on device/emulator

## Next Steps

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Check [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines
- Review API documentation at `/docs` endpoint
