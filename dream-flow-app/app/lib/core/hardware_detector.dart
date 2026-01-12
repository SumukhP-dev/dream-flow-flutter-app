import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'tflite_acceleration.dart';

/// Hardware detection service for detecting mobile accelerators and model availability
/// 
/// Detects:
/// - Android: Tensor chip (Pixel 6+) or NPU
/// - iOS: Neural Engine (A12 Bionic+)
/// - Model availability: TFLite (Android) or Core ML (iOS)
class HardwareDetector {
  static HardwareDetector? _instance;
  static HardwareDetector get instance => _instance ??= HardwareDetector._();

  HardwareDetector._();

  bool? _hasTensorChip;
  bool? _hasNeuralEngine;
  bool? _hasTfliteModels;
  bool? _hasCoreMLModels;
  String? _tfliteAccelerator;
  bool? _hasAiAccelerator;
  String? _platform;

  /// Detect hardware capabilities and model availability
  /// Returns a map of environment variables to set
  Future<Map<String, String>> detectHardware() async {
    final envVars = <String, String>{};

    if (Platform.isAndroid) {
      _platform = 'android';
      envVars['MOBILE_PLATFORM'] = 'android';
      
      // Try to detect Tensor chip via device model/properties
      // For now, assume Pixel 6+ devices have Tensor chips
      _hasTensorChip = await _detectTensorChip();
      envVars['HAS_TENSOR_CHIP'] = _hasTensorChip! ? 'true' : 'false';
      
      // Check for TFLite models
      _hasTfliteModels = await _checkTfliteModels();
      envVars['HAS_TFLITE_MODELS'] = _hasTfliteModels! ? 'true' : 'false';

      // Detect whether we can enable a hardware delegate (GPU) or fall back (XNNPACK/CPU)
      final accel = TfliteAcceleration.detectBestAccelerator();
      _tfliteAccelerator = accel;
      _hasAiAccelerator = (accel == 'nnapi' || accel == 'gpu');
      envVars['TFLITE_ACCELERATOR'] = accel;
      envVars['HAS_AI_ACCELERATOR'] = _hasAiAccelerator! ? 'true' : 'false';
      
      debugPrint('Hardware Detection (Android):');
      debugPrint('  Tensor Chip: $_hasTensorChip');
      debugPrint('  TFLite Models: $_hasTfliteModels');
      debugPrint('  TFLite Accelerator: $_tfliteAccelerator');
      
    } else if (Platform.isIOS) {
      _platform = 'ios';
      envVars['MOBILE_PLATFORM'] = 'ios';
      
      // Check for Neural Engine availability via TFLite Core ML delegate
      _hasNeuralEngine = await _detectNeuralEngine();
      envVars['HAS_NEURAL_ENGINE'] = _hasNeuralEngine! ? 'true' : 'false';
      
      // Core ML model checks are no longer used by the current pipeline.
      _hasCoreMLModels = false;
      envVars['HAS_COREML_MODELS'] = 'false';

      final accel = TfliteAcceleration.detectBestAccelerator();
      _tfliteAccelerator = accel;
      _hasAiAccelerator = (accel == 'coreml' || accel == 'metal');
      envVars['TFLITE_ACCELERATOR'] = accel;
      envVars['HAS_AI_ACCELERATOR'] = _hasAiAccelerator! ? 'true' : 'false';
      
      debugPrint('Hardware Detection (iOS):');
      debugPrint('  Neural Engine: $_hasNeuralEngine');
      debugPrint('  Core ML Models: $_hasCoreMLModels');
      debugPrint('  TFLite Accelerator: $_tfliteAccelerator');
      
    } else {
      // Not mobile platform
      _platform = 'other';
      envVars['MOBILE_PLATFORM'] = 'other';
      envVars['HAS_TENSOR_CHIP'] = 'false';
      envVars['HAS_NEURAL_ENGINE'] = 'false';
      envVars['HAS_TFLITE_MODELS'] = 'false';
      envVars['HAS_COREML_MODELS'] = 'false';
      envVars['TFLITE_ACCELERATOR'] = 'none';
      envVars['HAS_AI_ACCELERATOR'] = 'false';
    }

    return envVars;
  }


  /// Check if TFLite models are available
  Future<bool> _checkTfliteModels() async {
    try {
      // Check in assets directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(appDir.path, 'models'));
      
      if (await modelsDir.exists()) {
        // Check for .tflite files
        final files = await modelsDir.list().toList();
        final hasTflite = files.any((file) => 
          file.path.toLowerCase().endsWith('.tflite')
        );
        if (hasTflite) {
          return true;
        }
      }
      
      // Also check in app bundle assets (for bundled models)
      // This would require platform channel to check assets
      return false;
    } catch (e) {
      debugPrint('Error checking TFLite models: $e');
      return false;
    }
  }

  /// Detect if device has Google Tensor chip (Pixel 6+)
  Future<bool> _detectTensorChip() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // This would ideally use platform channels to check Android Build properties
      // For now, use environment variable that could be set by native Android code
      final deviceModel = Platform.environment['DEVICE_MODEL']?.toLowerCase() ?? '';
      
      // Check for known Tensor chip devices
      final tensorDevices = [
        'pixel 6', 'pixel 6 pro', 'pixel 6a',
        'pixel 7', 'pixel 7 pro', 'pixel 7a', 
        'pixel 8', 'pixel 8 pro', 'pixel 8a',
        'pixel 9', 'pixel 9 pro', 'pixel 9 xl'
      ];
      
      final hasTensorDevice = tensorDevices.any((device) => 
        deviceModel.contains(device.replaceAll(' ', '')) ||
        deviceModel.contains(device)
      );
      
      if (hasTensorDevice) {
        return true;
      }
      
      // Fallback: if we have NNAPI support, assume modern hardware
      // This is not as accurate but provides a reasonable heuristic
      return _tfliteAccelerator == 'nnapi';
      
    } catch (e) {
      debugPrint('Error detecting Tensor chip: $e');
      return false;
    }
  }

  /// Detect if device has Apple Neural Engine (A12 Bionic+)
  Future<bool> _detectNeuralEngine() async {
    if (!Platform.isIOS) return false;
    
    try {
      // Check if Core ML delegate is available (indicates Neural Engine support)
      final accel = TfliteAcceleration.detectBestAccelerator();
      if (accel == 'coreml') {
        return true;
      }
      
      // Fallback: check iOS version and assume modern devices have Neural Engine
      // This would ideally use platform channels to check device model
      // A12 Bionic+ devices (iPhone XS+, iPad Pro 2018+) have Neural Engine
      final iosVersion = Platform.environment['IOS_VERSION'] ?? '';
      if (iosVersion.isNotEmpty) {
        final version = double.tryParse(iosVersion.split('.').first) ?? 0;
        // iOS 12+ typically indicates A12+ which has Neural Engine
        return version >= 12.0;
      }
      
      // Conservative fallback: assume Neural Engine is available if we're on iOS
      // Most iOS devices running Flutter apps are likely modern enough
      return true;
      
    } catch (e) {
      debugPrint('Error detecting Neural Engine: $e');
      return false;
    }
  }

  /// Get detected hardware info (for debugging)
  Map<String, dynamic> getHardwareInfo() {
    return {
      'platform': _platform,
      'hasTensorChip': _hasTensorChip,
      'hasNeuralEngine': _hasNeuralEngine,
      'hasTfliteModels': _hasTfliteModels,
      'hasCoreMLModels': _hasCoreMLModels,
      'tfliteAccelerator': _tfliteAccelerator,
      'hasAiAccelerator': _hasAiAccelerator,
    };
  }
}

