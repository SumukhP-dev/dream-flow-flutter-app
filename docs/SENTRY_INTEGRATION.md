# Sentry Integration Guide

This document describes the Sentry error tracking and analytics integration for the Dream Flow application.

## Overview

Sentry has been integrated across both the Flutter frontend and FastAPI backend to capture:
- Crashes and exceptions
- Guardrail violations
- Session IDs for context tracking

## Frontend (Flutter) Integration

### Configuration

1. **Dependencies**: Added `sentry_flutter: ^8.0.0` to `pubspec.yaml`

2. **Environment Variables**:
   - `SENTRY_DSN`: Sentry DSN for error tracking (optional - if not provided, Sentry is disabled)
   - `ENVIRONMENT`: Environment name (defaults to "development")

3. **Initialization**: Sentry is initialized in `lib/main.dart` before Supabase initialization

### Usage

#### Setting Session ID Context

Use `SentryService` to set session IDs when they become available:

```dart
import '../services/sentry_service.dart';

// Set session ID when story is generated
if (experience.sessionId != null) {
  await SentryService.setSessionId(experience.sessionId);
}
```

#### Capturing Exceptions

```dart
try {
  // Your code
} catch (error) {
  await SentryService.captureException(
    error,
    sessionId: sessionId, // Optional
    extra: {'additional': 'context'},
  );
}
```

#### Capturing Messages

```dart
await SentryService.captureMessage(
  'Important event occurred',
  sessionId: sessionId, // Optional
  level: SentryLevel.warning,
);
```

### Automatic Context

- User context is automatically set from Supabase auth when available
- Session IDs are set in `SessionScreen` when a session is loaded
- Session IDs are set in `HomeScreen` when a story is generated

## Backend (FastAPI) Integration

### Configuration

1. **Dependencies**: Added `sentry-sdk[fastapi]==2.15.0` to `requirements.txt`

2. **Environment Variables** (in `app/config.py`):
   - `SENTRY_DSN`: Sentry DSN for error tracking (optional)
   - `SENTRY_ENVIRONMENT`: Environment name (defaults to "development")
   - `SENTRY_TRACES_SAMPLE_RATE`: Performance monitoring sample rate (defaults to 0.2)

3. **Initialization**: Sentry is initialized in `app/main.py` in the `create_app()` function

### Features

#### Request Middleware

The `RequestContextMiddleware` automatically:
- Captures request IDs and prompt IDs in Sentry context
- Sets session IDs in Sentry context when available in request state
- Captures all unhandled exceptions with full context

#### Guardrail Violation Tracking

Guardrail violations are automatically captured with:
- Violation count and categories
- Content type (story, narration, visual, prompt)
- Session ID (when available)
- User ID (when available)
- Request ID and prompt ID

#### Session ID Context

Session IDs are automatically captured:
- From request body in `/api/v1/feedback` endpoint
- After session creation in `/api/v1/story` endpoint
- Stored in `request.state.session_id` for middleware access

### Manual Exception Capture

```python
import sentry_sdk

# Capture exception with session context
with sentry_sdk.push_scope() as scope:
    scope.set_tag("session_id", str(session_id))
    scope.set_context("session", {"id": str(session_id)})
    sentry_sdk.capture_exception(exception)
```

## Testing

### Disable Sentry (Development)

If you don't want to use Sentry during development:
- **Flutter**: Don't provide `SENTRY_DSN` via `--dart-define`
- **FastAPI**: Don't set `SENTRY_DSN` environment variable

Sentry will be disabled gracefully without errors.

### Verify Integration

1. **Flutter**: Check that Sentry initializes without errors in console
2. **FastAPI**: Check logs for "Sentry initialized for environment: ..." message
3. **Test Error Capture**: Trigger a guardrail violation or exception and verify it appears in Sentry dashboard

## Session ID Tracking

Session IDs are tracked in the following scenarios:

1. **Story Generation**: Session ID is set when a story is successfully generated
2. **Session Screen**: Session ID is set when a session screen is loaded
3. **Feedback Submission**: Session ID is captured from request body
4. **Guardrail Violations**: Session ID is included when available (may not be available if violations occur before session creation)

## Best Practices

1. **Always set session IDs** when they become available using `SentryService.setSessionId()`
2. **Capture exceptions** with context using `SentryService.captureException()`
3. **Include relevant context** in error reports (user ID, request ID, etc.)
4. **Use appropriate log levels** (info, warning, error) for different event types

## Environment Setup

### Production

```bash
# Flutter
flutter run --dart-define=SENTRY_DSN=https://your-dsn@sentry.io/project-id --dart-define=ENVIRONMENT=production

# FastAPI
export SENTRY_DSN=https://your-dsn@sentry.io/project-id
export SENTRY_ENVIRONMENT=production
```

### Development

```bash
# Flutter - Sentry disabled if DSN not provided
flutter run

# FastAPI - Sentry disabled if DSN not provided
# No environment variables needed
```

