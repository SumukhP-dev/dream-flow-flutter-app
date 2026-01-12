# Fast Story Generation Endpoint

## Overview

The `/api/v1/story/fast` endpoint is optimized for end users who need faster story generation with reduced wait times.

## Optimizations

### 1. Reduced Scene Count
- **Regular endpoint**: Default 4 scenes (can be 1-8)
- **Fast endpoint**: Maximum 2 scenes (automatically capped)
- **Time savings**: ~50% reduction in image generation time (2-4 minutes → 1-2 minutes)

### 2. Shorter Story Length
- **Regular endpoint**: Default 400 words
- **Fast endpoint**: Maximum 300 words (automatically capped)
- **Time savings**: ~25% reduction in story generation time

### 3. Same Quality
- Uses the same AI models
- Same guardrails and safety checks
- Same audio and video quality
- Just fewer images and shorter stories

## Expected Performance

### Regular Endpoint (`/api/v1/story`)
- **Total time**: 3-5 minutes
- **Story generation**: 30-120 seconds
- **Audio synthesis**: 30-60 seconds
- **Image generation**: 2-4 minutes (4 images × 30-60s each)
- **Video stitching**: 10-30 seconds

### Fast Endpoint (`/api/v1/story/fast`)
- **Total time**: 1.5-3 minutes (40-50% faster)
- **Story generation**: 20-90 seconds (shorter stories)
- **Audio synthesis**: 30-60 seconds (same)
- **Image generation**: 1-2 minutes (2 images × 30-60s each)
- **Video stitching**: 10-30 seconds (same)

## Usage

### Request Format

Same as regular endpoint:

```bash
curl -X POST http://localhost:8080/api/v1/story/fast \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A peaceful bedtime story about a sleepy kitten",
    "theme": "calm"
  }'
```

### Automatic Optimizations

The endpoint automatically:
- Caps `num_scenes` at 2 (even if you request more)
- Caps `target_length` at 300 words (even if you request more)

### Example Request

```json
{
  "prompt": "A peaceful story",
  "theme": "calm",
  "num_scenes": 4,      // Will be capped to 2
  "target_length": 500  // Will be capped to 300
}
```

### Response Format

Same as regular endpoint:

```json
{
  "story_text": "...",
  "theme": "calm",
  "assets": {
    "audio": "https://...",
    "video": "https://...",
    "frames": ["https://...", "https://..."]
  },
  "session_id": "..."
}
```

## When to Use

### Use Fast Endpoint (`/api/v1/story/fast`) for:
- ✅ Consumer mobile app (end users)
- ✅ Quick story generation
- ✅ When 1-2 scenes are sufficient
- ✅ When shorter stories are acceptable

### Use Regular Endpoint (`/api/v1/story`) for:
- ✅ Studio/professional use
- ✅ When you need 4+ scenes
- ✅ When you need longer stories (400+ words)
- ✅ When quality over speed is priority

## Integration

### Flutter Consumer App

Update `StoryService` to use the fast endpoint:

```dart
Future<StoryExperience> generateStory(StoryGenerationRequest request) async {
  final uri = Uri.parse('$_baseUrl/api/v1/story/fast');  // Changed to /fast
  // ... rest of the code
}
```

## Testing

Test the fast endpoint:

```bash
cd backend_fastapi
./test_story_quick.sh
```

Or manually:

```bash
curl -X POST http://localhost:8080/api/v1/story/fast \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A peaceful story",
    "theme": "calm"
  }'
```

## Logging

The fast endpoint uses different log event names:
- `story.generate.fast.start`
- `story.generate.fast.model_complete`
- `story.generate.fast.assets_complete`
- `story.generate.fast.success`
- `story.generate.fast.error`

This allows you to track performance differences between regular and fast endpoints.


