# Physical Device Testing Guide

## Overview
This guide provides step-by-step instructions for testing the on-device ML features on physical Android and iOS devices.

---

## Prerequisites

### Android
- Physical Android device with USB debugging enabled
- Android SDK and ADB installed
- Device with Android 7.0 (API 24) or higher
- **Recommended**: Pixel 6+ with Tensor chip for best performance

### iOS  
- Physical iOS device (iPhone/iPad) with iOS 12+
- Xcode with valid Apple Developer account
- Device provisioning profile set up
- **Recommended**: iPhone 12+ with Neural Engine (A14+)

---

## Android Testing

### 1. Enable USB Debugging

On your Android device:
1. Go to **Settings > About Phone**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings > Developer Options**
4. Enable **USB Debugging**
5. Connect device via USB and authorize computer

### 2. Verify Device Connection

```bash
# Check connected devices
adb devices

# Should show:
# List of devices attached
# DEVICE_ID    device
```

### 3. Build and Install App

```bash
cd dream-flow-app/app

# Clean build
flutter clean
flutter pub get

# Build and run
flutter run -d <device-id>

# Or build APK and install manually
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 4. Test Story Generation

**Test Steps:**
1. Open app on device
2. Navigate to story creation
3. Enter prompt: "A peaceful adventure in a magical forest"
4. Start generation
5. Monitor logcat for performance metrics

**Monitor Logs:**
```bash
# View Flutter logs
adb logcat | grep -i "flutter\|tflite\|story"

# Expected output:
# ⚡ Story TFLite acceleration: NNAPI (hw=true, threads=4)
# 🎯 Story generation started
# ✓ Story generation completed in 8.5s
```

**Performance Checklist:**
- [ ] Model loads without errors
- [ ] Generation completes in <10 seconds
- [ ] Generated story is coherent
- [ ] No memory warnings
- [ ] No app crashes

### 5. Test Image Generation

**Test Steps:**
1. Continue from story generation
2. Initiate image generation for story
3. Monitor progress (4 images)
4. Verify images display correctly

**Monitor Logs:**
```bash
adb logcat | grep -i "flutter\|stable\|image"

# Expected output:
# ⚡ Image TFLite acceleration: GPU (hw=true)
# 🎨 Starting Stable Diffusion pipeline
# ✓ Generated 4 images in 18.3s
```

**Performance Checklist:**
- [ ] Models load successfully  
- [ ] Generation completes in <20 seconds for 4 images
- [ ] Images are visually coherent
- [ ] Memory usage is acceptable (<2GB)
- [ ] No crashes during generation

### 6. Test TTS Audio

**Test Steps:**
1. Continue from image generation
2. Initiate TTS audio generation
3. Verify audio plays correctly
4. Check audio quality

**Monitor Logs:**
```bash
adb logcat | grep -i "tts\|audio"

# Expected output:
# ✓ TTS service initialized
# 🎵 Audio synthesis started
# ✓ Audio generated in 3.2s
```

**Performance Checklist:**
- [ ] TTS initializes instantly
- [ ] Audio generates in <5 seconds
- [ ] Audio quality is clear
- [ ] Speech rate is appropriate (0.5x)
- [ ] Audio file is valid format

### 7. Full Pipeline Test

**Combined test:**
1. Create new story from scratch
2. Monitor total time from start to finish
3. Verify all components work together

**Target Performance:**
- Story: ≤10s
- Images (4): ≤20s (parallel with audio)
- Audio: ≤5s (parallel with images)
- **Total: ≤30s**

---

## iOS Testing

### 1. Setup Xcode

```bash
cd dream-flow-app/app/ios

# Open workspace
open Runner.xcworkspace
```

In Xcode:
1. Select your development team
2. Update bundle identifier if needed
3. Select your physical device as build target

### 2. Configure Signing

1. In Xcode, go to **Signing & Capabilities**
2. Select your **Team**
3. Ensure **Automatically manage signing** is checked
4. Verify provisioning profile is valid

### 3. Build and Deploy

In Xcode:
1. Select device from dropdown (top left)
2. Press **Cmd+R** to build and run
3. Trust developer certificate on device if prompted

Or via command line:
```bash
# Build for device
flutter build ios --release --no-codesign

# Then deploy via Xcode
```

### 4. Test Story Generation

**Test Steps:**
1. Open app on device
2. Navigate to story creation  
3. Enter prompt: "A peaceful adventure in a magical forest"
4. Start generation
5. Monitor Xcode console for logs

**Expected Console Output:**
```
✓ CoreML Story model loaded successfully (Neural Engine enabled)
🎯 CoreML Story generation started
✓ CoreML Story generation completed (placeholder mode)
```

**Performance Checklist:**
- [ ] Core ML model loads without errors
- [ ] Generation completes in <10 seconds
- [ ] Neural Engine is utilized (check in Instruments)
- [ ] No memory warnings
- [ ] No crashes

### 5. Test Image Generation

**Test Steps:**
1. Continue from story generation
2. Initiate image generation
3. Monitor console logs
4. Verify images display

**Expected Console Output:**
```
✓ CoreML Stable Diffusion models loaded successfully
🎨 CoreML Image generation started
✓ CoreML Image generation completed (4 images, placeholder mode)
```

**Performance Checklist:**
- [ ] Core ML models load successfully
- [ ] Generation completes in <20 seconds
- [ ] Images are valid format
- [ ] Memory usage acceptable
- [ ] No crashes

### 6. Test TTS Audio

**Test Steps:**
1. Continue from image generation
2. Initiate TTS generation
3. Play audio
4. Verify quality

**Expected Console Output:**
```
✓ TTS service initialized successfully
iOS TTS initialized successfully
iOS TTS synthesis completed
```

**Performance Checklist:**
- [ ] AVSpeechSynthesizer initializes instantly
- [ ] Audio generates in <5 seconds
- [ ] Voice quality is high
- [ ] Appropriate speech rate
- [ ] Audio plays correctly

### 7. Profile with Instruments

For detailed performance analysis:

1. In Xcode, go to **Product > Profile** (Cmd+I)
2. Select **Core ML** template
3. Run full story generation pipeline
4. Analyze:
   - Neural Engine utilization
   - Memory usage
   - Inference times
   - CPU/GPU usage

**Target Metrics:**
- Neural Engine utilization: >80% during inference
- Memory peak: <2GB
- No thermal throttling warnings

---

## Common Issues and Solutions

### Android

**Issue:** "Failed to load TFLite model"
**Solution:**
```bash
# Verify model files are bundled
adb shell ls /data/app/.../lib/arm64-v8a/*.so
# Check build.gradle includes models
```

**Issue:** "NNAPI delegate creation failed"
**Solution:**
- Device may not support NNAPI
- App should fall back to GPU or XNNPACK
- Check logs for alternative delegate

**Issue:** "Out of memory"
**Solution:**
- Model files may be too large
- Enable memory optimization in build
- Test on device with more RAM

### iOS

**Issue:** "Core ML model not found"
**Solution:**
```bash
# Verify model is in bundle
# Check Runner.xcodeproj for model references
# Ensure .mlmodelc is included in build phases
```

**Issue:** "Platform channel error"
**Solution:**
- Verify AppDelegate.swift changes are compiled
- Check method channel name matches Flutter side
- Rebuild Xcode project

**Issue:** "Signing error"
**Solution:**
- Update provisioning profile
- Check bundle ID is unique
- Verify team membership

---

## Performance Benchmarking

### Automated Benchmark Script

Create `benchmark_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dream_flow/core/on_device_ml_service.dart';

void main() {
  test('Benchmark story generation', () async {
    final service = OnDeviceMLService.instance;
    await service.initialize();
    
    final stopwatch = Stopwatch()..start();
    final story = await service.generateStory(
      prompt: 'A magical forest',
      theme: 'Aurora Dreams',
    );
    stopwatch.stop();
    
    print('Story generation time: ${stopwatch.elapsedMilliseconds}ms');
    expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // <10s
  });
  
  test('Benchmark image generation', () async {
    final service = OnDeviceMLService.instance;
    await service.initialize();
    
    final stopwatch = Stopwatch()..start();
    final images = await service.generateImages(
      prompt: 'A magical forest',
      theme: 'Aurora Dreams',
      numImages: 4,
    );
    stopwatch.stop();
    
    print('Image generation time: ${stopwatch.elapsedMilliseconds}ms');
    expect(stopwatch.elapsedMilliseconds, lessThan(20000)); // <20s
    expect(images.length, equals(4));
  });
}
```

Run benchmarks:
```bash
flutter test test/benchmark_test.dart
```

---

## Test Results Template

Document your test results:

```markdown
## Test Results

**Device**: [e.g., Pixel 6, iPhone 13 Pro]
**OS Version**: [e.g., Android 13, iOS 16.3]
**Date**: [YYYY-MM-DD]

### Story Generation
- Model Load Time: [X.X]s
- Inference Time: [X.X]s
- Memory Usage: [XXX]MB
- Status: [PASS/FAIL]
- Notes: [any issues or observations]

### Image Generation
- Model Load Time: [X.X]s
- Inference Time (4 images): [X.X]s
- Memory Usage Peak: [XXX]MB
- Status: [PASS/FAIL]
- Notes: [any issues or observations]

### TTS Audio
- Initialization Time: [X.X]s
- Synthesis Time: [X.X]s
- Audio Quality: [Excellent/Good/Poor]
- Status: [PASS/FAIL]

### Total Pipeline
- End-to-End Time: [X.X]s
- Target Met (<30s): [YES/NO]
- Overall Status: [PASS/FAIL]
```

---

## Next Steps

After successful device testing:

1. ✅ Verify all features work end-to-end
2. ✅ Document performance metrics
3. ✅ Compare Android vs iOS performance
4. ✅ Identify any platform-specific issues
5. ✅ Optimize if performance targets not met
6. ✅ Proceed to production testing

---

## Support

For issues during testing:
- Check logs for specific error messages
- Verify model files are correctly placed
- Ensure device meets minimum requirements
- Review troubleshooting section above
