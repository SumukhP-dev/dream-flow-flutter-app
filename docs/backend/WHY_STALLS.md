# Why Story Generation Tests Stall

## Common Causes

The story generation endpoint can take **2-5 minutes** to complete because it performs multiple sequential operations:

### 1. Story Text Generation (30-120 seconds)
- Calls Hugging Face API to generate story text
- Uses `chat_completion` for conversational models
- Can be slow if:
  - API is queued/busy
  - Network latency
  - Model loading time on provider side

### 2. Audio Synthesis (30-60 seconds)
- Generates narration audio from story text
- Calls `text_to_speech` API
- Can be slow if:
  - Audio generation is computationally intensive
  - API provider is busy

### 3. Image Generation (30-60 seconds per image)
- Generates multiple visual frames (default: 4 scenes)
- Each image takes 30-60 seconds
- Total: **2-4 minutes for all images**
- This is often the **slowest part**

### 4. Video Stitching (10-30 seconds)
- Combines audio and images into video
- Happens locally but can take time

## Total Expected Time

- **Minimum**: ~2 minutes (fast API, good network)
- **Typical**: 3-5 minutes
- **Maximum**: 5-10 minutes (slow API, network issues)

## How to Diagnose

### 1. Check Server Logs

Watch the server terminal output. You should see logs like:
```
INFO: story.generate.start
INFO: story.generate.model_complete (duration_ms: 45000)
INFO: story.generate.assets_complete (duration_ms: 120000)
```

### 2. Test with Timeout

Use the test script with a timeout:
```bash
cd backend_fastapi
./test_story_quick.sh
```

### 3. Test Individual Steps

You can test just the story generation (without audio/images) by modifying the request, but the current API always generates all assets.

### 4. Check Network/API Status

The Hugging Face API might be:
- Queued (many requests ahead)
- Slow (provider issues)
- Rate-limited (too many requests)

## Solutions

### Option 1: Wait It Out
The request is likely still processing. Wait 3-5 minutes and check if it completes.

### Option 2: Reduce Image Count
Edit your request to generate fewer images:
```json
{
  "prompt": "...",
  "theme": "calm",
  "num_scenes": 1
}
```

### Option 3: Use Local Inference
If you have `LOCAL_INFERENCE=true`, it might be faster:
- Local models don't depend on API speed
- No network latency
- But might be slower on CPU-only systems

### Option 4: Add Progress Logging
The server already logs progress. Watch the terminal where uvicorn is running to see which step is taking time.

### Option 5: Test Health Endpoint First
Make sure the server is responsive:
```bash
curl http://localhost:8080/health
```

## Quick Test Command

```bash
# Test with verbose output and timeout
timeout 300 curl -X POST http://localhost:8080/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A very short story",
    "theme": "calm",
    "target_length": 100,
    "num_scenes": 1
  }' \
  -v
```

This will:
- Show verbose output
- Timeout after 5 minutes
- Use shorter story and fewer images

## If It's Actually Hanging

If the request doesn't complete after 5-10 minutes, it might be:

1. **Network issue**: Check internet connection
2. **API error**: Check server logs for errors
3. **Deadlock**: Check if server process is still running
4. **Memory issue**: Check if server ran out of memory

Check server status:
```bash
ps aux | grep uvicorn
```

Check server logs in the terminal where you started uvicorn.

