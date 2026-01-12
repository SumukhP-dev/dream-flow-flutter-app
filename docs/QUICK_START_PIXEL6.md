# Quick Start: Pixel 6 Testing Setup

Fast setup guide to get testing on Pixel 6 in 30 minutes.

## 🚀 Quick Setup (30 minutes)

### Step 1: Azure Services (10 min)

1. **Azure Portal** → Create Resource → "Content Safety"

   - Region: East US (or closest)
   - Pricing: Free (F0)
   - Copy: Endpoint + Key 1

2. **Azure Portal** → Create Resource → "Computer Vision"
   - Same region as above
   - Pricing: Free (F0)
   - Copy: Endpoint + Key 1

### Step 2: Backend Config (5 min)

Create `backend_fastapi/.env`:

```env
# Azure Content Safety
AZURE_CONTENT_SAFETY_ENABLED=true
AZURE_CONTENT_SAFETY_ENDPOINT=https://YOUR-REGION.api.cognitive.microsoft.com/
AZURE_CONTENT_SAFETY_KEY=YOUR-KEY

# Azure Computer Vision
AZURE_COMPUTER_VISION_ENABLED=true
AZURE_COMPUTER_VISION_ENDPOINT=https://YOUR-REGION.cognitiveservices.azure.com/
AZURE_COMPUTER_VISION_KEY=YOUR-KEY

# Supabase (if you have it)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-key
SUPABASE_SERVICE_ROLE_KEY=your-key

# Backend
BACKEND_URL=http://localhost:8080
LOCAL_INFERENCE=true
INFERENCE_VERSION=local
```

**Test backend:**

```bash
cd backend_fastapi
pip install -r requirements.txt
uvicorn app.main:app --reload
# Check: http://localhost:8080/health
```

### Step 3: Flutter Setup (5 min)

1. **Enable USB Debugging on Pixel 6**:

   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → Enable "USB Debugging"

2. **Connect Pixel 6**:

   ```bash
   # Verify connection
   flutter devices
   # Should see: Pixel 6 (mobile) • ...

   # Forward port (allows app to use localhost:8080)
   adb reverse tcp:8080 tcp:8080
   ```

3. **Update Flutter Config**:
   Find backend URL config in `dream-flow-app/app/lib/core/config.dart` (or similar):
   ```dart
   static const String backendUrl = 'http://localhost:8080';
   ```

### Step 4: Build & Run (10 min)

```bash
cd dream-flow-app/app
flutter pub get
flutter run
```

**First build takes 5-10 minutes** - be patient!

### Step 5: Test (5 min)

1. Open app on Pixel 6
2. Generate a story
3. Check backend terminal logs:
   - Should see: "Azure Content Safety client initialized"
   - Should see: "Native mobile accelerator detected: tensor"
   - Should see story generation logs

## ✅ Verification Checklist

- [ ] Backend running: `curl http://localhost:8080/health`
- [ ] Pixel 6 connected: `flutter devices` shows device
- [ ] Port forwarded: `adb reverse --list` shows tcp:8080
- [ ] App installed on Pixel 6
- [ ] Story generation works
- [ ] Backend logs show Azure services called

## 🔧 Common Issues

**Backend not reachable:**

```bash
# Use ADB port forwarding (easiest)
adb reverse tcp:8080 tcp:8080
```

**Azure services not working:**

- Check `.env` file has correct values
- Verify endpoints end with `/`
- Check Azure Portal → Services are "Active"

**App crashes:**

```bash
flutter clean
flutter pub get
flutter run
```

## 📱 What to Test

1. **Story Generation**: Generate a story through app
2. **Azure Integration**: Check backend logs for Azure calls
3. **Tensor Chip**: Should detect Pixel 6's Tensor chip
4. **Content Safety**: Generated content should be safe
5. **Computer Vision**: Image analysis should work

## 🎯 Success Criteria

✅ Backend starts without errors
✅ App connects to backend
✅ Story generation completes
✅ Azure services are called (check logs)
✅ No crashes or errors

**You're ready to test!** 🎉
