# How to Check Why Mock Values Are Being Used

## Problem
You're seeing `[MOCK STORY]` in the generated stories even though you're using the "real backend" on another laptop.

## Root Cause
The backend uses **mock values** when:
1. `HUGGINGFACE_API_URL` environment variable is set to a mock service URL (e.g., `http://localhost:8000`)
2. The backend is configured to use a local mock HuggingFace service

## How to Fix

### Step 1: Check Backend Environment Variables

On the **backend laptop** (where FastAPI is running), check the environment variables:

```bash
# Check if HUGGINGFACE_API_URL is set
echo $HUGGINGFACE_API_URL

# Or on Windows PowerShell:
$env:HUGGINGFACE_API_URL
```

**If `HUGGINGFACE_API_URL` is set to a localhost URL** (like `http://localhost:8000` or `http://127.0.0.1:8000`), that's why you're getting mock values!

### Step 2: Remove or Update HUGGINGFACE_API_URL

**Option A: Use Real HuggingFace API (Recommended)**
- **Unset** `HUGGINGFACE_API_URL` completely, OR
- **Set it to empty**: `export HUGGINGFACE_API_URL=""` (Linux/Mac) or `$env:HUGGINGFACE_API_URL=""` (PowerShell)
- Make sure `HUGGINGFACE_API_TOKEN` is set with your real HuggingFace token
- Restart the backend server

**Option B: Use Local Ollama (For Free Tier)**
- Set `LOCAL_INFERENCE=true`
- Set `USE_LOCAL_MODELS=true` (if using Ollama)
- Unset `HUGGINGFACE_API_URL`
- Restart the backend server

### Step 3: Verify Backend Configuration

Check the backend logs when it starts. You should see one of these messages:

**✅ Good (Real HuggingFace):**
```
Using HuggingFace model: meta-llama/Llama-3.2-1B-Instruct
```

**✅ Good (Local Ollama):**
```
Using Ollama local model: llama3.2:1b
```

**❌ Bad (Mock Service):**
```
Using custom HuggingFace API URL: http://localhost:8000 with model: ...
```

### Step 4: Check Backend Startup Script

If you're using a startup script (like `run_local_server.sh`), check if it sets `HUGGINGFACE_API_URL`:

```bash
# Look for this line in your startup script:
grep -i "HUGGINGFACE_API_URL" run_local_server.sh
```

If it's setting a mock URL, remove that line or comment it out.

## Quick Fix Commands

**On Linux/Mac:**
```bash
# Unset the mock URL
unset HUGGINGFACE_API_URL

# Make sure real token is set
export HUGGINGFACE_API_TOKEN=hf_your_real_token_here

# Restart backend
cd backend_fastapi
uvicorn app.dreamflow.main:app --reload --port 8080
```

**On Windows PowerShell:**
```powershell
# Unset the mock URL
$env:HUGGINGFACE_API_URL = ""

# Make sure real token is set
$env:HUGGINGFACE_API_TOKEN = "hf_your_real_token_here"

# Restart backend
cd backend_fastapi
uvicorn app.dreamflow.main:app --reload --port 8080
```

## Expected Behavior After Fix

After removing `HUGGINGFACE_API_URL` or setting it correctly:
- Stories should be **real AI-generated text** (not `[MOCK STORY]`)
- Backend logs should show "Using HuggingFace model: ..." (not "Using custom HuggingFace API URL")
- Story quality should match the model you're using (e.g., Llama-3.2-1B-Instruct)

## Still Seeing Mock Values?

1. **Check if mock service is still running**: `ps aux | grep mock_hf_service` (Linux/Mac) or `Get-Process | Where-Object {$_.ProcessName -like "*mock*"}` (PowerShell)
2. **Check backend logs** for which client is being used
3. **Verify environment variables** are actually loaded (restart terminal/server)
4. **Check `.env` file** if you're using one - make sure `HUGGINGFACE_API_URL` is not set there

