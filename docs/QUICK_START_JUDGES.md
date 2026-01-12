# 🚀 Dream Flow - 2-Minute Quick Start for Judges

**Klaviyo Winter 2026 Hackathon Submission**

Get the app running and see Klaviyo integration in action in under 2 minutes!

---

## Prerequisites Check

```bash
# Check Python version (need 3.11+)
python --version

# Check if pip is installed
pip --version
```

If you don't have Python 3.11+, download from: https://www.python.org/downloads/

---

## Step 1: Get Klaviyo API Key (30 seconds)

1. Go to https://www.klaviyo.com/sign-up
2. Create a free account (or log in)
3. Navigate to: **Settings** → **API Keys**
4. Click "Create Private API Key"
5. Copy the key (starts with `pk_` or similar)

---

## Step 2: Clone & Setup (30 seconds)

```bash
# Clone repository
git clone https://github.com/yourusername/dream-flow-app.git
cd dream-flow-app/backend_fastapi

# Install dependencies
pip install -r requirements.txt

# Create environment file
cat > .env << EOF
KLAVIYO_API_KEY=YOUR_KEY_HERE
KLAVIYO_ENABLED=true
EOF

# Edit .env and paste your actual Klaviyo API key
# On Windows: notepad .env
# On Mac/Linux: nano .env
```

---

## Step 3: Start Backend (10 seconds)

```bash
uvicorn app.main:app --reload --port 8000
```

You should see:

```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete.
```

---

## Step 4: Test Klaviyo Integration (30 seconds)

Open a new terminal and run:

```bash
# Test 1: Check integration status
curl http://localhost:8000/api/v1/demo/klaviyo-integration | python -m json.tool

# Expected: JSON showing all Klaviyo features and API endpoints used
```

```bash
# Test 2: Check MCP architecture
curl http://localhost:8000/api/v1/demo/mcp-status | python -m json.tool

# Expected: JSON showing Model Context Protocol implementation
```

---

## Step 5: Generate a Story & See Klaviyo Magic! (20 seconds)

```bash
# Generate a test story (this triggers Klaviyo events!)
curl -X POST http://localhost:8000/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{
    "theme": "Ocean Adventure",
    "prompt": "A curious dolphin exploring coral reefs",
    "num_scenes": 3,
    "mood": "excited"
  }' | python -m json.tool
```

**Watch your backend terminal!** You'll see:

```
================================================================================
✓ KLAVIYO EVENT TRACKED: Story Generated
  User: ... 
  Properties: {'theme': 'Ocean Adventure', 'story_length': 850, ...}
================================================================================
```

---

## Step 6: Verify in Klaviyo Dashboard (10 seconds)

1. Go to your Klaviyo dashboard
2. Click **Analytics** → **Metrics**
3. Look for "Story Generated" metric
4. Click it to see the event details!

🎉 **You just saw Dream Flow's Klaviyo integration in action!**

---

## What to Explore Next

### View All Demo Endpoints

```bash
# Browser or curl:
http://localhost:8000/docs
```

FastAPI auto-generates interactive API documentation. Look for:
- `/api/v1/demo/klaviyo-integration` - Integration status
- `/api/v1/demo/mcp-status` - MCP architecture
- `/api/v1/story` - Story generation (triggers events)
- `/api/v1/auth/signup` - User signup (creates Klaviyo profile)

### Test User Signup Flow

```bash
curl -X POST http://localhost:8000/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!",
    "full_name": "Test User"
  }'
```

This will:
1. Create a user account
2. ✅ Create Klaviyo profile
3. ✅ Track "Signed Up" event

Check your Klaviyo dashboard → Profiles to see the new profile!

---

## Code Highlights to Review

### 1. Main Klaviyo Service

```bash
# View the core integration
cat backend_fastapi/app/dreamflow/klaviyo_service.py | head -n 100
```

**Key features**:
- Event tracking with retry logic
- Profile management
- Structured properties
- Error handling

### 2. MCP Adapter (Innovation!)

```bash
# View the cutting-edge MCP implementation
cat backend_fastapi/app/dreamflow/klaviyo_mcp_adapter.py | head -n 150
```

**Demonstrates**:
- Model Context Protocol integration
- LLM-powered personalization
- Future-ready architecture

### 3. Integration in Action

```bash
# See how events are triggered in main app
grep -n "klaviyo_service.track" backend_fastapi/app/dreamflow/main.py
```

Shows all places where Klaviyo events are tracked throughout the application.

---

## Troubleshooting

### "Klaviyo API Key invalid"

- Make sure you copied the **Private API Key** (not public)
- Check `.env` file has no extra spaces
- Restart the server after editing `.env`

### "Module not found" errors

```bash
pip install --upgrade -r requirements.txt
```

### Port 8000 already in use

```bash
# Use different port
uvicorn app.main:app --reload --port 8001

# Then use http://localhost:8001 in tests
```

### No events showing in Klaviyo

- Wait 30-60 seconds for events to appear
- Check backend terminal for error messages
- Verify `KLAVIYO_ENABLED=true` in .env
- Make sure API key is correct

---

## Next Steps

### Run with Full Features

To enable all features (optional):

1. **Add Supabase** (database):
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_key
   SUPABASE_SERVICE_ROLE_KEY=your_key
   ```

2. **Add AI Services** (better story generation):
   ```
   OPENAI_API_KEY=sk-your_key
   HUGGINGFACE_API_TOKEN=hf_your_token
   ```

3. Restart server

### Run Mobile App

```bash
cd dream-flow-app/app
flutter pub get
flutter run
```

---

## Quick Reference

| What | Command |
|------|---------|
| Start backend | `uvicorn app.main:app --reload --port 8000` |
| View API docs | Open `http://localhost:8000/docs` |
| Check Klaviyo status | `curl http://localhost:8000/api/v1/demo/klaviyo-integration` |
| Generate story | `curl -X POST http://localhost:8000/api/v1/story -H "Content-Type: application/json" -d '{"theme":"Ocean","prompt":"dolphin","num_scenes":3}'` |
| View logs | Check terminal where uvicorn is running |

---

## Documentation

- **Full README**: See [HACKATHON_README.md](HACKATHON_README.md)
- **Klaviyo Integration Guide**: See [docs/KLAVIYO_INTEGRATION.md](docs/KLAVIYO_INTEGRATION.md)
- **Architecture**: See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## Questions?

**For Hackathon Judges**:
- All demo endpoints are at `/api/v1/demo/*`
- Interactive API docs at `/docs`
- Full code in `backend_fastapi/app/dreamflow/`

**Contact**: [your.email@example.com]

---

**Happy Exploring! 🚀**
