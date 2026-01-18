import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Flutter bridge to iOS Core ML image generation (Stable Diffusion)
/// Communicates with native Swift code via MethodChannel
class CoreMLImageLoader {
  static const platform = MethodChannel('com.dreamflow/ml');

  bool _loaded = false;

  /// Load the Core ML Stable Diffusion models
  Future<void> load() async {
    if (_loaded) {
      debugPrint('CoreML image models already loaded');
      return;
    }

    try {
      final result = await platform.invokeMethod('loadImageModel');
      if (result == true) {
        _loaded = true;
        debugPrint('✓ CoreML image models loaded successfully');
      } else {
        throw Exception('Failed to load models');
      }
    } on PlatformException catch (e) {
      debugPrint('Error loading CoreML image models: ${e.message}');
      rethrow;
    }
  }

  /// Generate images from text prompt
  Future<List<Uint8List>> generate({
    required String prompt,
    int numImages = 4,
    int width = 384,
    int height = 384,
    int numInferenceSteps = 10,
    double guidanceScale = 7.5,
  }) async {
    if (!_loaded) {
      await load();
    }

    try {
      final result =
          await platform.invokeMethod<List<Object?>>('generateImages', {
        'prompt': prompt,
        'numImages': numImages,
        'width': width,
        'height': height,
        'numInferenceSteps': numInferenceSteps,
        'guidanceScale': guidanceScale,
      });

      if (result == null) {
        throw Exception('No result from image generation');
      }

      // Convert result to List<Uint8List>
      final images = <Uint8List>[];
      for (final item in result) {
        if (item is Uint8List) {
          images.add(item);
        } else {
          debugPrint(
              'Warning: Unexpected image data type: ${item.runtimeType}');
        }
      }

      debugPrint('✓ Generated ${images.length} images with CoreML');
      return images;
    } on PlatformException catch (e) {
      debugPrint('Error generating images with CoreML: ${e.message}');
      rethrow;
    }
  }

  /// Check if models are loaded
  Future<bool> isLoaded() async {
    try {
      final result = await platform.invokeMethod<bool>('isImageModelLoaded');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking CoreML image model status: ${e.message}');
      return false;
    }
  }

  /// Unload the models and free resources
  Future<void> unload() async {
    try {
      await platform.invokeMethod('unloadImageModel');
      _loaded = false;
      debugPrint('CoreML image models unloaded');
    } on PlatformException catch (e) {
      debugPrint('Error unloading CoreML image models: ${e.message}');
    }
  }
}
