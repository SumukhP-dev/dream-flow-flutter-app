import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Flutter bridge to iOS Core ML story generation
/// Communicates with native Swift code via MethodChannel
class CoreMLStoryLoader {
  static const platform = MethodChannel('com.dreamflow/ml');

  bool _loaded = false;

  /// Load the Core ML story model
  Future<void> load() async {
    if (_loaded) {
      debugPrint('CoreML story model already loaded');
      return;
    }

    try {
      final result = await platform.invokeMethod('loadStoryModel');
      if (result == true) {
        _loaded = true;
        debugPrint('✓ CoreML story model loaded successfully');
      } else {
        throw Exception('Failed to load model');
      }
    } on PlatformException catch (e) {
      debugPrint('Error loading CoreML story model: ${e.message}');
      rethrow;
    }
  }

  /// Generate story text from prompt
  Future<String> generate({
    required String prompt,
    int maxTokens = 200,
    double temperature = 0.8,
  }) async {
    if (!_loaded) {
      await load();
    }

    try {
      final result = await platform.invokeMethod<String>('generateStory', {
        'prompt': prompt,
        'maxTokens': maxTokens,
        'temperature': temperature,
      });

      if (result == null) {
        throw Exception('No result from story generation');
      }

      return result;
    } on PlatformException catch (e) {
      debugPrint('Error generating story with CoreML: ${e.message}');
      rethrow;
    }
  }

  /// Check if model is loaded
  Future<bool> isLoaded() async {
    try {
      final result = await platform.invokeMethod<bool>('isStoryModelLoaded');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking CoreML story model status: ${e.message}');
      return false;
    }
  }

  /// Unload the model and free resources
  Future<void> unload() async {
    try {
      await platform.invokeMethod('unloadStoryModel');
      _loaded = false;
      debugPrint('CoreML story model unloaded');
    } on PlatformException catch (e) {
      debugPrint('Error unloading CoreML story model: ${e.message}');
    }
  }
}
