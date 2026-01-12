#!/usr/bin/env dart
/// Script to download ML models for on-device inference
/// 
/// Usage:
///   dart scripts/download_models.dart [android|ios]
/// 
/// Downloads models optimized for CPU-only inference (non-Tensor/Neural Engine devices)

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Model download configurations
class ModelDownloadConfig {
  final String name;
  final String platform; // 'android' or 'ios'
  final String filename;
  final String downloadUrl;
  final int expectedSizeBytes;

  ModelDownloadConfig({
    required this.name,
    required this.platform,
    required this.filename,
    required this.downloadUrl,
    required this.expectedSizeBytes,
  });
}

/// Model download URLs
/// 
/// Note: These are placeholder URLs. You'll need to:
/// 1. Convert models to TFLite (Android) or Core ML (iOS) format
/// 2. Host them on a CDN or use Hugging Face model files
/// 3. Update these URLs with actual model file locations
class ModelUrls {
  // Story Generation Model: DistilGPT-2
  static const androidStoryModelUrl = 'https://huggingface.co/distilgpt2/resolve/main/pytorch_model.bin';
  // TODO: Replace with actual TFLite model URL when converted
  static const iosStoryModelUrl = 'https://huggingface.co/distilgpt2/resolve/main/pytorch_model.bin';
  // TODO: Replace with actual Core ML model URL when converted
  
  // Image Generation: Stable Diffusion Turbo
  // These need to be converted and hosted separately
  static const androidImageTextEncoderUrl = ''; // TODO: Add actual URL
  static const androidImageUNetUrl = ''; // TODO: Add actual URL
  static const androidImageVAEUrl = ''; // TODO: Add actual URL
  static const iosImageModelUrl = ''; // TODO: Add actual Core ML package URL
}

Future<void> main(List<String> args) async {
  final platform = args.isNotEmpty ? args[0] : 'android';
  
  if (platform != 'android' && platform != 'ios') {
    print('Usage: dart scripts/download_models.dart [android|ios]');
    exit(1);
  }

  print('Downloading models for $platform platform...\n');

  // Get models directory
  final scriptDir = Directory.current;
  final modelsDir = Directory(path.join(scriptDir.path, 'models'));
  if (!await modelsDir.exists()) {
    await modelsDir.create(recursive: true);
  }

  try {
    if (platform == 'android') {
      await downloadAndroidModels(modelsDir);
    } else {
      await downloadIOSModels(modelsDir);
    }
    
    print('\n✅ All models downloaded successfully!');
    print('Models saved to: ${modelsDir.path}');
  } catch (e) {
    print('\n❌ Error downloading models: $e');
    exit(1);
  }
}

Future<void> downloadAndroidModels(Directory modelsDir) async {
  print('Android Models:');
  print('===============\n');

  // Story Generation Model (DistilGPT-2 TFLite)
  print('1. Story Generation Model (DistilGPT-2 TFLite)...');
  print('   ⚠️  Note: You need to convert DistilGPT-2 to TFLite format first.');
  print('   📝 See: https://www.tensorflow.org/lite/models/convert/convert_models');
  print('   💡 For testing, you can use a smaller quantized model from Hugging Face\n');

  // Image Generation Models (Stable Diffusion TFLite)
  print('2. Image Generation Models (Stable Diffusion TFLite)...');
  print('   📦 Text Encoder: sd_text_encoder.tflite');
  print('   📦 UNet: sd_unet.tflite');
  print('   📦 VAE Decoder: sd_vae.tflite');
  print('   ⚠️  Note: These need to be converted from Stable Diffusion models.');
  print('   📝 See: https://huggingface.co/models?search=stable-diffusion\n');

  print('📋 Download Steps:');
  print('   1. Convert models to TFLite format using TensorFlow Lite Converter');
  print('   2. Quantize models for smaller size (INT8 quantization recommended)');
  print('   3. Upload models to a CDN or hosting service');
  print('   4. Update URLs in lib/core/model_config.dart');
  print('   5. Run this script again to download from the updated URLs\n');
}

Future<void> downloadIOSModels(Directory modelsDir) async {
  print('iOS Models:');
  print('===========\n');

  // Story Generation Model (DistilGPT-2 Core ML)
  print('1. Story Generation Model (DistilGPT-2 Core ML)...');
  print('   ⚠️  Note: You need to convert DistilGPT-2 to Core ML format first.');
  print('   📝 See: https://coremltools.readme.io/docs');
  print('   💡 Use coremltools to convert PyTorch/TensorFlow models\n');

  // Image Generation Model (Stable Diffusion Core ML)
  print('2. Image Generation Model (Stable Diffusion Core ML)...');
  print('   📦 Model Package: stable_diffusion.mlpackage');
  print('   ⚠️  Note: This needs to be converted to Core ML format.');
  print('   📝 See: https://github.com/apple/ml-stable-diffusion\n');

  print('📋 Download Steps:');
  print('   1. Convert models to Core ML format using coremltools');
  print('   2. Optimize models for Neural Engine (automatic in Core ML)');
  print('   3. Upload models to a CDN or hosting service');
  print('   4. Update URLs in lib/core/model_config.dart');
  print('   5. Run this script again to download from the updated URLs\n');
}

/// Download a single model file
Future<void> downloadModel({
  required String url,
  required String filename,
  required Directory outputDir,
  int? expectedSizeBytes,
}) async {
  if (url.isEmpty) {
    print('   ⚠️  URL not configured, skipping...');
    return;
  }

  final outputFile = File(path.join(outputDir.path, filename));
  
  if (await outputFile.exists()) {
    final stat = await outputFile.stat();
    print('   ✓ Already exists (${_formatBytes(stat.size)})');
    return;
  }

  print('   📥 Downloading from $url...');
  
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final contentLength = response.contentLength ?? 0;
    int bytesDownloaded = 0;

    final sink = outputFile.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      bytesDownloaded += chunk.length;
      
      if (contentLength > 0) {
        final percentage = (bytesDownloaded / contentLength * 100).toStringAsFixed(1);
        stdout.write('\r   Progress: $percentage% (${_formatBytes(bytesDownloaded)}/${_formatBytes(contentLength)})');
      }
    }
    await sink.close();
    print(''); // New line after progress

    final finalSize = await outputFile.stat();
    print('   ✅ Downloaded: ${_formatBytes(finalSize.size)}');

    if (expectedSizeBytes != null) {
      final diff = (finalSize.size - expectedSizeBytes).abs();
      if (diff > expectedSizeBytes * 0.1) {
        print('   ⚠️  Warning: Size differs from expected (expected: ${_formatBytes(expectedSizeBytes)})');
      }
    }
  } catch (e) {
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    rethrow;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

