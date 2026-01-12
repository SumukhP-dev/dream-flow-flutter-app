import 'dart:io';
import 'package:flutter/foundation.dart';
import 'hardware_detector.dart';

/// Inference version types available for mobile devices
enum InferenceVersion {
  nativeMobile('native_mobile'),
  appleIntelligence('apple'),
  local('local');

  const InferenceVersion(this.value);
  final String value;

  @override
  String toString() => value;
}

/// Mobile-optimized version detection for on-device inference
/// 
/// This detector runs ON the mobile device and can access:
/// - Native hardware accelerators (Tensor chips, Neural Engine)  
/// - Apple Intelligence APIs (iOS devices)
/// - Local TFLite/Core ML models
/// 
/// Priority hierarchy:
/// 1. Native Mobile (Tensor/Neural Engine) - fastest, most efficient
/// 2. Apple Intelligence (iOS only) - high quality, Apple ecosystem
/// 3. Local models - fallback for all devices
class InferenceVersionDetector {
  static InferenceVersionDetector? _instance;
  static InferenceVersionDetector get instance => _instance ??= InferenceVersionDetector._();

  InferenceVersionDetector._();

  Map<String, String>? _hardwareEnvVars;
  List<InferenceVersion>? _availableVersions;
  InferenceVersion? _recommendedVersion;

  /// Detect all available inference versions on this mobile device
  Future<List<InferenceVersion>> detectAvailableVersions() async {
    if (_availableVersions != null) {
      return _availableVersions!;
    }

    final available = <InferenceVersion>[];
    
    // Get hardware capabilities
    final hardwareDetector = HardwareDetector.instance;
    _hardwareEnvVars = await hardwareDetector.detectHardware();
    
    debugPrint('🔍 Detecting available inference versions:');
    
    // Check for Native Mobile (1st Priority)
    if (_detectNativeMobile()) {
      available.add(InferenceVersion.nativeMobile);
      debugPrint('✅ Native Mobile: Available (hardware accelerator detected)');
    } else {
      debugPrint('❌ Native Mobile: Not available (no hardware accelerator)');
    }
    
    // Check for Apple Intelligence (2nd Priority - iOS only)
    if (_detectAppleIntelligence()) {
      available.add(InferenceVersion.appleIntelligence);
      debugPrint('✅ Apple Intelligence: Available');
    } else {
      debugPrint('❌ Apple Intelligence: Not available');
    }
    
    // Local models are always available as fallback
    available.add(InferenceVersion.local);
    debugPrint('✅ Local: Always available (fallback)');
    
    _availableVersions = available;
    debugPrint('📋 Available versions: ${available.map((v) => v.value).join(', ')}');
    
    return available;
  }

  /// Get the recommended inference version based on hardware and priority
  Future<InferenceVersion> getRecommendedVersion() async {
    if (_recommendedVersion != null) {
      return _recommendedVersion!;
    }

    final available = await detectAvailableVersions();
    
    // Follow priority hierarchy:
    // 1. Native Mobile (fastest, most efficient on supported hardware)
    if (available.contains(InferenceVersion.nativeMobile)) {
      final acceleratorType = _getAcceleratorType();
      debugPrint('🏆 Recommended: Native Mobile ($acceleratorType)');
      _recommendedVersion = InferenceVersion.nativeMobile;
      return _recommendedVersion!;
    }
    
    // 2. Apple Intelligence (high quality for iOS devices)
    if (available.contains(InferenceVersion.appleIntelligence)) {
      debugPrint('🏆 Recommended: Apple Intelligence');
      _recommendedVersion = InferenceVersion.appleIntelligence;
      return _recommendedVersion!;
    }
    
    // 3. Local fallback (works on all devices)
    debugPrint('🏆 Recommended: Local (fallback)');
    _recommendedVersion = InferenceVersion.local;
    return _recommendedVersion!;
  }

  /// Check if native mobile accelerator is available
  bool _detectNativeMobile() {
    if (_hardwareEnvVars == null) return false;
    
    // Check for Android Tensor chip or NPU
    if (Platform.isAndroid) {
      final hasTensorChip = _hardwareEnvVars!['HAS_TENSOR_CHIP'] == 'true';
      final hasAiAccelerator = _hardwareEnvVars!['HAS_AI_ACCELERATOR'] == 'true';
      final hasTfliteModels = _hardwareEnvVars!['HAS_TFLITE_MODELS'] == 'true';
      
      // Need both hardware acceleration AND models available
      return (hasTensorChip || hasAiAccelerator) && hasTfliteModels;
    }
    
    // Check for iOS Neural Engine
    if (Platform.isIOS) {
      final hasNeuralEngine = _hardwareEnvVars!['HAS_NEURAL_ENGINE'] == 'true';
      final hasCoreMLModels = _hardwareEnvVars!['HAS_COREML_MODELS'] == 'true';
      
      // Need both Neural Engine AND Core ML models available
      return hasNeuralEngine && hasCoreMLModels;
    }
    
    return false;
  }

  /// Check if Apple Intelligence is available
  bool _detectAppleIntelligence() {
    // Apple Intelligence is only available on iOS devices
    if (!Platform.isIOS) return false;
    
    // Check iOS version (Apple Intelligence requires iOS 18.1+)
    // This would need to be implemented via platform channels
    // For now, assume it's available on iOS devices
    
    // Check if Apple Intelligence is enabled in system settings
    // This would also need platform channel implementation
    
    // For now, return true if running on iOS and has Neural Engine
    // (which indicates a modern iOS device that could support Apple Intelligence)
    final hasNeuralEngine = _hardwareEnvVars?['HAS_NEURAL_ENGINE'] == 'true';
    return hasNeuralEngine;
  }

  /// Get the type of accelerator available
  String _getAcceleratorType() {
    if (_hardwareEnvVars == null) return 'unknown';
    
    if (Platform.isAndroid) {
      if (_hardwareEnvVars!['HAS_TENSOR_CHIP'] == 'true') {
        return 'Tensor Processing Unit';
      }
      if (_hardwareEnvVars!['HAS_AI_ACCELERATOR'] == 'true') {
        return 'NPU/GPU Accelerator';
      }
    }
    
    if (Platform.isIOS) {
      if (_hardwareEnvVars!['HAS_NEURAL_ENGINE'] == 'true') {
        return 'Neural Engine';
      }
    }
    
    return 'unknown';
  }

  /// Check if current device is iPhone with Neural Engine
  bool isNeuralEngineCapable() {
    return Platform.isIOS && 
           _hardwareEnvVars?['HAS_NEURAL_ENGINE'] == 'true';
  }

  /// Check if current device is Pixel with Tensor chip
  bool isTensorChipCapable() {
    return Platform.isAndroid && 
           _hardwareEnvVars?['HAS_TENSOR_CHIP'] == 'true';
  }

  /// Check if device has any AI accelerator
  bool hasAnyAccelerator() {
    return isNeuralEngineCapable() || 
           isTensorChipCapable() ||
           (_hardwareEnvVars?['HAS_AI_ACCELERATOR'] == 'true');
  }

  /// Get device-specific optimization settings
  Map<String, dynamic> getOptimizationSettings() {
    final settings = <String, dynamic>{};
    
    if (_detectNativeMobile()) {
      settings['use_hardware_acceleration'] = true;
      settings['batch_size'] = 1; // Optimized for mobile
      settings['max_tokens'] = 150; // Shorter stories for mobile
      settings['temperature'] = 0.7; // Balanced creativity/speed
      
      if (Platform.isAndroid) {
        settings['tflite_delegate'] = hasAnyAccelerator() ? 'gpu' : 'xnnpack';
      } else if (Platform.isIOS) {
        settings['coreml_enabled'] = true;
      }
    } else {
      // Fallback settings for devices without hardware acceleration
      settings['use_hardware_acceleration'] = false;
      settings['batch_size'] = 1;
      settings['max_tokens'] = 100; // Even shorter for CPU-only
      settings['temperature'] = 0.6;
      settings['tflite_delegate'] = 'xnnpack'; // CPU-optimized
    }
    
    return settings;
  }

  /// Reset cached detection results (for testing)
  void reset() {
    _hardwareEnvVars = null;
    _availableVersions = null;
    _recommendedVersion = null;
  }

  /// Get debug information about detected capabilities
  Map<String, dynamic> getDebugInfo() {
    return {
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
      'hardware_env_vars': _hardwareEnvVars ?? {},
      'available_versions': _availableVersions?.map((v) => v.value).toList() ?? [],
      'recommended_version': _recommendedVersion?.value,
      'has_tensor_chip': isTensorChipCapable(),
      'has_neural_engine': isNeuralEngineCapable(),
      'has_any_accelerator': hasAnyAccelerator(),
    };
  }
}