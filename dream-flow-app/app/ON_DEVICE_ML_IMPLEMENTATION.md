# On-Device ML Implementation Guide

## Overview

The Dream Flow app now uses on-device machine learning for all AI operations:
- **Story Generation**: On-device language models
- **Image Generation**: On-device Stable Diffusion models  
- **Text-to-Speech**: On-device TTS (native APIs or models)

## Platform Support

### iOS
- Uses **Core ML** framework
- Leverages **Neural Engine** on A12 Bionic and later chips
- Best performance on iPhone 12 and later, iPad Pro

### Android
- Uses **TensorFlow Lite**
- Leverages **Tensor chip** on Google Pixel devices
- Uses **NPU/GPU** acceleration on other devices via NNAPI
- Best performance on Pixel 6+ and recent flagship devices

## Current Status

The infrastructure is in place with placeholder implementations. To complete the implementation:

### 1. Story Generation Models

**Recommended Models:**
- **Small/Medium**: DistilGPT-2, GPT-2 Small (150M-350M parameters)
- **Better Quality**: Llama 2 7B quantized, Llama 3 8B quantized
- **Size Consideration**: Models should be <2GB for mobile apps

**iOS Implementation:**
```swift
// ios/Runner/OnDeviceML.swift
import CoreML

class StoryGenerator {
    var model: MLModel?
    
    func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: "story_model", withExtension: "mlmodel") else {
            return
        }
        model = try? MLModel(contentsOf: modelURL)
    }
    
    func generate(prompt: String) -> String {
        // Tokenize prompt, run inference, decode output
        // Use Neural Engine acceleration automatically
    }
}
```

**Android Implementation:**
```dart
// Using tflite_flutter package
import 'package:tflite_flutter/tflite_flutter.dart';

class StoryGenerator {
  Interpreter? _interpreter;
  
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('models/story_model.tflite');
    // Use NNAPI delegate for Tensor chip acceleration
    final options = InterpreterOptions()
      ..threads = 4
      ..useGpuDelegateV2 = true;
  }
  
  Future<String> generate(String prompt) async {
    // Tokenize prompt, prepare input tensor
    // Run inference, decode output
  }
}
```

### 2. Image Generation Models

**Stable Diffusion Models:**
- Core ML Stable Diffusion (iOS): ~4-6GB total
- TensorFlow Lite Stable Diffusion (Android): ~4-6GB total
- Consider downloading on first launch due to size

### 3. Text-to-Speech

**iOS:**
```swift
import AVFoundation

let synthesizer = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: text)
utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
synthesizer.speak(utterance)
```

**Android:**
```dart
import 'package:flutter_tts/flutter_tts.dart';

final FlutterTts flutterTts = FlutterTts();
await flutterTts.setLanguage("en-US");
await flutterTts.speak(text);
```

## Model Preparation

### Converting Models for iOS (Core ML)

1. **PyTorch → Core ML:**
```python
import coremltools as ct
import torch

# Load PyTorch model
model = torch.load('model.pt')
model.eval()

# Convert to Core ML
mlmodel = ct.convert(
    model,
    inputs=[ct.TensorType(name="input", shape=(1, 512))],
    outputs=[ct.TensorType(name="output")],
    minimum_deployment_target=ct.target.iOS15,
)

# Optimize for Neural Engine
mlmodel = ct.models.neural_network.quantization_utils.quantize_weights(mlmodel, nbits=8)

# Save
mlmodel.save("StoryModel.mlmodel")
```

2. **TensorFlow → Core ML:**
```python
import coremltools as ct

mlmodel = ct.convert('model.pb')
mlmodel.save("StoryModel.mlmodel")
```

### Converting Models for Android (TensorFlow Lite)

1. **TensorFlow → TFLite:**
```python
import tensorflow as tf

# Load model
model = tf.keras.models.load_model('model.h5')

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]  # Quantization

tflite_model = converter.convert()

# Save
with open('model.tflite', 'wb') as f:
    f.write(tflite_model)
```

2. **Quantization for smaller size:**
```python
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8
```

## Adding Models to App

### iOS

1. **Bundle with app:**
   - Add `.mlmodel` files to Xcode project
   - Drag into `ios/Runner/Resources/`
   - Ensure "Copy Bundle Resources" includes them

2. **Download at runtime:**
   ```swift
   let url = URL(string: "https://your-cdn.com/models/StoryModel.mlmodel")!
   let downloadTask = URLSession.shared.downloadTask(with: url) { localURL, _, _ in
       if let localURL = localURL {
           let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
           let destinationURL = documentsPath.appendingPathComponent("StoryModel.mlmodel")
           try? FileManager.default.moveItem(at: localURL, to: destinationURL)
       }
   }
   downloadTask.resume()
   ```

### Android

1. **Bundle with app:**
   - Place `.tflite` files in `android/app/src/main/assets/models/`
   - Access via `await rootBundle.load('assets/models/model.tflite')`

2. **Download at runtime:**
   ```dart
   final response = await http.get(Uri.parse('https://your-cdn.com/models/model.tflite'));
   final file = File('${appDocumentsDir}/models/model.tflite');
   await file.writeAsBytes(response.bodyBytes);
   ```

## Performance Optimization

1. **Use quantized models** (INT8) for 4x size reduction and faster inference
2. **Enable hardware acceleration:**
   - iOS: Core ML automatically uses Neural Engine
   - Android: Use NNAPI delegate for Tensor chip/NPU
3. **Batch processing** when possible
4. **Model caching** - load once, reuse
5. **Lazy loading** - load models only when needed

## Privacy & Security

✅ **All processing happens on-device**  
✅ **No data leaves the device**  
✅ **Works completely offline**  
✅ **User privacy protected**

## Testing

1. Test on various devices (old and new)
2. Monitor memory usage
3. Check inference speed
4. Verify quality of generated content
5. Test offline functionality

## Next Steps

1. Choose appropriate models (size vs quality tradeoff)
2. Convert models to Core ML (iOS) and TFLite (Android)
3. Implement actual inference code (replace placeholders)
4. Add model download/caching
5. Optimize for performance
6. Test thoroughly

