# Configuration Guide

This guide explains how to configure environment variables for the Dream Flow application across the backend and frontend.

## Backend Configuration (FastAPI)

The backend uses a `.env` file for configuration. Copy `.env.example` to `.env` and fill in your values:

```bash
cd backend_fastapi
cp .env.example .env
# Edit .env with your actual values
```

### Required Environment Variables

- `SUPABASE_URL`: Your Supabase project URL (e.g., `https://xxxxx.supabase.co`)
- `SUPABASE_ANON_KEY`: Your Supabase anonymous key (public key)
- `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (for admin operations)
- `BACKEND_URL`: The URL where the backend API is accessible (e.g., `http://localhost:8080` or `https://api.example.com`)
- `HUGGINGFACE_API_TOKEN`: Your Hugging Face API token for model inference

### Optional Environment Variables

- `STORY_MODEL`: Hugging Face model ID for story generation (default: `meta-llama/Llama-3.2-1B-Instruct`)
- `TTS_MODEL`: Text-to-speech model ID (default: `suno/bark-small`)
- `IMAGE_MODEL`: Image generation model ID (default: `black-forest-labs/FLUX.1-schnell`)
- `MAX_NEW_TOKENS`: Maximum tokens for story generation (default: `512`)
- `ASSET_DIR`: Directory for storing generated assets (default: `./storage`)

The backend automatically loads these from the `.env` file via `python-dotenv` in `app/config.py`.

## Frontend Configuration (Flutter)

The Flutter app uses `--dart-define` flags to pass configuration at compile time. This is more secure than hardcoding values and allows different configurations for different environments.

### Running with Configuration

#### Development (Local Backend)

```bash
cd frontend_flutter

# Run with dart-define flags
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here \
  --dart-define=BACKEND_URL=http://10.0.2.2:8080
```

**Note:** For Android emulator, use `http://10.0.2.2:8080` to access `localhost:8080` on your host machine. For iOS simulator, use `http://localhost:8080`.

#### Production (Remote Backend)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here \
  --dart-define=BACKEND_URL=https://api.example.com
```

### Building with Configuration

#### Android

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here \
  --dart-define=BACKEND_URL=https://api.example.com
```

#### iOS

```bash
flutter build ios \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here \
  --dart-define=BACKEND_URL=https://api.example.com
```

#### Web

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here \
  --dart-define=BACKEND_URL=https://api.example.com
```

### Configuration Files

The following files use these environment variables:

1. **`lib/main.dart`**: Initializes Supabase with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
2. **`lib/services/story_service.dart`**: Uses `BACKEND_URL` to connect to the FastAPI backend

### Using a Configuration Script (Optional)

To avoid typing long commands, you can create a script:

**Windows (PowerShell) - `run-dev.ps1`:**

```powershell
flutter run `
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="your-anon-key-here" `
  --dart-define=BACKEND_URL="http://10.0.2.2:8080"
```

**macOS/Linux (Bash) - `run-dev.sh`:**

```bash
#!/bin/bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here \
  --dart-define=BACKEND_URL=http://10.0.2.2:8080
```

Make the script executable: `chmod +x run-dev.sh`

## Getting Your Supabase Credentials

1. Go to your [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon/public key** → `SUPABASE_ANON_KEY`
   - **service_role key** → `SUPABASE_SERVICE_ROLE_KEY` (keep this secret!)

## Security Notes

- **Never commit `.env` files** to version control
- **Never commit** `--dart-define` values in scripts that are committed
- The `SUPABASE_ANON_KEY` is safe to include in client-side code (it's designed for public use)
- The `SUPABASE_SERVICE_ROLE_KEY` should **only** be used in backend/server code and never exposed to clients
- Use environment-specific values (development vs production)

## CI/CD Secret Injection

The `SUPABASE_SERVICE_ROLE_KEY` is **required** and must be injected via CI/CD pipeline secrets or deployment environment variables. The application will fail to start if this key is missing.

### How the Service Role Key is Loaded

The backend loads the service-role key in the following priority order:

1. **Environment Variable** (Primary method for CI/CD)
   - Variable name: `SUPABASE_SERVICE_ROLE_KEY`
   - Recommended for: GitHub Actions, Azure DevOps, Docker, Kubernetes, etc.

2. **Azure Key Vault** (Optional fallback for Azure deployments)
   - Requires: `AZURE_KEY_VAULT_URL` environment variable
   - Optional: `AZURE_KEY_VAULT_SECRET_NAME` (defaults to `supabase-service-role-key`)
   - Requires: `azure-keyvault-secrets` and `azure-identity` packages
   - Authentication: Uses Managed Identity, Service Principal, or DefaultAzureCredential

### CI/CD Configuration Examples

#### GitHub Actions

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to production
        env:
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
          HUGGINGFACE_API_TOKEN: ${{ secrets.HUGGINGFACE_API_TOKEN }}
        run: |
          # Your deployment commands here
```

#### Azure DevOps

```yaml
variables:
  - group: production-secrets  # Variable group with secrets

steps:
  - script: |
      # Your deployment commands
    env:
      SUPABASE_SERVICE_ROLE_KEY: $(SUPABASE_SERVICE_ROLE_KEY)
      SUPABASE_URL: $(SUPABASE_URL)
```

#### Docker / Docker Compose

```yaml
# docker-compose.yml
services:
  backend:
    build: ./backend_fastapi
    environment:
      - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
      - SUPABASE_URL=${SUPABASE_URL}
      # ... other variables
```

**Important:** Never hardcode the service-role key in Dockerfiles or compose files. Use environment variable substitution.

#### Kubernetes

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: supabase-secrets
type: Opaque
stringData:
  SUPABASE_SERVICE_ROLE_KEY: <your-key-here>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  template:
    spec:
      containers:
      - name: backend
        envFrom:
        - secretRef:
            name: supabase-secrets
```

#### Azure App Service / Container Apps

For Azure deployments, you can use Azure Key Vault:

1. Store the secret in Azure Key Vault
2. Set environment variables:
   - `AZURE_KEY_VAULT_URL=https://your-vault.vault.azure.net/`
   - `AZURE_KEY_VAULT_SECRET_NAME=supabase-service-role-key` (optional)
3. Ensure the app has proper authentication (Managed Identity recommended)

### Failure Behavior

If the `SUPABASE_SERVICE_ROLE_KEY` is missing, the application will **fail fast** at startup with a clear error message:

```
ValueError: SUPABASE_SERVICE_ROLE_KEY is required but not found. 
This key must be provided via:
  - Environment variable SUPABASE_SERVICE_ROLE_KEY (recommended for CI/CD)
  - Azure Key Vault (set AZURE_KEY_VAULT_URL and optionally AZURE_KEY_VAULT_SECRET_NAME)

The service-role key MUST NEVER be committed to the repository. 
Configure it in your CI/CD pipeline secrets or deployment environment.
```

This ensures that misconfigurations are caught immediately rather than causing runtime errors.

## Troubleshooting

### Frontend: "Missing required configuration" error

This means `SUPABASE_URL` or `SUPABASE_ANON_KEY` are not provided via `--dart-define`. Make sure you're passing both flags when running or building.

### Backend: Cannot connect to Supabase

1. Verify your `.env` file exists in `backend_fastapi/`
2. Check that `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set correctly
3. Ensure there are no extra spaces or quotes in your `.env` file values

### Story Service: Cannot reach backend

1. Verify `BACKEND_URL` is set correctly via `--dart-define`
2. For Android emulator, use `http://10.0.2.2:8080` (not `localhost`)
3. For iOS simulator, use `http://localhost:8080`
4. Ensure the backend is running and accessible at the specified URL

