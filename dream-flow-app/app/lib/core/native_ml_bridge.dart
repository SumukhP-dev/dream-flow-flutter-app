import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge service for calling native ML inference via platform channels
///
/// Supports:
/// - iOS: Core ML (Neural Engine)
/// - Android: TensorFlow Lite (Tensor chip/NPU/GPU)
class NativeMLBridge {
  static NativeMLBridge? _instance;
  static NativeMLBridge get instance => _instance ??= NativeMLBridge._();

  NativeMLBridge._();

  static const MethodChannel _mlChannel = MethodChannel('com.dreamflow/ml');
  bool _storyModelLoaded = false;
  bool _imageModelLoaded = false;

  /// Load story generation model
  Future<bool> loadStoryModel({String? modelPath}) async {
    try {
      final result = await _mlChannel.invokeMethod<bool>(
        'loadStoryModel',
        {'path': modelPath},
      );
      _storyModelLoaded = result ?? false;
      debugPrint('Story model loaded: $_storyModelLoaded');
      return _storyModelLoaded;
    } on PlatformException catch (e) {
      debugPrint('Error loading story model: ${e.message}');
      _storyModelLoaded = false;
      return false;
    } catch (e) {
      debugPrint('Unexpected error loading story model: $e');
      _storyModelLoaded = false;
      return false;
    }
  }

  /// Generate story text using native ML model
  Future<String> generateStory({
    required String prompt,
    int maxTokens = 200,
    double temperature = 0.8,
  }) async {
    if (!_storyModelLoaded) {
      // Try to load model automatically
      final loaded = await loadStoryModel();
      if (!loaded) {
        throw Exception(
            'Story model not loaded and failed to load automatically');
      }
    }

    try {
      final result = await _mlChannel.invokeMethod<String>(
        'generateStory',
        {
          'prompt': prompt,
          'maxTokens': maxTokens,
          'temperature': temperature,
        },
      );
      return result ?? '';
    } on PlatformException catch (e) {
      debugPrint('Error generating story: ${e.message}');
      throw Exception('Failed to generate story: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error generating story: $e');
      throw Exception('Failed to generate story: $e');
    }
  }

  /// Load image generation model
  Future<bool> loadImageModel({String? modelPath}) async {
    try {
      final result = await _mlChannel.invokeMethod<bool>(
        'loadImageModel',
        {'path': modelPath},
      );
      _imageModelLoaded = result ?? false;
      debugPrint('Image model loaded: $_imageModelLoaded');
      return _imageModelLoaded;
    } on PlatformException catch (e) {
      debugPrint('Error loading image model: ${e.message}');
      _imageModelLoaded = false;
      return false;
    } catch (e) {
      debugPrint('Unexpected error loading image model: $e');
      _imageModelLoaded = false;
      return false;
    }
  }

  /// Generate image using native ML model
  Future<List<int>> generateImage({
    required String prompt,
    int width = 512,
    int height = 512,
    int numInferenceSteps = 20,
  }) async {
    if (!_imageModelLoaded) {
      // Try to load model automatically
      final loaded = await loadImageModel();
      if (!loaded) {
        throw Exception(
            'Image model not loaded and failed to load automatically');
      }
    }

    try {
      final result = await _mlChannel.invokeMethod<List<int>>(
        'generateImage',
        {
          'prompt': prompt,
          'width': width,
          'height': height,
          'numInferenceSteps': numInferenceSteps,
        },
      );
      return result ?? [];
    } on PlatformException catch (e) {
      debugPrint('Error generating image: ${e.message}');
      // If not implemented, return empty list (will use placeholder)
      if (e.code == 'NOT_IMPLEMENTED') {
        return [];
      }
      throw Exception('Failed to generate image: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error generating image: $e');
      throw Exception('Failed to generate image: $e');
    }
  }

  /// Check if story model is loaded
  bool get isStoryModelLoaded => _storyModelLoaded;

  /// Check if image model is loaded
  bool get isImageModelLoaded => _imageModelLoaded;

  /// Initialize models (load both story and image models)
  Future<void> initialize() async {
    if (Platform.isIOS || Platform.isAndroid) {
      // Try to load models from bundle/assets
      await loadStoryModel();
      await loadImageModel();
    }
  }
}
