/// Performance constraints for on-device ML models
///
/// Requirements:
/// - Total runtime: ≤30 seconds per story (with parallel execution)
/// - Must fit on phone storage
/// - Optimized for CPU-only inference (no Tensor/Neural Engine)
library;

class ModelPerformanceConstraints {
  ModelPerformanceConstraints._();

  /// Maximum total time for complete story generation pipeline (seconds)
  static const int maxTotalTimeSeconds = 30;

  /// Story generation target time (should be fastest, runs first)
  static const int storyGenerationTargetSeconds = 8;

  /// Image generation target time (can run in parallel, 4 images)
  static const int imageGenerationTargetSeconds = 20; // ~5s per image

  /// Audio generation target time (can run in parallel with images)
  static const int audioGenerationTargetSeconds = 5;

  /// Maximum model size for story model (bytes)
  static const int maxStoryModelSizeBytes = 100 * 1024 * 1024; // 100MB

  /// Maximum total model size for image models (bytes)
  static const int maxImageModelSizeBytes = 1000 * 1024 * 1024; // 1GB

  /// Maximum total storage used by all models (bytes)
  static const int maxTotalStorageBytes = 1200 * 1024 * 1024; // 1.2GB

  /// Recommended models that meet constraints

  /// Story generation model recommendations (in order of preference)
  static const List<String> recommendedStoryModels = [
    'GPT-2 Tiny (28M params, ~30MB quantized)', // Fastest option
    'MobileBERT (25M params, ~25MB quantized)', // Alternative
    'DistilGPT-2 (82M params, ~50MB quantized)', // If faster models unavailable
  ];

  /// Image generation model recommendations
  static const List<String> recommendedImageModels = [
    'Stable Diffusion Turbo Lite (smallest variant)',
    'Stable Diffusion 1.4 quantized',
    'Lightweight diffusion model alternatives',
  ];

  /// Check if model size is acceptable
  static bool isModelSizeAcceptable(int sizeBytes, ModelType type) {
    switch (type) {
      case ModelType.story:
        return sizeBytes <= maxStoryModelSizeBytes;
      case ModelType.image:
        return sizeBytes <= maxImageModelSizeBytes;
      default:
        return true;
    }
  }

  /// Check if total storage usage is acceptable
  static bool isTotalStorageAcceptable(int storySize, int imageSize) {
    return (storySize + imageSize) <= maxTotalStorageBytes;
  }

  /// Get performance target for model type
  static int getPerformanceTarget(ModelType type) {
    switch (type) {
      case ModelType.story:
        return storyGenerationTargetSeconds;
      case ModelType.image:
        return imageGenerationTargetSeconds;
      case ModelType.tts:
        return audioGenerationTargetSeconds;
    }
  }
}

enum ModelType {
  story,
  image,
  tts,
}
