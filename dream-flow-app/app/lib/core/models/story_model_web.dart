import 'package:flutter/foundation.dart';

/// Web-safe stub for StoryModelLoader.
///
/// On Flutter Web, `tflite_flutter` (FFI) cannot be used, so we provide a
/// placeholder implementation that keeps non-ML UI flows working.
class StoryModelLoader {
  StoryModelLoader._();
  static StoryModelLoader? _instance;
  static StoryModelLoader get instance => _instance ??= StoryModelLoader._();

  bool _loaded = false;

  Future<void> load() async {
    _loaded = true;
    debugPrint('Story model stub loaded (web)');
  }

  bool get isLoaded => _loaded;

  Future<String> generate({
    required String prompt,
    int maxTokens = 200,
    double temperature = 0.8,
  }) async {
    debugPrint(
      'Story generation not supported on web (prompt="$prompt", maxTokens=$maxTokens, temp=$temperature)',
    );
    return _generatePlaceholderStory(prompt);
  }

  Future<void> unload() async {
    _loaded = false;
  }

  String _generatePlaceholderStory(String prompt) {
    return '''
Once upon a time, there was a wonderful story about $prompt.

This is a web placeholder. On-device generation is available on Android/iOS builds.
'''
        .trim();
  }
}

