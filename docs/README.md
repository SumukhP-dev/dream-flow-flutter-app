# Docker Local Development Stack

This directory contains Docker configuration for running the Dream Flow application locally with all services.

## Overview

The `docker-compose.yml` at the project root sets up:

1. **FastAPI Backend** (`api`) - Main application server
2. **Mock HuggingFace Service** (`mock-hf`) - Simulates HuggingFace Inference API
3. **Supabase PostgreSQL** (`supabase-db`) - Database
4. **Supabase Auth** (`supabase-auth`) - Authentication service
5. **Supabase Storage** (`supabase-storage`) - File storage
6. **Supabase Kong** (`supabase-kong`) - API gateway

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB of free disk space
- Ports available: 8080, 8000, 8001, 5000, 54322, 9999

## Quick Start

1. **Create environment file** (optional, for custom configuration):
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

2. **Start all services**:
   ```bash
   docker-compose up -d
   ```

3. **Check service status**:
   ```bash
   docker-compose ps
   ```

4. **View logs**:
   ```bash
   docker-compose logs -f api
   ```

5. **Stop all services**:
   ```bash
   docker-compose down
   ```

## Service URLs

- **API**: http://localhost:8080
- **Supabase (via Kong)**: http://localhost:8000
- **Mock HuggingFace**: http://localhost:8001
- **PostgreSQL**: localhost:54322
- **Auth**: http://localhost:9999
- **Storage**: http://localhost:5000

## Environment Variables

Key environment variables (can be set in `.env` file):

```bash
# Database
POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password
POSTGRES_DB=postgres
POSTGRES_USER=postgres
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long

# Supabase Keys (defaults provided for local dev)
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# HuggingFace (for mock service)
HUGGINGFACE_API_TOKEN=mock_token

# Models (optional)
STORY_MODEL=meta-llama/Llama-3.2-1B-Instruct
TTS_MODEL=suno/bark-small
IMAGE_MODEL=black-forest-labs/FLUX.1-schnell
```

## Database Migrations

Migrations are automatically applied when the database container starts. They are located in `backend_supabase/supabase/migrations/` and are mounted into the PostgreSQL container's initialization directory.

## Mock HuggingFace Service

The mock service simulates the HuggingFace Inference API for local development. It supports:
- Text generation (story models)
- Text-to-audio (TTS models)
- Text-to-image (image models)

**Note**: The mock service returns simplified mock data. For production-like behavior, use real HuggingFace API tokens.

**Important**: The `InferenceClient` from `huggingface_hub` uses the official HuggingFace API endpoints (`https://api-inference.huggingface.co`). To use the mock service, you have two options:

1. **Use real HuggingFace API** (recommended for testing): Set `HUGGINGFACE_API_TOKEN` to a real token in your `.env` file
2. **Modify services for local mock**: Update `backend_fastapi/app/services.py` to use httpx directly when `HUGGINGFACE_API_URL` is set to `http://mock-hf:8001`

For now, the mock service is available at `http://localhost:8001` but the API will use the real HuggingFace API unless modified.

## Troubleshooting

### Services won't start
- Check if ports are already in use: `netstat -an | grep <port>`
- Check Docker logs: `docker-compose logs <service-name>`
- Ensure Docker has enough resources allocated

### Database connection issues
- Wait for database to be healthy: `docker-compose ps supabase-db`
- Check database logs: `docker-compose logs supabase-db`

### Migration errors
- Ensure migration files are in correct order (by timestamp)
- Check database logs for specific SQL errors

### Storage issues
- Check storage volume: `docker volume inspect dream-flow_supabase-storage-data`
- Ensure storage service is running: `docker-compose ps supabase-storage`

## Data Persistence

Data is persisted in Docker volumes:
- `supabase-db-data`: PostgreSQL data
- `supabase-storage-data`: File storage data

To remove all data:
```bash
docker-compose down -v
```

## Development Workflow

1. Make code changes in `backend_fastapi/`
2. Rebuild the API container:
   ```bash
   docker-compose build api
   docker-compose up -d api
   ```
3. Or use volume mounts for live reload (already configured for `storage/` and `config/`)

## Production Notes

This setup is for **local development only**. For production:
- Use managed Supabase instance
- Use real HuggingFace API tokens
- Configure proper security settings
- Use production-grade database backups
- Set up proper monitoring and logging

