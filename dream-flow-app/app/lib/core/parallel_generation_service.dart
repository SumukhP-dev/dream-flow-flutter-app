import 'package:flutter/foundation.dart';
import 'on_device_ml_service.dart';

/// Service for parallel execution of story generation pipeline
///
/// Optimizes total runtime by running image and audio generation in parallel
/// Target: Total runtime ≤30 seconds on CPU-only devices
class ParallelGenerationService {
  ParallelGenerationService._();
  static ParallelGenerationService? _instance;
  static ParallelGenerationService get instance =>
      _instance ??= ParallelGenerationService._();

  final OnDeviceMLService _mlService = OnDeviceMLService.instance;

  /// Generate complete story experience with parallel execution
  ///
  /// Pipeline:
  /// 1. Generate story text (sequential, ~8s)
  /// 2. Generate images + audio in parallel (~20s + ~5s, overlaps)
  ///
  /// Total: ~25-30 seconds
  Future<StoryGenerationResult> generateStoryExperience({
    required String prompt,
    required String theme,
    Map<String, dynamic>? profile,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Step 1: Generate story text (sequential, must complete first)
      debugPrint('Starting story generation...');
      final storyText = await _mlService.generateStory(
        prompt: prompt,
        theme: theme,
        maxTokens: 200, // Optimized for speed
        profile: profile,
      );
      final storyTime = stopwatch.elapsedMilliseconds;
      debugPrint('Story generated in ${storyTime}ms');

      // Step 2: Generate images and audio in parallel (overlapped execution)
      debugPrint('Starting parallel image and audio generation...');
      final parallelStart = Stopwatch()..start();

      // Extract mood from profile for voice selection
      final mood = profile?['mood'] as String?;

      final results = await Future.wait([
        // Image generation (target: <20s)
        _mlService.generateImages(
          prompt: prompt,
          theme: theme,
          numImages: 4,
          width: 384, // Optimized size
          height: 384,
        ),
        // Audio generation (target: <5s, can overlap with images)
        // Voice automatically selected based on theme and mood
        _mlService.generateAudio(
          text: storyText,
          language: 'en-US',
          theme: theme,
          mood: mood,
          profile: profile,
        ),
      ]);

      final images = results[0] as List<Uint8List>;
      final audio = results[1] as Uint8List;
      final parallelTime = parallelStart.elapsedMilliseconds;
      debugPrint('Parallel generation completed in ${parallelTime}ms');

      stopwatch.stop();
      final totalTime = stopwatch.elapsedMilliseconds / 1000.0;
      debugPrint('Total generation time: ${totalTime.toStringAsFixed(2)}s');

      if (totalTime > 30) {
        debugPrint(
            '⚠️ Warning: Generation time (${totalTime}s) exceeds 30s target');
      }

      return StoryGenerationResult(
        storyText: storyText,
        images: images,
        audio: audio,
        generationTimeSeconds: totalTime,
        storyTimeSeconds: storyTime / 1000.0,
        parallelTimeSeconds: parallelTime / 1000.0,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error in parallel generation: $e');
      rethrow;
    }
  }

  /// Generate only story text (fastest path)
  /// Target: <10 seconds
  Future<String> generateStoryOnly({
    required String prompt,
    required String theme,
    Map<String, dynamic>? profile,
  }) async {
    final stopwatch = Stopwatch()..start();
    final story = await _mlService.generateStory(
      prompt: prompt,
      theme: theme,
      maxTokens: 200,
      profile: profile,
    );
    stopwatch.stop();

    final timeSeconds = stopwatch.elapsedMilliseconds / 1000.0;
    debugPrint('Story-only generation: ${timeSeconds.toStringAsFixed(2)}s');
    return story;
  }
}

/// Result of parallel story generation
class StoryGenerationResult {
  final String storyText;
  final List<Uint8List> images;
  final Uint8List audio;
  final double generationTimeSeconds;
  final double storyTimeSeconds;
  final double parallelTimeSeconds;

  StoryGenerationResult({
    required this.storyText,
    required this.images,
    required this.audio,
    required this.generationTimeSeconds,
    required this.storyTimeSeconds,
    required this.parallelTimeSeconds,
  });

  bool get meetsPerformanceTarget => generationTimeSeconds <= 30.0;
}
