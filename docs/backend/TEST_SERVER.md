# Testing the Backend Server

This guide shows you how to test your Dream Flow backend server.

## Quick Test

Run the automated test script:

```bash
cd backend_fastapi
./test_server.sh
```

## Manual Testing

### 1. Check if Server is Running

```bash
# Check if the server process is running
ps aux | grep uvicorn

# Or check if port 8080 is listening
lsof -i :8080
# or
netstat -tuln | grep 8080
```

### 2. Health Check

Test the basic health endpoint:

```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "ok",
  "apps": ["dreamflow", "studio"]
}
```

### 3. API Documentation

Open in your browser:
- **Swagger UI**: http://localhost:8080/docs
- **ReDoc**: http://localhost:8080/redoc

These provide interactive API documentation where you can test endpoints directly.

### 4. Test Story Generation

#### Using curl:

```bash
curl -X POST http://localhost:8080/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A peaceful bedtime story about a sleepy kitten",
    "theme": "calm",
    "user_profile": {
      "age": 5,
      "interests": ["animals", "nature"],
      "preferred_length": "short"
    }
  }'
```

#### Using Python:

```python
import requests

response = requests.post(
    "http://localhost:8080/api/v1/story",
    json={
        "prompt": "A peaceful bedtime story about a sleepy kitten",
        "theme": "calm",
        "user_profile": {
            "age": 5,
            "interests": ["animals", "nature"],
            "preferred_length": "short"
        }
    }
)

print(response.status_code)
print(response.json())
```

### 5. Test Other Endpoints

#### Get Story Presets:
```bash
curl http://localhost:8080/api/v1/presets
```

#### Get Story History (requires authentication):
```bash
curl http://localhost:8080/api/v1/history \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 6. Test with Browser

1. **Health Check**: Open http://localhost:8080/health in your browser
2. **API Docs**: Open http://localhost:8080/docs for interactive testing
3. **Test HTML Page**: If you have `test_backend.html`, open it in your browser

## Common Issues

### Server Not Responding

1. **Check if server is running**:
   ```bash
   ps aux | grep uvicorn
   ```

2. **Check server logs** for errors

3. **Verify port 8080 is not in use**:
   ```bash
   lsof -i :8080
   ```

### 503 Service Unavailable

- This might occur if:
  - Hugging Face API token is missing
  - Local inference models are not downloaded
  - Supabase is not configured

Check your `.env` file for required credentials.

### Connection Refused

- Make sure the server is running
- Check the host and port (should be `0.0.0.0:8080` or `localhost:8080`)
- Verify firewall settings

## Advanced Testing

### Load Testing with Locust (if installed):

```bash
cd backend_fastapi
locust -f tests/locustfile.py --host=http://localhost:8080
```

### Automated Test Suite:

```bash
cd backend_fastapi
pytest tests/ -v
```

## Testing Checklist

- [ ] Server starts without errors
- [ ] Health endpoint returns 200 OK
- [ ] API docs are accessible at /docs
- [ ] Story generation endpoint works
- [ ] Presets endpoint returns data
- [ ] CORS is configured (for frontend access)
- [ ] Error handling works correctly

## Next Steps

After confirming the server works:
1. Test with your Flutter frontend apps
2. Verify Supabase integration (if configured)
3. Test local inference (if using LOCAL_INFERENCE=true)
4. Monitor server logs for any issues

