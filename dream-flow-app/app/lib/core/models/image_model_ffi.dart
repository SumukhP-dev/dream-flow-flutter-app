import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../tflite_acceleration.dart';
import '../model_manager.dart';
import '../model_config.dart';
import '../tokenizers/tokenizer_manager.dart';
import '../tokenizers/gpt2_tokenizer.dart';
import 'image_model_coreml.dart';

/// Image generation model loader for on-device inference (Stable Diffusion)
/// Supports:
/// - Android: TFLite with NNAPI/GPU/XNNPACK delegates
/// - iOS: Core ML with Neural Engine via platform channels
class ImageModelLoader {
  ImageModelLoader._();
  static ImageModelLoader? _instance;
  static ImageModelLoader get instance => _instance ??= ImageModelLoader._();

  bool _loaded = false;
  Interpreter? _textEncoder;
  Interpreter? _unet;
  Interpreter? _vaeDecoder;
  GPT2Tokenizer? _tokenizer;

  TfliteAccelerationBundle? _textEncoderAccel;
  TfliteAccelerationBundle? _unetAccel;
  TfliteAccelerationBundle? _vaeAccel;
  
  // iOS Core ML loader
  CoreMLImageLoader? _coreMLLoader;

  Future<void> load() async {
    if (_loaded) {
      debugPrint('Image models already loaded');
      return;
    }

    try {
      if (Platform.isIOS) {
        // Use Core ML on iOS for Neural Engine acceleration
        await _loadCoreMLModels();
      } else if (Platform.isAndroid) {
        // Use TFLite on Android for Tensor/GPU acceleration
        final modelManager = ModelManager.instance;

        if (!await modelManager.hasImageModels()) {
          debugPrint('Image models not found, downloading...');
          await modelManager.downloadImageModels();
        }

        await _loadTfliteModels();
      } else {
        throw UnsupportedError('Platform not supported');
      }

      _loaded = true;
      debugPrint('Image generation models loaded successfully');
    } catch (e) {
      debugPrint('Failed to load image models: $e');
      rethrow;
    }
  }
  
  /// Load Core ML models on iOS
  Future<void> _loadCoreMLModels() async {
    try {
      _coreMLLoader = CoreMLImageLoader();
      await _coreMLLoader!.load();
      debugPrint('✓ Image models loaded via Core ML (Neural Engine)');
    } catch (e) {
      debugPrint('Failed to load CoreML image models: $e');
      rethrow;
    }
  }

  Future<void> _loadTfliteModels() async {
    try {
      final modelManager = ModelManager.instance;
      final filenames = ModelConfig.imageModel.getAndroidFilenames();

      final modelFiles = <File>[];
      for (final filename in filenames) {
        final file = await modelManager.getModelFile(filename);
        modelFiles.add(file);
      }

      _textEncoderAccel?.dispose();
      _unetAccel?.dispose();
      _vaeAccel?.dispose();

      _textEncoderAccel = TfliteAcceleration.createOptions();
      _unetAccel = TfliteAcceleration.createOptions();
      _vaeAccel = TfliteAcceleration.createOptions();

      debugPrint(
        '⚡ Image TFLite acceleration: '
        'text=${_textEncoderAccel!.info.accelerator}, '
        'unet=${_unetAccel!.info.accelerator}, '
        'vae=${_vaeAccel!.info.accelerator}',
      );

      _textEncoder =
          Interpreter.fromFile(modelFiles[0], options: _textEncoderAccel!.options);
      _unet = Interpreter.fromFile(modelFiles[1], options: _unetAccel!.options);
      _vaeDecoder =
          Interpreter.fromFile(modelFiles[2], options: _vaeAccel!.options);

      _tokenizer = await TokenizerManager.instance.loadGPT2Tokenizer();
      debugPrint('✓ TFLite image model loading completed');
    } catch (e) {
      throw Exception('Failed to load TFLite image models: $e');
    }
  }

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
      if (Platform.isIOS && _coreMLLoader != null) {
        // Use Core ML on iOS
        return await _coreMLLoader!.generate(
          prompt: prompt,
          numImages: numImages,
          width: width,
          height: height,
          numInferenceSteps: numInferenceSteps,
          guidanceScale: guidanceScale,
        );
      } else if (Platform.isAndroid) {
        // Use TFLite on Android
        return await _generateInDart(
            prompt, numImages, width, height, numInferenceSteps, guidanceScale);
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Image generation failed: $e');
      rethrow;
    }
  }

  Future<List<Uint8List>> _generateInDart(
    String prompt,
    int numImages,
    int width,
    int height,
    int numInferenceSteps,
    double guidanceScale,
  ) async {
    if (_textEncoder == null || _unet == null || _vaeDecoder == null) {
      debugPrint('⚠️ TFLite image models not loaded');
      return [];
    }

    if (_tokenizer == null) {
      debugPrint('⚠️ Tokenizer not loaded');
      return [];
    }

    debugPrint('🎨 Starting Stable Diffusion pipeline (Dart/TFLite)');
    debugPrint('   Prompt: $prompt');
    debugPrint(
        '   Images: $numImages, Size: ${width}x$height, Steps: $numInferenceSteps');

    try {
      final textEmbeddings = await _encodeText(prompt);
      if (textEmbeddings == null) {
        debugPrint('❌ Text encoding failed');
        return [];
      }

      final images = <Uint8List>[];
      for (int i = 0; i < numImages; i++) {
        final seed = DateTime.now().millisecondsSinceEpoch + i;

        final latents = await _denoiseLatents(
          textEmbeddings,
          seed,
          numInferenceSteps,
          guidanceScale,
          width,
          height,
        );
        if (latents == null) continue;

        final imageBytes = await _decodeLatents(latents, width, height);
        if (imageBytes == null) continue;
        images.add(imageBytes);
      }

      return images;
    } catch (e, stackTrace) {
      debugPrint('❌ Stable Diffusion pipeline error: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<double>?> _encodeText(String prompt) async {
    try {
      final tokenizer = _tokenizer!;
      final tokens = tokenizer.encode(prompt);
      final maxLength = 77;
      final paddedTokens = List<int>.filled(maxLength, 0);
      final length = math.min(tokens.length, maxLength);
      for (int i = 0; i < length; i++) {
        paddedTokens[i] = tokens[i];
      }

      final outputTensor = _textEncoder!.getOutputTensor(0);
      final input = [paddedTokens];
      final outputShape = outputTensor.shape;
      final outputSize = outputShape.fold<int>(1, (a, b) => a * b);
      final output = List<double>.filled(outputSize, 0.0);

      _textEncoder!.run(input, output);
      return output;
    } catch (e) {
      debugPrint('Text encoding error: $e');
      return null;
    }
  }

  Future<List<double>?> _denoiseLatents(
    List<double> textEmbeddings,
    int seed,
    int numInferenceSteps,
    double guidanceScale,
    int width,
    int height,
  ) async {
    try {
      final latentWidth = width ~/ 8;
      final latentHeight = height ~/ 8;
      final latentChannels = 4;
      final latentSize = latentWidth * latentHeight * latentChannels;

      final random = math.Random(seed);
      var latents = List<double>.generate(
        latentSize,
        (_) => (random.nextDouble() * 2.0 - 1.0) * 0.18215,
      );

      final unetOutputTensor = _unet!.getOutputTensor(0);
      final outputShape = unetOutputTensor.shape;
      final outputSize = outputShape.fold<int>(1, (a, b) => a * b);

      final timesteps = _createTimesteps(numInferenceSteps);

      for (int i = 0; i < numInferenceSteps; i++) {
        final t = timesteps[i];
        final inputData = _prepareUnetInput(
            latents, textEmbeddings, t, latentWidth, latentHeight);
        final noisePred = List<double>.filled(outputSize, 0.0);

        _unet!.run(inputData, noisePred);
        latents = _schedulerStep(
            latents, noisePred, t, i, numInferenceSteps, timesteps);
      }

      return latents;
    } catch (e) {
      debugPrint('Denoising error: $e');
      return null;
    }
  }

  dynamic _prepareUnetInput(
    List<double> latents,
    List<double> textEmbeddings,
    int timestep,
    int latentWidth,
    int latentHeight,
  ) {
    try {
      int numInputs = 1;
      try {
        _unet!.getInputTensor(1);
        numInputs = 2;
        try {
          _unet!.getInputTensor(2);
          numInputs = 3;
        } catch (_) {}
      } catch (_) {}

      if (numInputs == 3) {
        return [latents, [timestep.toDouble()], textEmbeddings];
      } else if (numInputs == 2) {
        final combined = <double>[];
        combined.add(timestep.toDouble());
        combined.addAll(textEmbeddings);
        return [latents, combined];
      } else {
        final combined = <double>[];
        combined.addAll(latents);
        combined.addAll(textEmbeddings);
        combined.add(timestep.toDouble());
        return [combined];
      }
    } catch (e) {
      debugPrint('⚠️ Error preparing UNet input: $e');
      return [latents];
    }
  }

  List<int> _createTimesteps(int numSteps) {
    final steps = <int>[];
    for (int i = 0; i < numSteps; i++) {
      final t = 1000 - (i * 1000 ~/ numSteps);
      steps.add(t);
    }
    return steps;
  }

  List<double> _schedulerStep(
    List<double> latents,
    List<double> noisePred,
    int timestep,
    int stepIndex,
    int numSteps,
    List<int> timesteps,
  ) {
    final alpha = 0.85;
    final nextLatents = List<double>.filled(latents.length, 0.0);
    for (int i = 0; i < latents.length; i++) {
      nextLatents[i] = latents[i] - noisePred[i] * alpha;
    }
    return nextLatents;
  }

  Future<Uint8List?> _decodeLatents(
    List<double> latents,
    int width,
    int height,
  ) async {
    try {
      final outputTensor = _vaeDecoder!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final outputSize = outputShape.fold<int>(1, (a, b) => a * b);

      final input = [latents];
      final output = List<double>.filled(outputSize, 0.0);

      _vaeDecoder!.run(input, output);
      return _postProcessImage(output, width, height);
    } catch (e) {
      debugPrint('VAE decoding error: $e');
      return null;
    }
  }

  Uint8List _postProcessImage(List<double> pixels, int width, int height) {
    final imageBytes = Uint8List(width * height * 3);
    final channels = 3;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        for (int c = 0; c < channels; c++) {
          final idx = c * (height * width) + y * width + x;
          if (idx < pixels.length) {
            var pixel = pixels[idx];
            pixel = (pixel + 1.0) / 2.0;
            pixel = pixel.clamp(0.0, 1.0);
            final byteValue = (pixel * 255.0).round().clamp(0, 255);
            final outputIdx = (y * width + x) * channels + c;
            imageBytes[outputIdx] = byteValue;
          }
        }
      }
    }

    return imageBytes;
  }

  bool get isLoaded => _loaded;

  Future<void> unload() async {
    if (!_loaded) return;

    try {
      if (Platform.isIOS && _coreMLLoader != null) {
        await _coreMLLoader!.unload();
        _coreMLLoader = null;
      } else if (Platform.isAndroid) {
        _textEncoder?.close();
        _unet?.close();
        _vaeDecoder?.close();
        _textEncoderAccel?.dispose();
        _unetAccel?.dispose();
        _vaeAccel?.dispose();

        _textEncoder = null;
        _unet = null;
        _vaeDecoder = null;
        _textEncoderAccel = null;
        _unetAccel = null;
        _vaeAccel = null;
        _tokenizer = null;
      }
      _loaded = false;
      debugPrint('Image models unloaded');
    } catch (e) {
      debugPrint('Error unloading image models: $e');
    }
  }
}

