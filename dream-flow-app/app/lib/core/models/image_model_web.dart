import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Web-safe stub for ImageModelLoader.
///
/// On Flutter Web, `tflite_flutter` (FFI) cannot be used, so we provide a
/// placeholder implementation that keeps non-ML UI flows working.
class ImageModelLoader {
  ImageModelLoader._();
  static ImageModelLoader? _instance;
  static ImageModelLoader get instance => _instance ??= ImageModelLoader._();

  bool _loaded = false;

  Future<void> load() async {
    _loaded = true;
    debugPrint('Image model stub loaded (web)');
  }

  bool get isLoaded => _loaded;

  Future<List<Uint8List>> generate({
    required String prompt,
    int numImages = 4,
    int width = 384,
    int height = 384,
    int numInferenceSteps = 10,
    double guidanceScale = 7.5,
  }) async {
    debugPrint(
      'Image generation not supported on web (prompt="$prompt", images=$numImages)',
    );
    return <Uint8List>[];
  }

  Future<void> unload() async {
    _loaded = false;
  }
}

