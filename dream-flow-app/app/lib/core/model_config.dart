import 'dart:io';

/// Configuration for ML models used in the app
/// Defines model metadata, download URLs, and platform-specific paths
class ModelConfig {
  ModelConfig._();

  /// Story generation model configuration
  static const StoryModel storyModel = StoryModel();

  /// Image generation model configuration
  static const ImageModel imageModel = ImageModel();

  /// Text-to-Speech model configuration (uses native APIs, no download needed)
  static const TTSModel ttsModel = TTSModel();

  /// Base URL for model downloads (CDN or Hugging Face)
  static const String baseDownloadUrl = 'https://huggingface.co';

  /// Model version for cache invalidation
  static const String modelVersion = 'v1.0.0';

  /// Get platform-specific model directory (use ModelManager instead)
  /// This method is deprecated - use ModelManager.instance._getModelDirectory()
}

/// Story generation model configuration
/// Optimized for <10 second inference on CPU-only devices
class StoryModel {
  const StoryModel();

  /// Model name - using smaller GPT-2 variants or MobileBERT for speed
  String get name => 'gpt2-tiny'; // Alternative: 'mobilebert' for even faster

  /// Model description
  String get description =>
      'GPT-2 Tiny or MobileBERT (fast CPU inference, <10s generation)';

  /// Model size in bytes (approximate)
  /// Using smaller models to ensure fast inference on CPU
  int get sizeBytes => 50 * 1024 * 1024; // ~50MB (smaller for faster loading)

  /// Android: TensorFlow Lite model filename
  String get androidFilename => 'gpt2_tiny.tflite'; // Or mobilebert.tflite

  /// iOS: TensorFlow Lite model filename (we use the same TFLite model on iOS)
  /// Note: We previously supported Core ML via platform channels; the current
  /// on-device pipeline uses `tflite_flutter` on both Android and iOS.
  String get iosFilename => 'gpt2_tiny.tflite';

  /// Android: Model download URL (TensorFlow Lite format)
  /// Note: Use GPT-2 Tiny or MobileBERT for faster inference
  String get androidDownloadUrl => '$modelBaseUrl/gpt2_tiny.tflite';

  /// iOS: Model download URL (TensorFlow Lite format - same as Android)
  String get iosDownloadUrl => '$modelBaseUrl/gpt2_tiny.tflite';

  /// Base URL for model files
  String get modelBaseUrl => '${ModelConfig.baseDownloadUrl}/models/gpt2-tiny';

  /// Get platform-specific filename
  String getFilename() {
    if (Platform.isAndroid) {
      return androidFilename;
    } else if (Platform.isIOS) {
      return iosFilename;
    }
    // Unit tests and desktop builds run on non-mobile platforms. Return the
    // default (Android) filename so callers can still function in test mode.
    return androidFilename;
  }

  /// Get platform-specific download URL
  String getDownloadUrl() {
    if (Platform.isAndroid) {
      return androidDownloadUrl;
    } else if (Platform.isIOS) {
      return iosDownloadUrl;
    }
    // Unit tests and desktop builds run on non-mobile platforms. Return the
    // default (Android) URL so callers can still function in test mode.
    return androidDownloadUrl;
  }
}

/// Image generation model configuration (Stable Diffusion)
class ImageModel {
  const ImageModel();

  /// Model name
  String get name => 'stable-diffusion-turbo';

  /// Model description
  String get description =>
      'Stable Diffusion Turbo (lightweight variant for mobile)';

  /// Total model size in bytes (approximate)
  int get sizeBytes => (1.5 * 1024 * 1024 * 1024).toInt(); // ~1.5GB

  /// Android: Text encoder model filename
  String get androidTextEncoderFilename => 'sd_text_encoder.tflite';

  /// Android: UNet model filename
  String get androidUNetFilename => 'sd_unet.tflite';

  /// Android: VAE decoder model filename
  String get androidVAEFilename => 'sd_vae.tflite';

  /// iOS: Core ML model package filename
  String get iosFilename => 'stable_diffusion.mlpackage';

  /// Android: Text encoder download URL
  String get androidTextEncoderUrl => '$modelBaseUrl/sd_text_encoder.tflite';

  /// Android: UNet download URL
  String get androidUNetUrl => '$modelBaseUrl/sd_unet.tflite';

  /// Android: VAE decoder download URL
  String get androidVAEUrl => '$modelBaseUrl/sd_vae.tflite';

  /// iOS: Model package download URL
  String get iosDownloadUrl => '$modelBaseUrl/stable_diffusion.mlpackage';

  /// Base URL for model files
  String get modelBaseUrl =>
      '${ModelConfig.baseDownloadUrl}/models/stable-diffusion-turbo';

  /// Get Android model filenames
  List<String> getAndroidFilenames() {
    return [
      androidTextEncoderFilename,
      androidUNetFilename,
      androidVAEFilename,
    ];
  }

  /// Get iOS model filenames (same as Android for TFLite)
  List<String> getIOSFilenames() {
    return [
      androidTextEncoderFilename,
      androidUNetFilename,
      androidVAEFilename,
    ];
  }

  /// Get Android download URLs
  List<String> getAndroidDownloadUrls() {
    return [
      androidTextEncoderUrl,
      androidUNetUrl,
      androidVAEUrl,
    ];
  }

  /// Get iOS download URLs (same as Android for TFLite)
  List<String> getIOSDownloadUrls() {
    return [
      androidTextEncoderUrl,
      androidUNetUrl,
      androidVAEUrl,
    ];
  }

  /// Get iOS filename (deprecated, use getIOSFilenames)
  String getIOSFilename() => iosFilename;

  /// Get iOS download URL (deprecated, use getIOSDownloadUrls)
  String getIOSDownloadUrl() => iosDownloadUrl;
}

/// Text-to-Speech model configuration
class TTSModel {
  const TTSModel();

  /// Model name
  String get name => 'native-tts';

  /// Model description
  String get description => 'Native TTS APIs (no model download required)';

  /// Model size (0 for native APIs)
  int get sizeBytes => 0;

  /// iOS: Use AVSpeechSynthesizer
  bool get useIOSNative => true;

  /// Android: Use Android TTS API
  bool get useAndroidNative => true;

  /// Default voice for iOS
  String get iosDefaultVoice => 'en-US';

  /// Default voice for Android
  String get androidDefaultVoice => 'en_US';
}
