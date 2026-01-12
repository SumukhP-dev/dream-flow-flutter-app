# Local Backend Service

## Overview

The local backend service allows the Dream Flow app to run entirely on-device without requiring an external backend server. The backend runs as an HTTP server on `127.0.0.1:8080` within the Flutter app.

## Architecture

The `LocalBackendService` class implements a lightweight HTTP server using Dart's `dart:io` HttpServer. It provides the same API endpoints as the Python FastAPI backend, allowing the Flutter app to work without modification.

## Features

- **On-device HTTP server**: Runs on localhost (127.0.0.1:8080)
- **Core API endpoints**: 
  - `/health` - Health check
  - `/api/v1/story` - Story generation
  - `/api/v1/story/fast` - Fast story generation
  - `/api/v1/history` - Session history
  - `/api/v1/presets` - Story presets
  - `/assets/*` - Static asset serving (audio, frames, video)

- **Local asset storage**: Stores generated assets (audio, images, video) in the app's documents directory

## Usage

The local backend is automatically started when the app launches (see `main.dart`). The `StoryService` and other services will connect to `http://127.0.0.1:8080` by default.

### Configuration

To use an external backend instead of the local one, set the `BACKEND_URL` environment variable:

```dart
flutter run --dart-define=BACKEND_URL=https://your-backend.com
```

## Implementation Notes

### Current Implementation (Placeholder)

The current implementation includes placeholder logic for:
- **Story generation**: Returns simple template stories
- **Image generation**: Creates placeholder image files
- **Audio generation**: Creates placeholder audio files

### Future Enhancements

To make the local backend fully functional, you would need to:

1. **Story Generation**: 
   - Integrate with HuggingFace API directly from Dart
   - Or use on-device LLM models (requires additional packages)
   - Or use Flutter plugins for AI inference

2. **Image Generation**:
   - Call HuggingFace image generation API from Dart
   - Or use on-device image generation models

3. **Audio Generation**:
   - Integrate Edge TTS or similar TTS service
   - Or use Flutter TTS plugins for on-device synthesis

4. **Data Persistence**:
   - Implement local database (SQLite) for history
   - Sync with Supabase when online (optional)

## Benefits

- **No external server required**: App works completely offline
- **Privacy**: All processing happens on-device
- **Faster development**: No need to deploy backend changes
- **Reduced costs**: No backend hosting costs

## Limitations

- **Current implementation is a placeholder**: Needs real AI integration
- **Device resources**: Heavy AI operations may be limited by device capabilities
- **Storage**: Large models and assets consume device storage

## Testing

To test the local backend:

1. Run the app normally
2. Check logs for "Local backend server started on http://127.0.0.1:8080"
3. The app should work without network connectivity (after initial setup)
4. Story generation will use placeholder content until AI integration is added

