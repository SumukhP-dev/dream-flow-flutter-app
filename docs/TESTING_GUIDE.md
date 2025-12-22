# Dream Flow Android Testing Guide

## Current Setup Status

✅ **Android Emulator**: Running (emulator-5554)
✅ **Backend Server**: Starting on http://localhost:8080
✅ **Flutter App**: Building and deploying to emulator

## Testing Checklist

### 1. Authentication Features

#### Sign Up
- [ ] Navigate to sign up screen
- [ ] Enter email and password
- [ ] Enter full name (optional)
- [ ] Verify successful account creation
- [ ] Check if redirected to home screen after sign up

#### Sign In
- [ ] Enter valid email and password
- [ ] Verify successful login
- [ ] Check if redirected to home screen
- [ ] Test with invalid credentials (should show error)

#### Sign Out
- [ ] Access sign out functionality
- [ ] Verify user is logged out
- [ ] Check if redirected to login screen

### 2. Home Screen Features

#### Profile Setup
- [ ] Enter current mood
- [ ] Enter nightly ritual/routine
- [ ] Add favorite characters (comma-separated)
- [ ] Add calming elements (comma-separated)
- [ ] Select sensory preferences (checkboxes)
- [ ] Verify all fields are saved

#### Story Generation
- [ ] Enter story prompt/description
- [ ] Select theme from featured worlds
- [ ] Adjust target length slider
- [ ] Select number of scenes
- [ ] Choose voice preset
- [ ] Click "Generate Story" button
- [ ] Verify loading state appears
- [ ] Check if story generation completes
- [ ] Verify navigation to session screen

### 3. Session Screen Features

#### Video Playback
- [ ] Verify video loads and displays
- [ ] Test video controls (play/pause)
- [ ] Verify video loops correctly
- [ ] Test mute functionality

#### Story Display
- [ ] Verify story text is displayed correctly
- [ ] Check paragraph formatting
- [ ] Scroll through full story

#### Scene Frames Gallery
- [ ] Verify frames are displayed horizontally
- [ ] Check frame images load correctly
- [ ] Test horizontal scrolling
- [ ] Verify frame count matches num_scenes

#### Audio Controls
- [ ] Verify audio status text updates correctly
  - Should show "Narration playing" when playing
  - Should show "Narration paused" when paused
- [ ] Test play/pause button
- [ ] Verify audio plays in background
- [ ] Check audio status interpolation: "Gentle looping voice" vs "Gentle ready voice"
- [ ] Test audio stops when paused

### 4. UI/UX Testing

#### Color API Fixes
- [ ] Verify no visual glitches from color API changes
- [ ] Check all screens render correctly
- [ ] Verify gradients and shadows display properly
- [ ] Test on different screen sizes (if available)

#### Navigation
- [ ] Test back button functionality
- [ ] Verify smooth transitions between screens
- [ ] Check app bar navigation

#### Error Handling
- [ ] Test with no internet connection
- [ ] Test with invalid backend URL
- [ ] Verify error messages display correctly
- [ ] Test recovery from error states

### 5. Backend Integration

#### API Connectivity
- [ ] Verify backend health endpoint responds
- [ ] Test story generation API call
- [ ] Check CORS configuration (if testing from web)
- [ ] Verify asset URLs are accessible

#### Supabase Integration
- [ ] Verify user authentication works
- [ ] Check profile data is saved to Supabase
- [ ] Test session data persistence
- [ ] Verify RLS policies work correctly

### 6. Performance Testing

- [ ] Check app startup time
- [ ] Test story generation response time
- [ ] Verify video/audio loading performance
- [ ] Check memory usage during story playback
- [ ] Test app stability during long sessions

## Known Issues to Watch For

1. **Backend Connection**: Ensure backend is running on port 8080
2. **Android Emulator Network**: Uses `10.0.2.2:8080` to access localhost
3. **Supabase Configuration**: Requires valid credentials via --dart-define
4. **Asset Loading**: Generated assets may take time to load

## Testing Commands

### Start Backend
```powershell
cd backend_fastapi
.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8080
```

### Run Flutter App
```powershell
cd frontend_flutter
flutter run -d emulator-5554 `
  --dart-define=SUPABASE_URL=https://dbpvmfglduprtbpaygmo.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_secret_f7om8DHi_eeV89aYbwVJXQ_uc546iWP `
  --dart-define=BACKEND_URL=http://10.0.2.2:8080
```

### Check Backend Health
```powershell
Invoke-WebRequest -Uri "http://localhost:8080/health"
```

## Troubleshooting

### App Won't Start
- Check if emulator is fully booted
- Verify Flutter dependencies are installed: `flutter pub get`
- Check for compilation errors in console

### Backend Not Responding
- Verify backend is running: Check for uvicorn process
- Check port 8080 is not in use
- Verify .env file has correct configuration

### Authentication Fails
- Verify Supabase credentials are correct
- Check network connectivity
- Verify Supabase project is active

### Story Generation Fails
- Check backend logs for errors
- Verify HUGGINGFACE_API_TOKEN is set
- Check backend is accessible from emulator (10.0.2.2:8080)

## Test Results Template

```
Date: [Date]
Tester: [Name]
Emulator: emulator-5554
Flutter Version: [Version]
Backend Status: [Running/Not Running]

### Test Results:
- Authentication: [Pass/Fail/Notes]
- Home Screen: [Pass/Fail/Notes]
- Story Generation: [Pass/Fail/Notes]
- Session Screen: [Pass/Fail/Notes]
- Audio Controls: [Pass/Fail/Notes]
- UI/UX: [Pass/Fail/Notes]

### Issues Found:
1. [Issue description]
2. [Issue description]

### Recommendations:
- [Recommendation]
```

