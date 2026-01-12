import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../model_manager.dart';
import '../model_config.dart';
import '../tflite_acceleration.dart';
import '../tokenizers/tokenizer_manager.dart';
import '../tokenizers/gpt2_tokenizer.dart';
import 'story_model_coreml.dart';

/// Story generation model loader for on-device inference
/// Supports:
/// - Android: TFLite with NNAPI/GPU/XNNPACK delegates
/// - iOS: Core ML with Neural Engine via platform channels
class StoryModelLoader {
  StoryModelLoader._();
  static StoryModelLoader? _instance;
  static StoryModelLoader get instance => _instance ??= StoryModelLoader._();

  bool _loaded = false;
  Interpreter? _model; // TFLite Interpreter for Android
  GPT2Tokenizer? _tokenizer; // Tokenizer instance (cached)
  TfliteAccelerationBundle? _accelBundle;
  
  // iOS Core ML loader
  CoreMLStoryLoader? _coreMLLoader;

  /// Load the story generation model
  Future<void> load() async {
    if (_loaded) {
      debugPrint('Story model already loaded');
      return;
    }

    try {
      if (Platform.isIOS) {
        // Use Core ML on iOS for Neural Engine acceleration
        await _loadCoreMLModel();
      } else if (Platform.isAndroid) {
        // Use TFLite on Android for Tensor/GPU acceleration
        final storyModel = ModelConfig.storyModel;
        final modelManager = ModelManager.instance;

        // Check if model exists, download if needed
        if (!await modelManager.hasStoryModel()) {
          debugPrint('Story model not found, downloading...');
          await modelManager.downloadStoryModel();
        }

        final filename = storyModel.getFilename();
        final modelFile = await modelManager.getModelFile(filename);
        await _loadTfliteModel(modelFile);
      } else {
        throw UnsupportedError('Platform not supported');
      }

      _loaded = true;
      debugPrint('Story model loaded successfully');
    } catch (e) {
      debugPrint('Failed to load story model: $e');
      rethrow;
    }
  }
  
  /// Load Core ML model on iOS
  Future<void> _loadCoreMLModel() async {
    try {
      _coreMLLoader = CoreMLStoryLoader();
      await _coreMLLoader!.load();
      debugPrint('✓ Story model loaded via Core ML (Neural Engine)');
    } catch (e) {
      debugPrint('Failed to load CoreML story model: $e');
      rethrow;
    }
  }

  /// Load TFLite model with hardware acceleration
  Future<void> _loadTfliteModel(File modelFile) async {
    try {
      // Check if model file exists
      if (!await modelFile.exists()) {
        // Try loading from assets
        debugPrint(
            'Model file not found at ${modelFile.path}, trying assets...');
        await _loadAndroidModelFromAssets(); // Re-use asset loading for both
        return;
      }

      _accelBundle?.dispose();
      _accelBundle = TfliteAcceleration.createOptions();
      debugPrint(
        '⚡ Story TFLite acceleration: ${_accelBundle!.info.accelerator} '
        '(hw=${_accelBundle!.info.isHardwareAccelerated}, threads=${_accelBundle!.info.threads})',
      );

      _model = Interpreter.fromFile(
        modelFile,
        options: _accelBundle!.options,
      );

      // Verify model is loaded correctly
      if (_model == null) {
        throw Exception('Failed to create TFLite interpreter');
      }

      debugPrint(
          'TFLite story model loaded successfully from ${modelFile.path}');

      // Load tokenizer
      _tokenizer = await TokenizerManager.instance.loadGPT2Tokenizer();
    } catch (e) {
      debugPrint('Failed to load TFLite story model from file: $e');
      // Try loading from assets as fallback
      try {
        await _loadAndroidModelFromAssets();
      } catch (assetsError) {
        debugPrint('Failed to load from assets: $assetsError');
        throw Exception('Failed to load TFLite story model: $e');
      }
    }
  }

  /// Load Android TFLite model from assets
  Future<void> _loadAndroidModelFromAssets() async {
    try {
      final storyModel = ModelConfig.storyModel;
      final filename = storyModel.androidFilename;
      final assetPath = 'assets/models/$filename';

      debugPrint('Loading TFLite model from assets: $assetPath');

      // Load model bytes from assets
      final ByteData data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      // Write to temporary file (TFLite needs a file path)
      final tempDir = await Directory.systemTemp.createTemp('tflite_models');
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes);

      _accelBundle?.dispose();
      _accelBundle = TfliteAcceleration.createOptions();
      debugPrint(
        '⚡ Story TFLite acceleration (assets): ${_accelBundle!.info.accelerator} '
        '(hw=${_accelBundle!.info.isHardwareAccelerated}, threads=${_accelBundle!.info.threads})',
      );

      _model = Interpreter.fromFile(
        tempFile,
        options: _accelBundle!.options,
      );

      if (_model == null) {
        throw Exception('Failed to create TFLite interpreter from assets');
      }

      debugPrint('TFLite story model loaded successfully from assets');

      // Load tokenizer
      _tokenizer = await TokenizerManager.instance.loadGPT2Tokenizer();
    } catch (e) {
      throw Exception('Failed to load TFLite story model from assets: $e');
    }
  }

  /// Check if model is ready for inference
  bool _isModelReady() {
    if (!_loaded) {
      return false;
    }
    if (_model == null) {
      return false;
    }
    if (_tokenizer == null) {
      return false;
    }
    return true;
  }

  /// Generate story text from prompt
  Future<String> generate({
    required String prompt,
    int maxTokens = 200,
    double temperature = 0.8,
  }) async {
    // Try to load model if not loaded
    if (!_loaded) {
      try {
        await load();
      } catch (e) {
        debugPrint('❌ Model loading failed: $e');
        return _generatePlaceholderStory(prompt);
      }
    }

    try {
      if (Platform.isIOS && _coreMLLoader != null) {
        // Use Core ML on iOS
        return await _coreMLLoader!.generate(
          prompt: prompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      } else if (Platform.isAndroid) {
        // Use TFLite on Android
        // Verify model is ready before attempting inference
        if (!_isModelReady()) {
          debugPrint('⚠️ Model not ready for inference');
          return _generatePlaceholderStory(prompt);
        }
        return await _generateWithTflite(prompt, maxTokens, temperature);
      } else {
        return _generatePlaceholderStory(prompt);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Story generation inference failed: $e');
      debugPrint('   Stack trace: $stackTrace');
      return _generatePlaceholderStory(prompt);
    }
  }

  /// Generate story using TFLite
  Future<String> _generateWithTflite(
      String prompt, int maxTokens, double temperature) async {
    try {
      final interpreter = _model;
      if (interpreter == null) {
        debugPrint('❌ TFLite model not loaded');
        return _generatePlaceholderStory(prompt);
      }

      // Ensure tokenizer is loaded
      try {
        _tokenizer ??= await TokenizerManager.instance.loadGPT2Tokenizer();
      } catch (e) {
        debugPrint('❌ Failed to load tokenizer: $e');
        return _generatePlaceholderStory(prompt);
      }

      // 1. Tokenize prompt
      List<int> inputIds;
      try {
        inputIds = _tokenizer!.encode(prompt);
        if (inputIds.isEmpty) {
          return _generatePlaceholderStory(prompt);
        }
      } catch (e) {
        return _generatePlaceholderStory(prompt);
      }

      // 2. Prepare input tensor
      const maxSequenceLength = 128; // Match model's expected input size
      final paddedInput = List<int>.filled(maxSequenceLength, 0);
      final inputLength = inputIds.length > maxSequenceLength
          ? maxSequenceLength
          : inputIds.length;

      for (int i = 0; i < inputLength; i++) {
        paddedInput[i] = inputIds[i];
      }

      // 3. Get model input/output shapes
      dynamic outputTensorInfo;
      try {
        outputTensorInfo = interpreter.getOutputTensor(0);
      } catch (e) {
        return _generatePlaceholderStory(prompt);
      }

      // 4. Prepare output tensor
      final outputShape = outputTensorInfo.shape;
      if (outputShape.isEmpty) {
        return _generatePlaceholderStory(prompt);
      }

      final vocabSizeInt = outputShape[outputShape.length - 1] as int;
      final outputSize =
          outputShape.reduce((a, b) => (a as int) * (b as int)) as int;
      final output = List<double>.filled(outputSize, 0.0);

      // 5. Run inference iteratively to generate tokens
      final generatedTokens = <int>[];
      var currentInput = List<int>.from(paddedInput);
      var currentSequence = List<int>.from(inputIds);

      for (int step = 0; step < maxTokens; step++) {
        final inputBuffer = currentInput;
        try {
          interpreter.run(inputBuffer, output);
        } catch (e) {
          break;
        }

        final lastTokenIndex = currentSequence.length - 1;
        if (lastTokenIndex < 0 || lastTokenIndex >= maxSequenceLength) {
          break;
        }

        final logitsStart = lastTokenIndex * vocabSizeInt;
        if (logitsStart + vocabSizeInt > output.length) {
          break;
        }

        final logits = output.sublist(logitsStart, logitsStart + vocabSizeInt);
        final nextTokenId = _sampleToken(logits, temperature);
        if (nextTokenId == null) {
          break;
        }

        if (_tokenizer!.vocab != null &&
            _tokenizer!.eosToken != null &&
            _tokenizer!.vocab!.containsKey(_tokenizer!.eosToken) &&
            nextTokenId == _tokenizer!.vocab![_tokenizer!.eosToken]) {
          break;
        }

        generatedTokens.add(nextTokenId);
        currentSequence.add(nextTokenId);

        if (currentSequence.length >= maxSequenceLength) {
          currentSequence =
              currentSequence.sublist(currentSequence.length - maxSequenceLength + 1);
        }
        currentInput = List<int>.filled(maxSequenceLength, 0);
        final seqLength = currentSequence.length < maxSequenceLength
            ? currentSequence.length
            : maxSequenceLength;
        for (int i = 0; i < seqLength; i++) {
          currentInput[i] = currentSequence[i];
        }
      }

      // 6. Decode generated tokens
      if (generatedTokens.isEmpty) {
        return _generatePlaceholderStory(prompt);
      }

      String generatedText;
      try {
        generatedText = _tokenizer!.decode(generatedTokens);
        if (generatedText.isEmpty) {
          return _generatePlaceholderStory(prompt);
        }
        return generatedText;
      } catch (e) {
        return _generatePlaceholderStory(prompt);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in TFLite inference: $e');
      debugPrint('Stack trace: $stackTrace');
      return _generatePlaceholderStory(prompt);
    }
  }

  /// Sample next token from logits using temperature
  int? _sampleToken(List<double> logits, double temperature) {
    if (logits.isEmpty) return null;

    try {
      // Apply temperature
      final scaledLogits = logits.map((l) => l / temperature).toList();

      // Softmax (simplified)
      final maxLogit = scaledLogits.reduce((a, b) => a > b ? a : b);
      final expLogits = scaledLogits
          .map((l) => (l - maxLogit).clamp(-50.0, 50.0))
          .toList();
      final sumExp = expLogits.fold(0.0, (a, b) => a + b);
      if (sumExp == 0.0) {
        final maxIndex = scaledLogits.indexWhere((l) => l == maxLogit);
        return maxIndex >= 0 ? maxIndex : null;
      }

      final probs = expLogits.map((l) => l / sumExp).toList();

      final random = (DateTime.now().millisecondsSinceEpoch % 10000) / 10000.0;
      double cumulative = 0.0;
      for (int i = 0; i < probs.length; i++) {
        cumulative += probs[i];
        if (random <= cumulative) {
          return i;
        }
      }

      final maxIndex = scaledLogits.indexWhere(
          (l) => l == scaledLogits.reduce((a, b) => a > b ? a : b));
      return maxIndex >= 0 ? maxIndex : null;
    } catch (e) {
      debugPrint('Error sampling token: $e');
      final maxIndex =
          logits.indexWhere((l) => l == logits.reduce((a, b) => a > b ? a : b));
      return maxIndex >= 0 ? maxIndex : null;
    }
  }

  /// Placeholder story generation (for testing)
  String _generatePlaceholderStory(String prompt) {
    return '''
Once upon a time, there was a wonderful story about $prompt.

The tale unfolds gently, carrying the listener on a peaceful journey through imagination.
'''
        .trim();
  }

  /// Check if model is loaded
  bool get isLoaded => _loaded;

  /// Unload the model and free resources
  Future<void> unload() async {
    if (!_loaded) return;

    try {
      if (Platform.isIOS && _coreMLLoader != null) {
        await _coreMLLoader!.unload();
        _coreMLLoader = null;
      } else if (Platform.isAndroid) {
        _model?.close();
        _model = null;
        _accelBundle?.dispose();
        _accelBundle = null;
        _tokenizer = null;
      }
      _loaded = false;
      debugPrint('Story model unloaded');
    } catch (e) {
      debugPrint('Error unloading story model: $e');
    }
  }
}

