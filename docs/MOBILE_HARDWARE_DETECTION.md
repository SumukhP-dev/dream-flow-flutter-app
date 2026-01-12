# Mobile Hardware Detection & Smart Model Selection

## Overview

The backend now automatically detects mobile hardware capabilities and selects the optimal inference method:

1. **Native Mobile Accelerators** (Highest Priority)
   - Android: Tensor chip (Pixel 6+) or NPU
   - iOS: Neural Engine (A12 Bionic+)
   - Uses native ML frameworks (TFLite/Core ML) when available

2. **GGUF Models** (Fallback)
   - Runs on CPU via llama-cpp-python
   - Works on all devices, including those without accelerators

## Detection Flow

```
Request → Detect Hardware → Select Method → Fallback if Needed
```

### Detection Priority

1. **Check for Native Accelerators:**
   - Android: Detects Tensor chip (Pixel 6+) or NPU via User-Agent + environment variables
   - iOS: Detects Neural Engine (A12+) via User-Agent + environment variables
   - Checks if native ML models (TFLite/Core ML) are available

2. **If Native Available:**
   - Use `native_mobile` inference mode
   - Leverages hardware acceleration for best performance

3. **If Native Not Available:**
   - Fall back to `local` inference mode
   - Uses GGUF models with llama-cpp-python
   - Runs on CPU (works on all devices)

## How It Works

### For Bundled Backend (Mobile App)

When the FastAPI backend is bundled into the mobile app:

1. **Mobile app detects hardware** on startup:
   ```dart
   // Flutter/Dart code sets environment variables
   // Android: Check for Tensor chip via Android APIs
   // iOS: Check for Neural Engine via iOS APIs
   ```

2. **Pass capabilities to backend:**
   ```python
   # Set environment variables before starting Python backend
   os.environ["MOBILE_PLATFORM"] = "android"  # or "ios"
   os.environ["HAS_TENSOR_CHIP"] = "true"  # Android
   os.environ["HAS_NEURAL_ENGINE"] = "true"  # iOS
   os.environ["HAS_TFLITE_MODELS"] = "true"  # Android
   os.environ["HAS_COREML_MODELS"] = "true"  # iOS
   ```

3. **Backend detects and selects:**
   - `detect_native_mobile_version()` checks environment variables
   - Returns `True` if native accelerator AND models are available
   - Backend selects `native_mobile` mode automatically

### For HTTP Requests (Current Implementation)

When backend receives HTTP requests:

1. **Extract User-Agent** from request headers
2. **Detect device type** from User-Agent:
   - Android: Checks for "android" and "pixel" (Tensor chip devices)
   - iOS: Checks for "iphone"/"ipad" and iOS version (Neural Engine devices)

3. **Check for native models:**
   - Currently relies on environment variables set by mobile app
   - Future: Could check model files in app bundle

4. **Select inference mode:**
   - If native available: Use `native_mobile`
   - Otherwise: Use `local` (GGUF models)

## Implementation Details

### Detection Functions

```python
# backend_fastapi/app/core/version_detector.py

detect_native_mobile_accelerator(user_agent) -> (bool, str)
# Returns: (has_accelerator, accelerator_type)
# Types: "tensor", "neural_engine", "npu", "none"

detect_native_mobile_version(user_agent) -> bool
# Returns True if native accelerator AND models are available

get_recommended_version(user_agent) -> InferenceVersion
# Returns: "native_mobile", "local", "google", or "apple"
# Priority: native_mobile > google > apple > local
```

### Generator Selection

```python
# backend_fastapi/app/core/services.py

get_generators(prompt_builder, user_agent=None) -> tuple
# Auto-detects best inference method
# Falls back gracefully: native_mobile → local
```

### Current Status

✅ **Detection Logic:** Implemented
✅ **Fallback Chain:** Implemented  
✅ **GGUF Models:** Bundled and ready
⏳ **Native ML Models:** Need to be added (TFLite/Core ML)
⏳ **Mobile App Integration:** Need to set environment variables from Flutter

## Next Steps

### 1. Add Native ML Models

**Android (TFLite):**
- Convert GGUF models to TFLite format
- Place in `android/app/src/main/assets/models/`
- Backend checks via `HAS_TFLITE_MODELS` env var

**iOS (Core ML):**
- Convert GGUF models to Core ML format
- Place in `ios/Runner/Resources/Models/`
- Backend checks via `HAS_COREML_MODELS` env var

### 2. Mobile App Integration

**Flutter/Dart code to detect hardware:**

```dart
// Detect Android Tensor chip
Future<bool> hasTensorChip() async {
  if (!Platform.isAndroid) return false;
  // Use platform channel to check Android system properties
  // or use DeviceInfoPlugin to detect Pixel 6+
}

// Detect iOS Neural Engine
Future<bool> hasNeuralEngine() async {
  if (!Platform.isIOS) return false;
  // Check device model (A12 Bionic and later)
  // iPhone XS, XR and later have Neural Engine
}
```

**Set environment variables before starting Python backend:**

```dart
// Before starting bundled Python backend
if (Platform.isAndroid) {
  await setEnvVar("MOBILE_PLATFORM", "android");
  await setEnvVar("HAS_TENSOR_CHIP", hasTensor ? "true" : "false");
  await setEnvVar("HAS_TFLITE_MODELS", hasTfliteModels ? "true" : "false");
} else if (Platform.isIOS) {
  await setEnvVar("MOBILE_PLATFORM", "ios");
  await setEnvVar("HAS_NEURAL_ENGINE", hasNeuralEngine ? "true" : "false");
  await setEnvVar("HAS_COREML_MODELS", hasCoreMLModels ? "true" : "false");
}
```

### 3. Implement Native Mobile Generators

Currently, `native_mobile` mode falls back to `local` generators. To fully implement:

1. Create platform channels (Flutter → Native)
2. Implement native ML inference (Kotlin/Swift)
3. Bridge between Python backend and native ML

OR

1. Keep Python backend for logic
2. Use native ML frameworks directly from Flutter
3. Backend coordinates but doesn't run inference

## Testing

### Test Detection

```python
from app.core.version_detector import detect_native_mobile_accelerator, detect_native_mobile_version

# Test with User-Agent
user_agent = "Mozilla/5.0 (Linux; Android 13; Pixel 7) ..."
has_accel, accel_type = detect_native_mobile_accelerator(user_agent)
print(f"Accelerator: {accel_type}, Available: {has_accel}")

# Test with environment variables (for bundled backend)
import os
os.environ["MOBILE_PLATFORM"] = "android"
os.environ["HAS_TENSOR_CHIP"] = "true"
os.environ["HAS_TFLITE_MODELS"] = "true"
available = detect_native_mobile_version()
print(f"Native mobile available: {available}")
```

## Summary

✅ **Hardware detection is implemented**
✅ **Smart selection logic is ready**
✅ **GGUF models are bundled as fallback**
⏳ **Native ML models need to be added**
⏳ **Mobile app needs to pass hardware info**

The backend will automatically:
1. Detect if Tensor chip/Neural Engine is available
2. Use native accelerators if available (best performance)
3. Fall back to GGUF models if not (works everywhere)

