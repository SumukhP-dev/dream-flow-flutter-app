# Fix Hugging Face API Endpoint Issue

## Problem

The Hugging Face API endpoint has changed:
- **Old (deprecated)**: `https://api-inference.huggingface.co`
- **New (required)**: `https://router.huggingface.co`

Error message:
```
410 Client Error: Gone for url: https://api-inference.huggingface.co/models/...
https://api-inference.huggingface.co is no longer supported. 
Please use https://router.huggingface.co instead.
```

## Solution

### Step 1: Update huggingface_hub Library

The `huggingface_hub` library needs to be updated to a version that uses the new endpoint:

```bash
cd backend_fastapi
source .venv/bin/activate  # or your virtual environment
pip install --upgrade huggingface_hub
```

Or update `requirements.txt`:
```
huggingface_hub>=0.25.1
```

Then reinstall:
```bash
pip install -r requirements.txt --upgrade
```

### Step 2: Restart the Backend Server

After updating the library, restart your backend server:

```bash
# Stop the current server (Ctrl+C or kill the process)
# Then restart:
cd backend_fastapi
source .venv/bin/activate
uvicorn app.dreamflow.main:app --reload --port 8080
```

Or if using the startup script:
```bash
./run_local_server.sh
```

## Verification

After updating, test the story generation endpoint:
- The error should no longer appear
- Story generation should work with the new router endpoint

## What Was Changed

1. ✅ Updated `requirements.txt` to allow newer versions of `huggingface_hub`
2. ✅ Updated comments in `app/core/services.py` to note the endpoint change
3. ✅ Updated `mock_hf_service.py` documentation

The `InferenceClient` from `huggingface_hub` should automatically use the new endpoint in recent versions of the library.

## If Issues Persist

If you're still seeing the old endpoint being used:

1. **Check huggingface_hub version**:
   ```bash
   pip show huggingface_hub
   ```

2. **Force upgrade to latest**:
   ```bash
   pip install --upgrade --force-reinstall huggingface_hub
   ```

3. **Check if InferenceClient supports base_url parameter** (in newer versions):
   ```python
   InferenceClient(
       model=model_id,
       token=token,
       base_url="https://router.huggingface.co"  # If supported
   )
   ```

