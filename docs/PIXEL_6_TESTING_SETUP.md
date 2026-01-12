# Pixel 6 Testing Setup Guide

Step-by-step guide to get everything ready for testing on Pixel 6.

## Prerequisites Checklist

- [ ] Pixel 6 device (Android)
- [ ] Developer mode enabled on Pixel 6
- [ ] USB debugging enabled
- [ ] Computer with Flutter installed
- [ ] Azure account (free tier is fine)
- [ ] Supabase account (or local setup)

## Step 1: Set Up Azure Services (Free Tier)

### 1.1 Create Azure Account

1. Go to [Azure Portal](https://portal.azure.com/)
2. Sign up for free account (gets $200 credit + free services)
3. Or register for Imagine Cup to get $1,000-$5,000 credits

### 1.2 Create Azure Content Safety Resource

1. In Azure Portal, click "Create a resource"
2. Search for "Content Safety"
3. Click "Create"
4. Fill in:
   - **Subscription**: Your subscription
   - **Resource Group**: Create new (e.g., "dream-flow-rg")
   - **Region**: Choose closest (e.g., "East US")
   - **Name**: `dream-flow-content-safety`
   - **Pricing Tier**: Free (F0) - 5,000 evaluations/month
5. Click "Review + Create" → "Create"
6. Wait for deployment (1-2 minutes)
7. Go to resource → "Keys and Endpoint"
8. Copy:
   - **Endpoint**: `https://your-region.api.cognitive.microsoft.com/`
   - **Key 1**: Copy this key

### 1.3 Create Azure Computer Vision Resource

1. In Azure Portal, click "Create a resource"
2. Search for "Computer Vision"
3. Click "Create"
4. Fill in:
   - **Subscription**: Your subscription
   - **Resource Group**: Same as above (dream-flow-rg)
   - **Region**: Same region as Content Safety
   - **Name**: `dream-flow-computer-vision`
   - **Pricing Tier**: Free (F0) - 20 transactions/day
5. Click "Review + Create" → "Create"
6. Wait for deployment (1-2 minutes)
7. Go to resource → "Keys and Endpoint"
8. Copy:
   - **Endpoint**: `https://your-region.cognitiveservices.azure.com/`
   - **Key 1**: Copy this key

### 1.4 Save Azure Credentials

Create a file to store credentials (keep secure):

```
Azure Content Safety:
Endpoint: https://your-region.api.cognitive.microsoft.com/
Key: your-key-here

Azure Computer Vision:
Endpoint: https://your-region.cognitiveservices.azure.com/
Key: your-key-here
```

## Step 2: Configure Backend

### 2.1 Install Dependencies

```bash
cd backend_fastapi

# Create virtual environment (if not already done)
python -m venv .venv

# Activate virtual environment
# Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# Windows CMD:
.venv\Scripts\activate
# Linux/Mac:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2.2 Create Environment File

Create `.env` file in `backend_fastapi/`:

```bash
# Supabase (required)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Backend URL
BACKEND_URL=http://localhost:8080

# Azure Content Safety (enable for testing)
AZURE_CONTENT_SAFETY_ENABLED=true
AZURE_CONTENT_SAFETY_ENDPOINT=https://your-region.api.cognitive.microsoft.com/
AZURE_CONTENT_SAFETY_KEY=your-content-safety-key
AZURE_CONTENT_SAFETY_SEVERITY_THRESHOLD=2

# Azure Computer Vision (enable for testing)
AZURE_COMPUTER_VISION_ENABLED=true
AZURE_COMPUTER_VISION_ENDPOINT=https://your-region.cognitiveservices.azure.com/
AZURE_COMPUTER_VISION_KEY=your-computer-vision-key

# HuggingFace (if using cloud models)
HUGGINGFACE_API_TOKEN=your-hf-token

# Local inference (use local models)
LOCAL_INFERENCE=true
INFERENCE_VERSION=local
```

**Important**: Replace all placeholder values with your actual credentials!

### 2.3 Test Backend Locally

```bash
cd backend_fastapi

# Start backend server
uvicorn app.main:app --reload --port 8080
```

**Verify it's working:**

1. Open browser to `http://localhost:8080/health`
2. Should return: `{"status": "healthy"}`
3. Check logs for Azure services initialization
4. Should see: "Azure Content Safety client initialized" (if enabled)

**Test Azure integrations:**

```bash
# Test story generation (will use Azure services)
curl -X POST http://localhost:8080/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A peaceful bedtime story about a sleepy kitten",
    "theme": "Calm Focus",
    "num_scenes": 2,
    "target_length": 300
  }'
```

Check logs to verify:

- Azure Content Safety is called
- Azure Computer Vision is called (for images)
- Story generation completes

### 2.4 Troubleshoot Backend Issues

**If Azure services don't initialize:**

- Check `.env` file has correct values
- Verify Azure services are deployed and active
- Check endpoint URLs are correct (include trailing `/`)
- Verify keys are correct (no extra spaces)

**If imports fail:**

```bash
pip install azure-ai-contentsafety azure-cognitiveservices-vision-computervision azure-storage-blob msrest
```

**If backend crashes:**

- Check Supabase credentials are correct
- Verify all required environment variables are set
- Check Python version (need 3.10+)

## Step 3: Set Up Flutter App for Pixel 6

### 3.1 Enable Developer Mode on Pixel 6

1. Go to Settings → About Phone
2. Tap "Build Number" 7 times
3. Go back to Settings → System → Developer Options
4. Enable "USB Debugging"
5. Connect Pixel 6 to computer via USB

### 3.2 Verify Device Connection

```bash
# Check if device is detected
flutter devices

# Should see something like:
# Pixel 6 (mobile) • ABC123XYZ • android-arm64 • Android 13 (API 33)
```

**If device not detected:**

- Install USB drivers (usually automatic on Windows/Mac)
- Enable USB debugging on phone
- Accept "Allow USB debugging" prompt on phone
- Try different USB cable/port

### 3.3 Configure Flutter App

Edit `dream-flow-app/app/lib/core/config.dart` (or wherever config is):

```dart
// Backend URL (use your computer's IP address for testing)
// Find your IP:
// Windows: ipconfig (look for IPv4 Address)
// Mac/Linux: ifconfig (look for inet)
// Example: http://192.168.1.100:8080

class Config {
  static const String backendUrl = 'http://YOUR_COMPUTER_IP:8080';
  // Or use localhost if using adb port forwarding:
  // static const String backendUrl = 'http://localhost:8080';

  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

### 3.4 Set Up ADB Port Forwarding (Optional but Recommended)

This allows the app to use `localhost:8080` instead of your computer's IP:

```bash
# Forward port 8080 from device to computer
adb reverse tcp:8080 tcp:8080

# Verify it worked
adb reverse --list
# Should show: tcp:8080 tcp:8080
```

Then in Flutter config, use:

```dart
static const String backendUrl = 'http://localhost:8080';
```

### 3.5 Build and Install App

```bash
cd dream-flow-app/app

# Get dependencies
flutter pub get

# Run on Pixel 6
flutter run -d <device-id>

# Or if only one device connected:
flutter run
```

**First build will take 5-10 minutes** (compiling native code)

## Step 4: Test on Pixel 6

### 4.1 Verify Backend Connection

1. Open app on Pixel 6
2. Try to generate a story
3. Check backend logs on computer
4. Should see requests coming from Pixel 6

### 4.2 Test Tensor Chip Detection

Check backend logs for:

```
Native mobile accelerator detected: tensor
Using native mobile inference mode (falling back to optimized local models)
```

Or User-Agent will contain "Pixel" and device info.

### 4.3 Test Azure Services Integration

1. Generate a story through the app
2. Check backend logs for:

   - "Azure Content Safety text moderation"
   - "Azure Computer Vision alt-text"
   - Moderation results logged

3. Verify story is generated and safe

### 4.4 Test Full Pipeline

1. **Generate Story**:

   - Open app
   - Create new story
   - Wait for generation (30-60 seconds)
   - Verify story appears

2. **Check Azure Integration**:

   - Look at backend logs
   - Should see Azure Content Safety called
   - Should see Azure Computer Vision called (for images)
   - No errors

3. **Verify Content**:
   - Story should be appropriate/safe
   - Images should be generated
   - Audio should be generated (if enabled)

## Step 5: Troubleshooting Common Issues

### Backend Not Reachable from Phone

**Problem**: App can't connect to backend

**Solutions:**

1. **Check firewall**:

   - Windows: Allow Python/uvicorn through firewall
   - Allow port 8080 inbound connections

2. **Use ADB port forwarding** (easiest):

   ```bash
   adb reverse tcp:8080 tcp:8080
   ```

   Then use `localhost:8080` in Flutter config

3. **Use computer's IP address**:

   - Find IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
   - Use: `http://YOUR_IP:8080` in Flutter config
   - Make sure phone and computer are on same WiFi network

4. **Check backend is running**:
   ```bash
   curl http://localhost:8080/health
   ```

### Azure Services Not Working

**Problem**: Azure services fail or not called

**Solutions:**

1. **Check credentials**:

   - Verify endpoint URLs are correct (include trailing `/`)
   - Verify keys are correct (no spaces)
   - Check `.env` file is loaded

2. **Check service status**:

   - Go to Azure Portal
   - Verify services are "Active"
   - Check usage limits (free tier limits)

3. **Check logs**:

   - Look for error messages
   - Check if services are enabled: `AZURE_CONTENT_SAFETY_ENABLED=true`

4. **Test manually**:
   ```python
   from app.core.azure_content_safety import get_content_safety_client
   client = get_content_safety_client()
   if client:
       result = client.moderate_text("test")
       print(result)
   ```

### App Crashes on Pixel 6

**Problem**: App crashes when running

**Solutions:**

1. **Check logs**:

   ```bash
   flutter logs
   ```

2. **Check permissions**:

   - App may need internet permission
   - Check `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET"/>
     ```

3. **Rebuild app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Story Generation Takes Too Long

**Problem**: Story generation is slow

**Solutions:**

1. **Use faster settings**:

   - Reduce `num_scenes` (fewer images)
   - Reduce `target_length` (shorter stories)
   - Use `LOCAL_INFERENCE=true` (faster than cloud)

2. **Check model settings**:

   - Use TinyLlama (faster than larger models)
   - Reduce image resolution
   - Reduce image generation steps

3. **This is normal**:
   - First generation takes longer (loading models)
   - 30-60 seconds is expected
   - Subsequent generations are faster

## Step 6: Verify Everything Works

### Testing Checklist

- [ ] Backend starts without errors
- [ ] Backend health endpoint works (`/health`)
- [ ] Azure Content Safety client initializes (check logs)
- [ ] Azure Computer Vision client initializes (check logs)
- [ ] Flutter app installs on Pixel 6
- [ ] App connects to backend
- [ ] Story generation works
- [ ] Azure services are called (check backend logs)
- [ ] Generated content is safe/appropriate
- [ ] Tensor chip detection works (check logs)
- [ ] No crashes or errors

### Quick Test Script

Run this to verify backend is ready:

```bash
# Test backend health
curl http://localhost:8080/health

# Test story generation
curl -X POST http://localhost:8080/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A quick test story",
    "theme": "Calm Focus",
    "num_scenes": 1,
    "target_length": 100
  }'
```

Should return JSON with story data.

## Summary

**To get ready for Pixel 6 testing:**

1. ✅ **Set up Azure services** (15 minutes)

   - Create Content Safety resource
   - Create Computer Vision resource
   - Get endpoints and keys

2. ✅ **Configure backend** (10 minutes)

   - Create `.env` file with credentials
   - Install dependencies
   - Test backend locally

3. ✅ **Set up Flutter app** (5 minutes)

   - Enable USB debugging on Pixel 6
   - Configure backend URL
   - Build and install app

4. ✅ **Test** (30 minutes)
   - Generate stories
   - Verify Azure integrations
   - Check logs

**Total time**: ~1 hour

**Cost**: $0 (using free tiers)

Once everything is set up, you can test story generation with Azure integrations on your Pixel 6!
