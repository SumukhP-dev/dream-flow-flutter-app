# Laptop Setup Guide for Self-Hosting Dream Flow Backend

Complete step-by-step guide to set up a laptop for self-hosting your FastAPI backend with local AI models (Ollama).

## Prerequisites

### Hardware Requirements
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 256GB+ SSD (models are 2-7GB each)
- **CPU**: 4+ cores (Intel i5/i7 or AMD Ryzen 5/7)
- **GPU**: Optional but recommended (NVIDIA with CUDA support)
- **Internet**: Stable connection (upload speed matters for serving requests)
- **Power**: Keep laptop plugged in 24/7

### Software Requirements
- Operating System: Windows 10/11, Linux (Ubuntu 22.04+), or macOS
- Python 3.11 or higher
- Git
- Text editor (VS Code recommended)

---

## Step 1: Install Base Software

### 1.1 Install Python 3.11+

**Windows:**
```powershell
# Download from python.org or use winget
winget install Python.Python.3.11
```

**Linux (Ubuntu):**
```bash
sudo apt update
sudo apt install python3.11 python3.11-venv python3-pip
```

**macOS:**
```bash
brew install python@3.11
```

Verify installation:
```bash
python --version  # Should show 3.11+
pip --version
```

### 1.2 Install Git

**Windows:**
```powershell
winget install Git.Git
```

**Linux:**
```bash
sudo apt install git
```

**macOS:**
```bash
brew install git
```

### 1.3 Install VS Code (Recommended)

Download from: https://code.visualstudio.com/

---

## Step 2: Install Ollama (Local AI Models)

### 2.1 Download Ollama

Visit: https://ollama.ai/download

**Windows:**
- Download installer and run it
- Ollama will be added to PATH automatically

**Linux:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

**macOS:**
- Download .dmg and install
- Or use: `brew install ollama`

### 2.2 Verify Ollama Installation

```bash
ollama --version
```

### 2.3 Download AI Models

```bash
# Story generation model (small, fast)
ollama pull llama3.2:1b

# Text-to-speech (if available)
ollama pull bark

# Image generation (if available)
ollama pull stable-diffusion

# Or use larger models for better quality:
ollama pull llama3.2:3b  # Better quality, needs more RAM
```

**Note:** Models are large (2-7GB each). Download time depends on internet speed.

### 2.4 Test Ollama

```bash
# Test text generation
ollama run llama3.2:1b "Write a short bedtime story about a star"

# Check if Ollama server is running
curl http://localhost:11434/api/tags
```

---

## Step 3: Clone and Set Up Your Backend

### 3.1 Clone Repository

```bash
cd ~  # or C:\Users\YourName on Windows
git clone https://github.com/your-username/Dream_Flow_Flutter_App.git
cd Dream_Flow_Flutter_App/backend_fastapi
```

### 3.2 Create Virtual Environment

**Windows:**
```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

**Linux/macOS:**
```bash
python3 -m venv venv
source venv/bin/activate
```

### 3.3 Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

---

## Step 4: Configure Environment Variables

### 4.1 Create `.env` File

Create `backend_fastapi/.env`:

```env
# Supabase Configuration (Required)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Backend URL (Your laptop's IP or domain)
BACKEND_URL=http://localhost:8080
# For external access: http://your-ip:8080 or https://your-domain.com

# Model Configuration (Local Models)
USE_LOCAL_MODELS=true
OLLAMA_BASE_URL=http://localhost:11434

# Story Model (Ollama model name)
STORY_MODEL=llama3.2:1b

# TTS Model (if using Ollama)
TTS_MODEL=bark

# Image Model (if using Ollama)
IMAGE_MODEL=stable-diffusion

# Optional: HuggingFace fallback (if local fails)
HUGGINGFACE_API_TOKEN=your-token-here

# Sentry (Optional, for error tracking)
SENTRY_DSN=
SENTRY_ENVIRONMENT=production

# Asset Storage
ASSET_DIR=./storage

# Admin Users (comma-separated user IDs)
ADMIN_USER_IDS=
```

### 4.2 Get Supabase Credentials

1. Go to https://supabase.com
2. Create account or sign in
3. Create new project
4. Go to Settings → API
5. Copy:
   - Project URL → `SUPABASE_URL`
   - `anon` key → `SUPABASE_ANON_KEY`
   - `service_role` key → `SUPABASE_SERVICE_ROLE_KEY` (keep secret!)

---

## Step 5: Network Configuration

### 5.1 Find Your Laptop's IP Address

**Windows:**
```powershell
ipconfig
# Look for IPv4 Address (e.g., 192.168.1.100)
```

**Linux/macOS:**
```bash
ip addr show  # Linux
ifconfig      # macOS
# Look for inet address (e.g., 192.168.1.100)
```

### 5.2 Configure Router Port Forwarding

1. Access router admin panel (usually `192.168.1.1`)
2. Find "Port Forwarding" or "Virtual Server"
3. Add rule:
   - **External Port**: 8080 (or 443 for HTTPS)
   - **Internal IP**: Your laptop's IP (e.g., 192.168.1.100)
   - **Internal Port**: 8080
   - **Protocol**: TCP

### 5.3 Configure Firewall

**Windows:**
```powershell
# Allow Python through firewall
New-NetFirewallRule -DisplayName "Python FastAPI" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

**Linux:**
```bash
sudo ufw allow 8080/tcp
sudo ufw enable
```

**macOS:**
- System Preferences → Security & Privacy → Firewall
- Click "Firewall Options"
- Add Python to allowed apps

### 5.4 Set Up Dynamic DNS (If IP Changes)

**Option 1: Use ngrok (Easiest, Free)**
```bash
# Install ngrok
# Download from https://ngrok.com
ngrok http 8080
# Gives you: https://random-string.ngrok.io
```

**Option 2: Use No-IP or DuckDNS (Free)**
- Sign up at https://www.noip.com or https://www.duckdns.org
- Install their dynamic DNS client
- Get a free subdomain (e.g., `yourname.duckdns.org`)

---

## Step 6: Set Up SSL/HTTPS (Optional but Recommended)

### 6.1 Using ngrok (Easiest)

```bash
ngrok http 8080
# Automatically provides HTTPS
```

### 6.2 Using Let's Encrypt (Free SSL)

**Linux (with nginx reverse proxy):**
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

**Windows:**
- Use Certify The Web: https://certifytheweb.com
- Or use Cloudflare Tunnel (free, easier)

---

## Step 7: Configure Backend for Local Models

### 7.1 Update Backend Code (If Needed)

The backend needs to support Ollama. You'll need to modify `backend_fastapi/app/core/services.py` to:
- Check for `USE_LOCAL_MODELS` environment variable
- Use Ollama API instead of HuggingFace when enabled
- Fall back to HuggingFace if local models fail

**Example modification needed:**
```python
# In services.py, modify _default_client function
import os
import httpx

def _default_client(model_id: str):
    if os.getenv("USE_LOCAL_MODELS") == "true":
        # Use Ollama local endpoint
        return OllamaClient(base_url=os.getenv("OLLAMA_BASE_URL", "http://localhost:11434"))
    else:
        # Use HuggingFace (current implementation)
        return InferenceClient(model=model_id, token=settings.hf_token)
```

---

## Step 8: Test the Setup

### 8.1 Start Ollama (If Not Running)

```bash
# Ollama should start automatically, but verify:
ollama serve
# Keep this running in a terminal
```

### 8.2 Start FastAPI Backend

```bash
cd backend_fastapi
# Activate virtual environment first
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
```

### 8.3 Test Health Endpoint

```bash
# Local test
curl http://localhost:8080/health

# External test (from another device)
curl http://your-ip:8080/health
# or
curl https://your-domain.com/health
```

### 8.4 Test Story Generation

```bash
curl -X POST http://localhost:8080/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A child exploring space",
    "theme": "space",
    "target_length": 300
  }'
```

---

## Step 9: Set Up Auto-Start (Keep Running 24/7)

### 9.1 Windows (Task Scheduler)

1. Open Task Scheduler
2. Create Basic Task
3. Name: "Dream Flow Backend"
4. Trigger: "When computer starts"
5. Action: "Start a program"
6. Program: `C:\path\to\venv\Scripts\python.exe`
7. Arguments: `-m uvicorn app.main:app --host 0.0.0.0 --port 8080`
8. Start in: `C:\path\to\backend_fastapi`

### 9.2 Linux (systemd Service)

Create `/etc/systemd/system/dreamflow.service`:

```ini
[Unit]
Description=Dream Flow Backend
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/Dream_Flow_Flutter_App/backend_fastapi
Environment="PATH=/home/your-username/Dream_Flow_Flutter_App/backend_fastapi/venv/bin"
ExecStart=/home/your-username/Dream_Flow_Flutter_App/backend_fastapi/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8080
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable dreamflow
sudo systemctl start dreamflow
sudo systemctl status dreamflow
```

### 9.3 macOS (Launch Agent)

Create `~/Library/LaunchAgents/com.dreamflow.backend.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dreamflow.backend</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/venv/bin/uvicorn</string>
        <string>app.main:app</string>
        <string>--host</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8080</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/path/to/backend_fastapi</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.dreamflow.backend.plist
```

---

## Step 10: Monitoring and Maintenance

### 10.1 Monitor Resource Usage

**Windows:**
- Task Manager → Performance tab
- Monitor CPU, RAM, Disk usage

**Linux:**
```bash
htop  # Install: sudo apt install htop
```

**macOS:**
- Activity Monitor

### 10.2 Check Logs

**FastAPI logs:**
- Check terminal output
- Or configure logging to file

**Ollama logs:**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags
```

### 10.3 Set Up Alerts (Optional)

- Use UptimeRobot (free) to monitor your endpoint
- Get email alerts if server goes down
- https://uptimerobot.com

---

## Troubleshooting

### Issue: Port 8080 Already in Use

**Solution:**
```bash
# Find what's using the port
# Windows:
netstat -ano | findstr :8080

# Linux/macOS:
lsof -i :8080

# Kill the process or use different port
```

### Issue: Can't Access from External Network

**Check:**
1. Firewall allows port 8080
2. Router port forwarding is configured
3. ISP doesn't block incoming connections
4. Try ngrok as temporary solution

### Issue: Models Too Slow

**Solutions:**
- Use smaller models (1B instead of 3B)
- Add GPU support (NVIDIA CUDA)
- Reduce `max_new_tokens` in config
- Use cloud models as fallback

### Issue: Laptop Overheating

**Solutions:**
- Use cooling pad
- Clean laptop fans
- Reduce CPU usage (smaller models)
- Consider underclocking

---

## Security Considerations

1. **Change Default Passwords**: If using SSH, use strong passwords
2. **Use HTTPS**: Set up SSL certificate (Let's Encrypt is free)
3. **Firewall**: Only open necessary ports (8080)
4. **Keep Updated**: Regularly update OS and Python packages
5. **Backup**: Regularly backup your `.env` file and database

---

## Cost Summary

- **Laptop**: $200-600 (one-time)
- **Electricity**: $3-12/month
- **Internet**: Already have (no extra cost)
- **Domain**: $10-15/year (optional)
- **Total**: ~$200-600 one-time + $3-12/month

**Much cheaper than cloud hosting ($24-85/month)!**

---

## Next Steps

1. ✅ Complete all setup steps above
2. ✅ Test locally first
3. ✅ Configure external access
4. ✅ Update Flutter app to use your server URL
5. ✅ Monitor and optimize

Need help with any specific step? Let me know!

