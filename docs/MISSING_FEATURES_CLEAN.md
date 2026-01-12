# Missing Features & Required Additions

## Summary
This document lists only features that are **NOT implemented** or need work. Everything else is already complete.

---

## 🔴 High Priority: Broken/Incomplete Features

### 1. Flutter TTS Service (Partially Implemented)
**Status**: Package installed but not implemented

**Location**: `dream-flow-app/app/lib/core/tts_service.dart` (lines 42-87)

**Issue**: 
- `flutter_tts: ^4.0.0` is in `pubspec.yaml` but not used
- Contains placeholder TODO comments
- `_ttsEngine` is set to `null`

**Required Implementation**:
```dart
// Replace placeholder code in _initializeAndroid() and _initializeIOS()
import 'package:flutter_tts/flutter_tts.dart';

final FlutterTts flutterTts = FlutterTts();
await flutterTts.setLanguage("en-US");
await flutterTts.setSpeechRate(0.5);
await flutterTts.setVolume(1.0);
await flutterTts.setPitch(1.0);
_ttsEngine = flutterTts;
```

**Also Update**:
- `speak()` method (lines 207-225) - currently just prints debug messages
- `stop()` method (lines 228-239) - currently just prints debug messages

---

### 2. Android TFLite Models (Disabled Due to Compatibility)
**Status**: Temporarily disabled due to `tflite_flutter` package compatibility issues

**Location**: `dream-flow-app/app/lib/core/models/story_model.dart` (lines 73-84)

**Issue**:
- Model loading is commented out
- `_model = null` - using placeholder stories
- Package `tflite_flutter: ^0.10.4` has compatibility issues

**Required Fix**:
1. Fix `tflite_flutter` package compatibility OR use alternative package
2. Uncomment and fix model loading code
3. Test on physical Android device with Tensor chip

**Files Affected**:
- `dream-flow-app/app/lib/core/models/story_model.dart`
- `dream-flow-app/app/lib/core/models/image_model.dart`
- `dream-flow-app/app/lib/core/on_device_ml_service.dart`

---

### 3. iOS Core ML Models (Not Implemented)
**Status**: Not implemented - only Android Kotlin code exists

**Location**: Need to create iOS native implementation

**Required Implementation**:
1. Create iOS Swift code for Core ML model loading
2. Add platform channel methods in Swift
3. Bridge to Flutter via `MethodChannel`
4. Test on physical iOS device

**Files to Create/Modify**:
- `dream-flow-app/app/ios/Runner/AppDelegate.swift` (add platform channel)
- Create `dream-flow-app/app/ios/Runner/CoreMLService.swift` (new file)
- `dream-flow-app/app/lib/core/native_ml_bridge.dart` (ensure iOS support)

---

## 🟡 Medium Priority: Optional Services (Need Configuration)

These services are **fully implemented** in code but need API keys/configuration to work.

### 1. Klaviyo Integration
**Status**: Code complete, needs API key

**Required**:
- `KLAVIYO_API_KEY` environment variable
- Package already installed: `klaviyo-api>=3.0.0`

**Features When Enabled**:
- Event tracking
- Personalization engine
- Churn prediction

---

### 2. Azure Content Safety
**Status**: Code complete, needs API keys

**Required**:
- `AZURE_CONTENT_SAFETY_ENABLED=true`
- `AZURE_CONTENT_SAFETY_ENDPOINT`
- `AZURE_CONTENT_SAFETY_KEY`
- Package already installed: `azure-ai-contentsafety>=1.0.0`

**Features When Enabled**:
- Image/text moderation
- COPPA compliance checks

---

### 3. Sentry Error Tracking
**Status**: Code complete, needs DSN

**Required**:
- `SENTRY_DSN` environment variable
- Package already installed: `sentry-sdk`

**Features When Enabled**:
- Error tracking
- Performance monitoring

---

### 4. Stripe Payments
**Status**: Code complete, needs API keys

**Required**:
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_PUBLISHABLE_KEY`
- Stripe Price IDs (monthly/annual premium/family)

**Features When Enabled**:
- Subscription management
- Payment processing

---

## 🟢 Low Priority: Optional/Experimental Features

### 1. Apple Intelligence API
**Status**: Code exists, API not yet available from Apple

**Required**:
- Wait for Apple Intelligence API release
- Then set `APPLE_INTELLIGENCE_API_KEY`
- Set `ENABLE_APPLE_INTELLIGENCE=true`

**Note**: Apple Intelligence API is not yet publicly available

---

## ✅ Already Complete (No Action Needed)

- ✅ Recommendations API endpoint (`/api/v1/recommendations`)
- ✅ `child_mode` and `child_profile_id` in `StoryRequest` schema
- ✅ Story count increment after generation
- ✅ Supabase integration (if configured)
- ✅ Bilingual translation post-processing
- ✅ Image generation pipeline
- ✅ Audio generation (edge-tts)
- ✅ Story generation (TinyLlama)
- ✅ Guardrails and content safety
- ✅ Subscription system
- ✅ Notification system
- ✅ Family/child mode infrastructure

---

## Quick Reference: What Needs Work

### Code Changes Required:
1. **Flutter TTS Service** - Replace placeholder with actual `flutter_tts` implementation
2. **Android TFLite** - Fix compatibility issues and enable model loading
3. **iOS Core ML** - Create native Swift implementation

### Configuration Required (Optional):
- Klaviyo API key (for analytics)
- Azure Content Safety keys (for moderation)
- Sentry DSN (for error tracking)
- Stripe keys (for payments)

### Already Working (Just Needs Enabling):
- Apple Intelligence API (when available from Apple)

