# Dream Flow FastAPI Backend

This backend powers the Dream Flow Flutter frontend by orchestrating a multi-stage pipeline:

1. Convert user prompts + profile context into bedtime stories (cloud or local LLMs such as Ollama).
2. Run the story through brand guardrails to keep content soothing and on-brand.
3. Turn the story into narration using text-to-audio models (Edge TTS in-process, with a silent-audio fallback if needed).
4. Render themed visual scenes with text-to-image models and return them as **image frames**, which the frontend can display as a slideshow and, optionally, stitch into a simple video.

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

Response (conceptual):

```json
{
  "story_text": "...",
  "theme": "Galactic pastel",
  "assets": {
    "audio": "/assets/audio/<file>.wav",              // may be empty if TTS fails
    "video": "/assets/video/<file>.mp4",              // optional, may be empty
    "frames": ["/assets/frames/<file>.png", "..."]    // primary visual layer (slideshow)
  }
}
```

### Health check

`GET /health` returns the configured story model and status flag.

## Frontend consumption

- **Images first**: the `frames` array is the default visual experience. The Flutter app can:
  - Show frames as a gallery or auto-advancing slideshow.
  - Sync frame changes roughly to the narration for a calm “storybook” feel.
- **Audio**:
  - `audio` URL is used for narration; if empty, the app should gracefully hide/disable audio controls.
- **Video (optional layer)**:
  - `video` URL is optional and may be empty.
  - When present, it can be loaded in the Flutter app’s video player, but the core UX should not depend on it.

## Guardrails configuration

- Guardrail thresholds now live in `config/guardrails.yaml`. Update the default `banned_terms` and tone limits there without touching any Python.
- Each profile entry (keyed by mood, routine, or even a preference string) can override `banned_terms` and `tone_thresholds`.
- The FastAPI process auto-reloads this YAML on the next request whenever the file changes—no redeploy or restart needed.

## Notes

- Prompt orchestration aligns story, narration, and visuals with the same profile-aware instructions, while the guardrail pass blocks off-brand content before assets are generated.
- All models referenced are available for free usage on the Hugging Face Inference API tier.
- For local GPU execution you can swap the model IDs with lighter checkpoints (e.g., `google/flan-t5-base`, `runwayml/stable-diffusion-v1-5`).
- Videos are synthesized by compositing Hugging Face generated frames with narration using MoviePy.


