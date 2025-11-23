# Dream Flow FastAPI Backend

This backend powers the Dream Flow Flutter frontend by orchestrating a multi-stage pipeline:

1. Convert user prompts + profile context into bedtime stories with Hugging Face text-generation models.
2. Run the story through brand guardrails to keep content soothing and on-brand.
3. Turn the story into narration using open text-to-audio models.
4. Render themed visual scenes with text-to-image models and compile them into a video synchronized with the narration.

## Directory layout

```
backend_fastapi/
├── app/
│   ├── __init__.py
│   ├── config.py
│   ├── main.py
│   ├── schemas.py
│   └── services.py
├── storage/   # generated assets (audio, frames, video)
└── requirements.txt
```

## Getting started

```bash
cd backend_fastapi
python -m venv .venv
. .venv/bin/activate          # PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Create a `.env` file (copy from `.env.example`) or export variables manually:

```bash
# Required
HUGGINGFACE_API_TOKEN=hf_...
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here  # REQUIRED - never commit to repo
BACKEND_URL=http://localhost:8080

# Optional (defaults provided)
STORY_MODEL=meta-llama/Llama-3.2-1B-Instruct
TTS_MODEL=suno/bark-small
IMAGE_MODEL=black-forest-labs/FLUX.1-schnell
MAX_NEW_TOKENS=512
ASSET_DIR=./storage
```

**Important:** The `SUPABASE_SERVICE_ROLE_KEY` is required and must be provided via environment variable or Azure Key Vault. The application will fail to start if this key is missing. In production, inject this secret via your CI/CD pipeline - never commit it to the repository.

See `.env.example` for a complete template. For CI/CD configuration details, see [CONFIGURATION.md](../CONFIGURATION.md#cicd-secret-injection).

Finally, run the API:

```bash
uvicorn app.main:app --reload --port 8080
```

## API

`POST /api/v1/story`

```json
{
  "prompt": "A child astronaut exploring a candy galaxy.",
  "theme": "Galactic pastel",
  "target_length": 400,
  "voice": "alloy",
  "num_scenes": 4,
  "profile": {
    "mood": "Sleepy and hopeful",
    "routine": "Warm bath then story time",
    "preferences": ["space travel", "friendship"],
    "favorite_characters": ["Nova the fox"],
    "calming_elements": ["starlight", "lavender", "soft clouds"]
  }
}
```

Response:

```json
{
  "story_text": "...",
  "theme": "Galactic pastel",
  "assets": {
    "audio": "/assets/audio/<file>.wav",
    "video": "/assets/video/<file>.mp4",
    "frames": ["/assets/frames/<file>.png", "..."]
  }
}
```

### Health check

`GET /health` returns the configured story model and status flag.

## Frontend consumption

- `video` URL can be loaded directly inside the Flutter app’s video player.
- `frames` array can be shown as a themed gallery while the video streams.
- `audio` URL allows audio-only playback for low-bandwidth modes.

## Guardrails configuration

- Guardrail thresholds now live in `config/guardrails.yaml`. Update the default `banned_terms` and tone limits there without touching any Python.
- Each profile entry (keyed by mood, routine, or even a preference string) can override `banned_terms` and `tone_thresholds`.
- The FastAPI process auto-reloads this YAML on the next request whenever the file changes—no redeploy or restart needed.

## Notes

- Prompt orchestration aligns story, narration, and visuals with the same profile-aware instructions, while the guardrail pass blocks off-brand content before assets are generated.
- All models referenced are available for free usage on the Hugging Face Inference API tier.
- For local GPU execution you can swap the model IDs with lighter checkpoints (e.g., `google/flan-t5-base`, `runwayml/stable-diffusion-v1-5`).
- Videos are synthesized by compositing Hugging Face generated frames with narration using MoviePy.


