# Quick Setup Guide for 8GB RAM Laptop

## Step 1: Install Dependencies

```powershell
cd backend_fastapi
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Step 2: Configure Environment

Create or update `.env` file (optimized for 8GB RAM, CPU-only, sub‑1‑minute stories):

```env
# Enable local inference (CPU-only TinyLlama)
LOCAL_INFERENCE=true
LOCAL_STORY_MODEL=tinyllama
LOCAL_MODEL_PATH=./models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf

# Enable low memory + fast mode for 8GB systems
LOW_MEMORY_MODE=true
FAST_MODE=true

# Disable heavy video generation
LOCAL_VIDEO_ENABLED=false

# Lightweight image generation (optional)
LOCAL_IMAGE_ENABLED=true
# Use the higher-quality SD 1.5 checkpoint by default (license-required)
LOCAL_IMAGE_MODEL=runwayml/stable-diffusion-v1-5
# Supply your Hugging Face token so gated weights can download
HUGGINGFACE_API_TOKEN=hf_xxx
USE_PLACEHOLDERS_ONLY=false   # set to true for fastest mode (no image gen)

# Short stories + few scenes for speed
MAX_NEW_TOKENS=128
MAX_STORY_LENGTH=500          # approx characters
NUM_SCENES=2                  # number of images
IMAGE_RESOLUTION=256x256
IMAGE_STEPS=6

# Supabase configuration (required)
SUPABASE_SERVICE_ROLE_KEY=your_key_here
SUPABASE_URL=your_url_here

# Optional: TTS voice
EDGE_TTS_VOICE=en-US-AriaNeural
```

## Step 3: Start Server

```powershell
# Standard start
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8080

# Or use persistent mode (recommended)
.\run_server_persistent.ps1 --method task
```

## Step 4: Verify

```powershell
# Check health
Invoke-WebRequest -Uri http://localhost:8080/health -UseBasicParsing

# Check memory usage
Get-Process python | Select-Object ProcessName, @{Name="Memory(MB)";Expression={$_.WS/1MB}}
```

## Expected Memory Usage

- **Model loading**: ~1-2 GB
- **Server running**: ~4-6 GB total
- **Free memory**: ~2-4 GB remaining

## Troubleshooting

### Out of Memory?

1. Set `LOW_MEMORY_MODE=true` in `.env`
2. Close other applications
3. Restart server

### Slow Generation?

- Normal: 2-7 minutes per story
- If >10 minutes: Check CPU/memory usage

### Model Won't Load?

- Ensure at least 1.5 GB free RAM
- Check disk space (model is ~600 MB)
- Try restarting server

## Network Setup (if frontend on different laptop)

1. Find 8GB laptop's IP address:
   ```powershell
   ipconfig | findstr IPv4
   ```

2. Update frontend `.env.local`:
   ```env
   NEXT_PUBLIC_BACKEND_URL=http://192.168.1.XXX:8080
   ```

3. Ensure firewall allows port 8080:
   ```powershell
   New-NetFirewallRule -DisplayName "Dream Flow Backend" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
   ```

## Auto-Start on Boot

```powershell
# Set up scheduled task
.\run_server_persistent.ps1 --method task

# Prevent sleep when plugged in (optional)
powercfg /change standby-timeout-ac 0
```

## Performance Tips

1. ✅ Keep laptop plugged in
2. ✅ Close unnecessary apps
3. ✅ Use `LOW_MEMORY_MODE=true`
4. ✅ Don't enable image generation
5. ✅ Monitor memory usage

## Success Indicators

- ✅ Server starts without errors
- ✅ Model loads in 10-30 seconds
- ✅ Health check returns `{"status":"ok"}`
- ✅ Memory usage stays under 6 GB
- ✅ Story generation completes in 2-7 minutes

