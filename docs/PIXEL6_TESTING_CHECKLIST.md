# Pixel 6 Testing Checklist

Quick checklist to get everything ready for testing on Pixel 6.

## ✅ Pre-Flight Checklist

### 1. Azure Services Setup (15 minutes)

- [ ] Create Azure account (or use Imagine Cup credits)
- [ ] Create Azure Content Safety resource
  - [ ] Copy endpoint URL
  - [ ] Copy key
- [ ] Create Azure Computer Vision resource
  - [ ] Copy endpoint URL
  - [ ] Copy key

### 2. Backend Configuration (10 minutes)

- [ ] Create `backend_fastapi/.env` file
- [ ] Add Azure Content Safety credentials:
  ```
  AZURE_CONTENT_SAFETY_ENABLED=true
  AZURE_CONTENT_SAFETY_ENDPOINT=https://YOUR-REGION.api.cognitive.microsoft.com/
  AZURE_CONTENT_SAFETY_KEY=YOUR-KEY
  ```
- [ ] Add Azure Computer Vision credentials:
  ```
  AZURE_COMPUTER_VISION_ENABLED=true
  AZURE_COMPUTER_VISION_ENDPOINT=https://YOUR-REGION.cognitiveservices.azure.com/
  AZURE_COMPUTER_VISION_KEY=YOUR-KEY
  ```
- [ ] Add Supabase credentials (if using):
  ```
  SUPABASE_URL=https://your-project.supabase.co
  SUPABASE_ANON_KEY=your-key
  SUPABASE_SERVICE_ROLE_KEY=your-key
  ```
- [ ] Add backend settings:
  ```
  BACKEND_URL=http://localhost:8080
  LOCAL_INFERENCE=true
  INFERENCE_VERSION=local
  ```

### 3. Install Backend Dependencies (5 minutes)

```bash
cd backend_fastapi
python -m venv .venv
# Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# Windows CMD:
.venv\Scripts\activate
# Mac/Linux:
source .venv/bin/activate

pip install -r requirements.txt
```

### 4. Test Backend Locally (5 minutes)

```bash
cd backend_fastapi
uvicorn app.main:app --reload --port 8080
```

**Verify:**

- [ ] Browser: `http://localhost:8080/health` returns `{"status": "healthy"}`
- [ ] Check terminal logs for:
  - [ ] "Azure Content Safety client initialized" (if enabled)
  - [ ] "Azure Computer Vision client initialized" (if enabled)
  - [ ] No import errors

**Test Azure integration:**

```bash
curl -X POST http://localhost:8080/api/v1/story \
  -H "Content-Type: application/json" \
  -d '{"prompt": "A quick test", "theme": "Calm Focus", "num_scenes": 1}'
```

- [ ] Request completes without errors
- [ ] Backend logs show Azure services being called

### 5. Pixel 6 Setup (5 minutes)

- [ ] Enable Developer Mode:
  1. Settings → About Phone
  2. Tap "Build Number" 7 times
- [ ] Enable USB Debugging:
  1. Settings → Developer Options
  2. Enable "USB Debugging"
- [ ] Connect Pixel 6 to computer via USB
- [ ] Accept "Allow USB debugging" prompt on phone

### 6. Verify Device Connection (2 minutes)

```bash
flutter devices
```

- [ ] Pixel 6 appears in device list
- [ ] Shows as "Pixel 6 (mobile) • [device-id] • android-arm64"

**If device not detected:**

- [ ] Check USB cable/port
- [ ] Re-enable USB debugging
- [ ] Install USB drivers (if needed)

### 7. Set Up Port Forwarding (1 minute)

**Option A: ADB Port Forwarding (Recommended)**

```bash
adb reverse tcp:8080 tcp:8080
adb reverse --list
```

- [ ] Port forwarding active (shows `tcp:8080 tcp:8080`)
- [ ] Can use `http://localhost:8080` in Flutter app

**Option B: Use Computer's IP Address**

```bash
# Find your IP address
# Windows:
ipconfig
# Mac/Linux:
ifconfig
```

- [ ] Note your computer's IP (e.g., `192.168.1.100`)
- [ ] Make sure phone and computer are on same WiFi network
- [ ] Will use `http://YOUR_IP:8080` in Flutter app

### 8. Flutter App Configuration (3 minutes)

**Option A: Use ADB Port Forwarding (Easiest)**

The app defaults to `http://127.0.0.1:8080` which works with port forwarding.

**No changes needed!** Just run:

```bash
adb reverse tcp:8080 tcp:8080
```

**Option B: Use IP Address**

If not using port forwarding, update Flutter app config:

Find `dream-flow-app/app/lib/core/story_service.dart` (or wherever BACKEND_URL is configured):

```dart
_baseUrl = baseUrl ??
    const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://YOUR_COMPUTER_IP:8080', // Change this
    ),
```

Or use --dart-define when running:

```bash
flutter run --dart-define=BACKEND_URL=http://192.168.1.100:8080
```

### 9. Build and Install App (10 minutes)

```bash
cd dream-flow-app/app
flutter pub get
flutter run
```

**First build takes 5-10 minutes** - be patient!

- [ ] App installs on Pixel 6
- [ ] App opens without crashes
- [ ] No build errors

### 10. Test Everything (15 minutes)

#### Test 1: Backend Connection

- [ ] Open app on Pixel 6
- [ ] Try to generate a story
- [ ] Check backend terminal for incoming requests
- [ ] Should see logs from Pixel 6

**If connection fails:**

- [ ] Check firewall (allow port 8080)
- [ ] Verify port forwarding: `adb reverse --list`
- [ ] Check backend is running: `curl http://localhost:8080/health`
- [ ] Verify same network (if using IP address)

#### Test 2: Tensor Chip Detection

- [ ] Generate a story
- [ ] Check backend logs for:
  - [ ] "Native mobile accelerator detected: tensor"
  - [ ] Or User-Agent contains "Pixel"

#### Test 3: Azure Content Safety

- [ ] Generate a story
- [ ] Check backend logs for:
  - [ ] "Azure Content Safety text moderation"
  - [ ] Moderation results logged
  - [ ] No errors

#### Test 4: Azure Computer Vision

- [ ] Generate a story with images
- [ ] Check backend logs for:
  - [ ] "Azure Computer Vision alt-text"
  - [ ] Image analysis logged
  - [ ] No errors

#### Test 5: Full Story Generation

- [ ] Story text appears
- [ ] Images are generated
- [ ] Audio is generated (if enabled)
- [ ] No crashes
- [ ] Content is safe/appropriate

## 🎯 Success Criteria

You're ready when:

- [x] Backend starts without errors
- [x] Backend health check works
- [x] Pixel 6 is connected and recognized
- [x] Port forwarding is active (or IP configured)
- [x] App installs and runs on Pixel 6
- [x] App can connect to backend
- [x] Story generation works
- [x] Azure services are called (check logs)
- [x] Tensor chip detection works (check logs)
- [x] No crashes or errors

## 🚨 Troubleshooting Quick Reference

**Backend not reachable:**

```bash
adb reverse tcp:8080 tcp:8080
# Then use: http://localhost:8080
```

**Azure services not working:**

- Check `.env` file values are correct
- Verify endpoints end with `/`
- Check Azure Portal → Services are "Active"

**App crashes:**

```bash
flutter clean
flutter pub get
flutter run
```

**Device not detected:**

- Re-enable USB debugging
- Try different USB cable/port
- Check USB drivers installed

## 📋 Summary

**Time needed**: ~1 hour total
**Cost**: $0 (using free tiers)

**Key steps:**

1. ✅ Azure services (15 min)
2. ✅ Backend config (10 min)
3. ✅ Test backend (5 min)
4. ✅ Pixel 6 setup (5 min)
5. ✅ Port forwarding (1 min)
6. ✅ Build app (10 min)
7. ✅ Test everything (15 min)

**Once complete, you can:**

- Test story generation
- Verify Azure integrations
- Test Tensor chip detection
- Record demo video
- Prepare for submission

Good luck! 🎉
