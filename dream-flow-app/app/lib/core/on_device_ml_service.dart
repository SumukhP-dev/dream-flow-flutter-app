import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'models/story_model.dart';
import 'models/image_model.dart';
import 'tts_service.dart';
import 'voice_selection_service.dart';

/// Service for on-device machine learning inference
/// Supports:
/// - Android: TensorFlow Lite (uses Tensor chip on Pixel devices)
/// - iOS: Core ML (uses Neural Engine on Apple devices)
class OnDeviceMLService {
  static OnDeviceMLService? _instance;
  static OnDeviceMLService get instance => _instance ??= OnDeviceMLService._();

  OnDeviceMLService._();

  bool _initialized = false;
  String? _modelPath;
  StoryModelLoader? _storyModelLoader;
  ImageModelLoader? _imageModelLoader;
  TTSService? _ttsService;

  /// Initialize the ML service and load models
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Platform.isIOS) {
        await _initializeIOS();
      } else if (Platform.isAndroid) {
        await _initializeAndroid();
      } else {
        throw UnsupportedError(
            'On-device ML is only supported on iOS and Android');
      }

      _initialized = true;
      debugPrint('OnDeviceMLService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize OnDeviceMLService: $e');
      rethrow;
    }
  }

  /// Initialize for iOS using Core ML
  Future<void> _initializeIOS() async {
    // On iOS, we'll use Core ML through platform channels
    // Models should be bundled in the app bundle under Resources/
    // For now, we'll set up the path structure
    final appDir = await getApplicationDocumentsDirectory();
    _modelPath = path.join(appDir.path, 'models');

    // Create models directory if it doesn't exist
    final modelDir = Directory(_modelPath!);
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    debugPrint('iOS Core ML initialization - models directory: $_modelPath');
    // Note: Actual Core ML model loading would be done through platform channels
    // or using a Flutter plugin that supports Core ML

    // Initialize model loaders and services
    _storyModelLoader = StoryModelLoader.instance;
    _imageModelLoader = ImageModelLoader.instance;
    _ttsService = TTSService.instance;
  }

  /// Initialize for Android using TensorFlow Lite
  Future<void> _initializeAndroid() async {
    // On Android, we'll use TensorFlow Lite
    // Models should be in assets/models/ or downloaded to app directory
    final appDir = await getApplicationDocumentsDirectory();
    _modelPath = path.join(appDir.path, 'models');

    // Create models directory if it doesn't exist
    final modelDir = Directory(_modelPath!);
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    debugPrint(
        'Android TensorFlow Lite initialization - models directory: $_modelPath');
    // Note: Actual TFLite model loading would be done using tflite_flutter package

    // Initialize model loaders and services
    _storyModelLoader = StoryModelLoader.instance;
    _imageModelLoader = ImageModelLoader.instance;
    _ttsService = TTSService.instance;
  }

  /// Generate story text using on-device model
  /// Target: <10 seconds on CPU-only devices
  /// Max tokens reduced for faster inference
  Future<String> generateStory({
    required String prompt,
    required String theme,
    int maxTokens = 200, // Reduced from 400 for faster generation
    Map<String, dynamic>? profile,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Build context-aware prompt
      final profileContext = profile != null
          ? ' Mood: ${profile['mood'] ?? ''}, Routine: ${profile['routine'] ?? ''}, Preferences: ${profile['preferences']?.join(', ') ?? ''}'
          : '';

      final fullPrompt =
          'Generate a soothing bedtime story about: $prompt, Theme: $theme$profileContext';

      // Use story model loader for actual inference
      if (_storyModelLoader != null) {
        return await _storyModelLoader!.generate(
          prompt: fullPrompt,
          maxTokens: maxTokens,
          temperature: 0.8,
        );
      }

      // Fallback if model loader not initialized - return empty to indicate unavailable
      debugPrint('Story model loader not initialized, returning empty string');
      return '';
    } catch (e) {
      debugPrint('Error generating story with model: $e');
      // Return empty string to indicate failure - let higher level services handle fallback
      return '';
    }
  }

  /// Generate image frames using on-device model (Stable Diffusion)
  /// Target: <20 seconds total (can run in parallel)
  /// Optimized for faster CPU inference
  Future<List<Uint8List>> generateImages({
    required String prompt,
    required String theme,
    int numImages = 4,
    int width = 384, // Reduced from 512 for faster generation
    int height = 384, // Reduced from 512 for faster generation
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Build full prompt with theme
      final fullPrompt =
          '$prompt, $theme style, soothing bedtime story illustration';

      // Use image model loader for actual inference
      // Note: Image generation can run in parallel with audio generation
      if (_imageModelLoader != null) {
        return await _imageModelLoader!.generate(
          prompt: fullPrompt,
          numImages: numImages,
          width: width,
          height: height,
          numInferenceSteps: 10, // Reduced for faster CPU inference
          guidanceScale: 7.5,
        );
      }

      // Fallback if model loader not initialized
      debugPrint('Image model loader not initialized, using placeholder');
      return [];
    } catch (e) {
      debugPrint('Error generating images with model: $e');
      // Return empty list on error
      return [];
    }
  }

  /// Generate audio using on-device TTS
  /// Voice is automatically selected based on story characteristics if not provided
  Future<Uint8List> generateAudio({
    required String text,
    String language = 'en-US',
    String? voice,
    String? theme,
    String? mood,
    Map<String, dynamic>? profile,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Auto-select voice based on story characteristics if not provided
      String? selectedVoice = voice;
      if (selectedVoice == null && (theme != null || mood != null)) {
        final voiceService = VoiceSelectionService.instance;
        selectedVoice = voiceService.selectVoice(
          theme: theme ?? 'Aurora Dreams',
          mood: mood,
          profile: profile,
        );
        debugPrint(
            'Auto-selected voice: $selectedVoice (theme: $theme, mood: $mood)');
      }

      // Use TTS service for audio generation
      if (_ttsService != null) {
        return await _ttsService!.synthesizeToFile(
          text: text,
          language: language,
          voice: selectedVoice,
          speechRate: 0.5, // Slower for bedtime stories
          volume: 1.0,
          pitch: 1.0,
        );
      }

      // Fallback if TTS service not initialized
      debugPrint('TTS service not initialized, returning empty audio');
      return Uint8List(0);
    } catch (e) {
      debugPrint('Error generating audio with TTS: $e');
      // Return empty audio on error
      return Uint8List(0);
    }
  }

  /// Check if a generated story is a placeholder
  bool _isPlaceholderStory(String story) {
    // Check for common placeholder indicators
    return story.contains('[BACKEND REQUIRED]') ||
           story.contains('placeholder') ||
           story.contains('Once upon a time, there was a wonderful story') ||
           story.isEmpty ||
           story.length < 50; // Too short to be a real story
  }

  /// Check if on-device ML is available
  bool get isAvailable => Platform.isIOS || Platform.isAndroid;

  /// Get the platform name
  String get platform {
    if (Platform.isIOS) return 'iOS (Core ML)';
    if (Platform.isAndroid) return 'Android (TensorFlow Lite)';
    return 'Unsupported';
  }
}
