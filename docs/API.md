# Dream Flow API Documentation

## Base URL

```
http://localhost:8080
```

## Authentication

Most endpoints require authentication via Supabase JWT tokens. Include the token in the Authorization header:

```
Authorization: Bearer <your_jwt_token>
```

## Endpoints

### Health Check

**GET** `/health`

Check if the API is running.

**Response:**

```json
{
  "status": "ok",
  "apps": ["dreamflow", "studio"]
}
```

### Generate Story

**POST** `/api/v1/story`

Generate a personalized bedtime story.

**Request Body:**

```json
{
  "prompt": "A peaceful bedtime story about a sleepy kitten",
  "theme": "Calm Focus",
  "target_length": 400,
  "num_scenes": 4,
  "voice": "alloy",
  "profile": {
    "mood": "Sleepy and hopeful",
    "routine": "Warm bath then story time",
    "preferences": ["animals", "nature"],
    "favorite_characters": [],
    "calming_elements": ["starlight", "soft clouds"]
  },
  "language": "en",
  "child_mode": false
}
```

**Response:**

```json
{
  "session_id": "uuid",
  "story_text": "Once upon a time...",
  "theme": "Calm Focus",
  "assets": {
    "audio": "/assets/audio/story.wav",
    "video": "/assets/video/story.mp4",
    "frames": ["/assets/frames/frame1.png", "/assets/frames/frame2.png"]
  }
}
```

### Stream Story Generation

**POST** `/api/v1/story/stream`

Stream story text as it's generated (Server-Sent Events).

**Request Body:** Same as `/api/v1/story`

**Response:** Server-Sent Events stream

```
data: {"type": "text", "delta": "Once"}
data: {"type": "text", "delta": " upon"}
data: {"type": "done"}
```

### Get Story Presets

**GET** `/api/v1/presets`

Get available story themes and presets.

**Response:**

```json
{
  "themes": [
    {
      "title": "Calm Focus",
      "description": "Soothing stories for relaxation",
      "emoji": "🌿"
    }
  ],
  "featured": ["Calm Focus", "Cozy Family"]
}
```

### Get Story History

**GET** `/api/v1/history`

Get user's story history (requires authentication).

**Query Parameters:**

- `limit` (optional): Number of stories to return (default: 20)
- `offset` (optional): Pagination offset (default: 0)

**Response:**

```json
{
  "sessions": [
    {
      "session_id": "uuid",
      "theme": "Calm Focus",
      "prompt": "A peaceful story",
      "created_at": "2025-01-01T00:00:00Z",
      "thumbnail_url": "/assets/frames/thumb.png"
    }
  ],
  "total": 10
}
```

### Get Session Details

**GET** `/api/v1/session/{session_id}`

Get details for a specific story session.

**Response:**

```json
{
  "session_id": "uuid",
  "story_text": "Full story text...",
  "theme": "Calm Focus",
  "assets": {
    "audio": "/assets/audio/story.wav",
    "video": "/assets/video/story.mp4",
    "frames": ["/assets/frames/frame1.png"]
  },
  "created_at": "2025-01-01T00:00:00Z"
}
```

### Subscription Management

**GET** `/api/v1/subscription`

Get user's subscription status (requires authentication).

**Response:**

```json
{
  "tier": "premium",
  "status": "active",
  "quota": {
    "stories_used": 5,
    "stories_limit": -1
  }
}
```

**POST** `/api/v1/subscription`

Create or update subscription.

**POST** `/api/v1/subscription/cancel`

Cancel subscription.

## Error Responses

All errors follow this format:

```json
{
  "detail": "Error message",
  "error": "ERROR_CODE"
}
```

**Common Status Codes:**

- `200` - Success
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `500` - Internal Server Error
- `503` - Service Unavailable

## Rate Limiting

Rate limits are based on subscription tier:

- **Free**: 3 stories per week
- **Premium**: Unlimited
- **Family**: Unlimited (up to 5 users)

## Interactive Documentation

Visit http://localhost:8080/docs for interactive Swagger UI documentation where you can test endpoints directly.
