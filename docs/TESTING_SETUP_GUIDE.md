# Testing Setup Guide - Pixel 6

## Current Status

✅ **Backend is running!**

- URL: `http://localhost:8080`
- Health check: `{"status": "ok", "llm": true, "tts": true, "stt": true, "twitch": true}`

## Quick Start Steps

### Step 1: Connect Your Pixel 6

1. **Enable Developer Mode on Pixel 6:**

   - Settings → About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings → System → Developer Options
   - Enable "USB Debugging"

2. **Connect Pixel 6 to Computer:**

   - Connect via USB cable
   - Accept "Allow USB debugging" prompt on phone (check "Always allow" if desired)

3. **Verify Connection:**

   ```powershell
   cd "C:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\dream-flow-app\app"
   flutter devices
   ```

   You should see your Pixel 6 listed, e.g.:

   ```
   Pixel 6 (mobile) • ABC123XYZ • android-arm64 • Android 13 (API 33)
   ```

### Step 2: Set Up Port Forwarding (IMPORTANT!)

Since your backend runs on `localhost:8080` on your computer, you need to forward that port to your Pixel 6 so the app can access it.

**Option A: Use ADB Port Forwarding (Recommended)**

If ADB is not in your PATH, use the full path:

```powershell
# Forward port 8080 from device to computer
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adbPath reverse tcp:8080 tcp:8080

# Verify it worked
& $adbPath reverse --list
# Should show: tcp:8080 tcp:8080
```

Or if ADB is in your PATH:

```powershell
adb reverse tcp:8080 tcp:8080
adb reverse --list
```

**Option B: Use Your Computer's IP Address**

If ADB port forwarding doesn't work, you can use your computer's IP:

1. Find your computer's IP address:

   ```powershell
   ipconfig
   # Look for "IPv4 Address" under your active network adapter
   # Example: 192.168.1.100
   ```

2. Make sure your phone and computer are on the same WiFi network

3. When running the Flutter app, use `--dart-define` to set the backend URL:
   ```powershell
   flutter run --dart-define=BACKEND_URL=http://192.168.1.100:8080
   ```

### Step 3: Configure Flutter App with .env File

**Note:** The app has been updated to automatically use your external backend when `BACKEND_URL` is provided. The local on-device backend will only start if no external backend is configured.

**Recommended: Use a `.env` file** to store your configuration instead of passing command-line flags.

1. **Create a `.env` file** in the `dream-flow-app/app` directory:

   ```powershell
   cd "C:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\dream-flow-app\app"
   ```

2. **Copy the example file and edit it:**

   ```powershell
   # Copy .env.example to .env (if .env.example exists)
   Copy-Item .env.example .env

   # Or create .env manually
   ```

3. **Edit the `.env` file** with your configuration:

   ```env
   # Backend Configuration
   # If using ADB port forwarding (recommended):
   BACKEND_URL=http://localhost:8080

   # Or if using IP address (if port forwarding doesn't work):
   # First get your IP: ipconfig
   # BACKEND_URL=http://192.168.1.14:8080

   # Supabase Configuration (optional for basic testing)
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key

   # Sentry Configuration (optional)
   SENTRY_DSN=

   # Environment (optional)
   ENVIRONMENT=development
   ```

4. **The `.env` file is automatically loaded** when you run the app - no need for `--dart-define` flags!

**Alternative: Using command-line flags (still supported)**

If you prefer to use command-line flags instead of a `.env` file:

```powershell
# If using ADB port forwarding (recommended):
flutter run -d 35221JEGR17301 --dart-define=BACKEND_URL=http://localhost:8080

# Or if using IP address (if port forwarding doesn't work):
# First get your IP: ipconfig
flutter run -d 35221JEGR17301 --dart-define=BACKEND_URL=http://192.168.1.14:8080
```

Replace `35221JEGR17301` with your actual device ID from `flutter devices`.

**Note:** Command-line `--dart-define` values take precedence over `.env` file values if both are provided.

### Step 4: Run the Flutter App

```powershell
cd "C:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\dream-flow-app\app"

# Get dependencies (if not done already)
flutter pub get

# Run on Pixel 6
# If you've set up .env file, just run:
flutter run -d 35221JEGR17301

# Or if using command-line flags instead:
flutter run -d 35221JEGR17301 --dart-define=BACKEND_URL=http://localhost:8080
```

Replace `35221JEGR17301` with your actual device ID (get it from `flutter devices`).

**First build takes 5-10 minutes** - be patient!

If you have multiple devices, specify the Pixel 6:

```powershell
flutter run -d <device-id>
# Get device-id from: flutter devices
```

### Step 5: Verify Backend Connection

Once the app is running on your Pixel 6:

1. **Check Backend Logs:**

   - Look at the terminal where the backend is running
   - You should see incoming requests from the app

2. **Test Story Generation:**

   - Open the app on Pixel 6
   - Try to generate a story
   - Check backend terminal for logs like:
     - "Azure Content Safety client initialized" (if enabled)
     - Story generation requests
     - Image generation requests

3. **Test Health Endpoint from Device:**
   - In the app, try to generate a story
   - If connection fails, you'll see an error in the app

## Testing Checklist

### Basic Functionality

- [ ] App installs and opens on Pixel 6
- [ ] App connects to backend (check backend logs)
- [ ] Story generation works
- [ ] Images are generated
- [ ] Audio is generated (if enabled)
- [ ] No crashes or errors

### Backend Integration

- [ ] Backend receives requests from Pixel 6
- [ ] Story generation completes successfully
- [ ] Azure services are called (check logs if configured)
- [ ] Tensor chip detection works (check logs for "tensor" or "Pixel")

### Features to Test

1. **Story Generation:**

   - Create a new story
   - Try different themes
   - Try different prompts
   - Check generated content quality

2. **Story Playback:**

   - Play audio narration
   - View image slideshow
   - Navigate through scenes

3. **Session History:**

   - View past stories
   - Resume previous sessions

4. **App Settings:**
   - Check accessibility features
   - Test user preferences

## Troubleshooting

### OneDrive Sync Issues

**Problem:** Flutter crashes with `FileSystemException: readInto failed` or timeouts

**This is common when your project is in OneDrive.** OneDrive sync can interfere with Flutter's file operations.

**Solutions:**

1. **Wait for OneDrive to finish syncing:**

   - Check OneDrive icon in system tray
   - Wait until all files show as synced (no spinning arrows)

2. **Pause OneDrive sync temporarily:**

   - Right-click OneDrive icon → Settings → Sync and backup
   - Pause syncing for 2 hours
   - Run Flutter command
   - Resume syncing when done

3. **Try running the command again:**

   - Sometimes it works on the second attempt
   - Flutter clean can help: `flutter clean && flutter pub get`

4. **For best results, consider:**
   - Moving the project to a local folder (outside OneDrive)
   - Or excluding `.dart_tool` and `build` folders from OneDrive sync

### Backend Not Reachable

**Problem:** App can't connect to backend

**Solutions:**

1. **Check port forwarding:**

   ```powershell
   adb reverse --list
   # Should show: tcp:8080 tcp:8080
   ```

   If not, run: `adb reverse tcp:8080 tcp:8080`

2. **Check backend is running:**

   ```powershell
   curl http://localhost:8080/health
   # Should return: {"status": "ok", ...}
   ```

3. **Check firewall:**

   - Windows Firewall may block connections
   - Allow Python/uvicorn through firewall
   - Allow port 8080 inbound connections

4. **Use IP address method:**
   - Find your IP: `ipconfig`
   - Update `.env` file: `BACKEND_URL=http://YOUR_IP:8080`
   - Or use: `--dart-define=BACKEND_URL=http://YOUR_IP:8080`
   - Ensure phone and computer are on same WiFi

### Pixel 6 Not Detected

**Problem:** `flutter devices` doesn't show Pixel 6

**Solutions:**

1. Enable USB debugging on phone
2. Accept "Allow USB debugging" prompt
3. Try different USB cable/port
4. Install USB drivers (usually automatic on Windows)
5. Restart ADB: `adb kill-server && adb start-server`

### App Crashes

**Problem:** App crashes when running

**Solutions:**

1. **Check logs:**

   ```powershell
   flutter logs
   ```

2. **Clean and rebuild:**

   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check permissions:**
   - App may need internet permission
   - Check `android/app/src/main/AndroidManifest.xml`

### Story Generation Fails

**Problem:** Story generation doesn't work

**Solutions:**

1. Check backend logs for errors
2. Verify backend health: `curl http://localhost:8080/health`
3. Check Azure service configuration (if using)
4. Check network connectivity
5. Try a simpler prompt first

## Current Backend Status

✅ Backend is running on `http://localhost:8080`

- Health endpoint: `/health`
- Story endpoint: `/api/v1/story`
- Documentation: `http://localhost:8080/docs` (FastAPI auto-docs)

## Next Steps

1. **Connect Pixel 6** and verify with `flutter devices`
2. **Set up port forwarding** with `adb reverse tcp:8080 tcp:8080`
3. **Run the app** with `flutter run`
4. **Test story generation** and check backend logs
5. **Verify all features** work as expected

## Additional Notes

- The app can run with a local on-device backend (`LocalBackendService`) OR the external backend
- To use external backend (recommended for testing), set `BACKEND_URL` in `.env` file or pass via `--dart-define`
- The `.env` file is automatically loaded - create it from `.env.example` template
- Command-line `--dart-define` values take precedence over `.env` file values
- Supabase is optional - app can work without it for basic testing
- Azure services are optional - backend will work without them (check backend `.env` file)
- First build takes longer (5-10 minutes) due to native code compilation

Good luck testing! 🎉
