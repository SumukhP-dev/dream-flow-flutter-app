# Quick Start Commands - Pixel 6 Testing

## Status Check Commands

```powershell
# Check if Pixel 6 is connected
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adbPath devices

# Check port forwarding
& $adbPath reverse --list

# Check Flutter devices
cd "C:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\dream-flow-app\app"
flutter devices

# Check backend health
curl http://localhost:8080/health
```

## Setup Commands (Run Once)

```powershell
# 1. Set up port forwarding
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adbPath reverse tcp:8080 tcp:8080

# 2. Verify port forwarding
& $adbPath reverse --list
```

## Run App Command

```powershell
# Navigate to app directory
cd "C:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\dream-flow-app\app"

# Get your device ID first
flutter devices

# Run app (replace DEVICE_ID with your actual device ID from above)
flutter run -d DEVICE_ID --dart-define=BACKEND_URL=http://localhost:8080
```

## Troubleshooting OneDrive Issues

If you get file system errors due to OneDrive sync:

1. **Wait for OneDrive to finish syncing** (check system tray icon)
2. **Or pause OneDrive sync temporarily:**
   - Right-click OneDrive icon → Settings → Sync and backup
   - Pause syncing for 2 hours
   - Run Flutter command
   - Resume syncing when done

## Current Configuration

- **Backend URL:** http://localhost:8080
- **Port Forwarding:** Enabled via ADB
- **Device:** Pixel 6 (check device ID with `flutter devices`)
- **Backend Status:** Running (verify with `curl http://localhost:8080/health`)































