import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// High-level summary of how TFLite inference will be accelerated on this device.
///
/// Notes:
/// - **iOS (preferred when available)**: TFLite **Core ML delegate** (`CoreMlDelegate`)
///   routes ops through **Core ML**, enabling use of the **Apple Neural Engine** when supported.
/// - **iOS fallback**: TFLite **Metal GPU delegate** (`GpuDelegate`).
/// - **Android (preferred when available)**: **NNAPI**
///   (`InterpreterOptions.useNnApiForAndroid = true`) routes ops to device NPUs/TPUs when supported
///   (including Pixel Tensor accelerators).
/// - **Android fallback**: TFLite **GPU delegate** (`GpuDelegateV2`).
/// - **CPU fallback**: **XNNPACK** (`XNNPackDelegate`) for faster CPU inference.
class TfliteAccelerationInfo {
  final String accelerator; // 'nnapi' | 'coreml' | 'metal' | 'gpu' | 'xnnpack' | 'cpu'
  final bool isHardwareAccelerated;
  final int threads;

  const TfliteAccelerationInfo({
    required this.accelerator,
    required this.isHardwareAccelerated,
    required this.threads,
  });

  Map<String, String> toEnvVars() => {
        'TFLITE_ACCELERATOR': accelerator,
        'HAS_AI_ACCELERATOR': isHardwareAccelerated ? 'true' : 'false',
        'TFLITE_THREADS': threads.toString(),
      };
}

class TfliteAccelerationBundle {
  final InterpreterOptions options;
  final List<Delegate> delegates;
  final TfliteAccelerationInfo info;

  const TfliteAccelerationBundle({
    required this.options,
    required this.delegates,
    required this.info,
  });

  void dispose() {
    for (final d in delegates) {
      try {
        d.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }
}

class TfliteAcceleration {
  TfliteAcceleration._();

  static String? _cachedChoice; // cache delegate choice per process

  static int _defaultThreads() {
    final cpuCount = Platform.numberOfProcessors;
    return cpuCount >= 4 ? 4 : (cpuCount >= 2 ? 2 : 1);
  }

  /// Pick the best available accelerator.
  /// Returns one of: 'nnapi', 'coreml', 'metal', 'gpu', 'xnnpack', 'cpu'.
  static String detectBestAccelerator() {
    if (_cachedChoice != null) return _cachedChoice!;

    // Android: prefer NNAPI (it will route to accelerators when available).
    if (Platform.isAndroid) {
      _cachedChoice = 'nnapi';
      return _cachedChoice!;
    }

    // iOS: prefer Core ML delegate (can use Neural Engine).
    if (Platform.isIOS) {
      try {
        final d = CoreMlDelegate(options: CoreMlDelegateOptions());
        d.delete();
        _cachedChoice = 'coreml';
        return _cachedChoice!;
      } catch (e) {
        debugPrint('⚠️ Core ML delegate unavailable: $e');
      }

      try {
        final d = GpuDelegate();
        d.delete();
        _cachedChoice = 'metal';
        return _cachedChoice!;
      } catch (e) {
        debugPrint('⚠️ Metal delegate unavailable: $e');
      }
    }

    // Android: GPU delegate fallback (if NNAPI is not desired/available at runtime).
    if (Platform.isAndroid) {
      try {
        final d = GpuDelegateV2();
        d.delete();
        _cachedChoice = 'gpu';
        return _cachedChoice!;
      } catch (e) {
        debugPrint('⚠️ Android GPU delegate unavailable: $e');
      }
    }

    // CPU acceleration: XNNPACK
    try {
      final d = XNNPackDelegate(options: XNNPackDelegateOptions(numThreads: 1));
      d.delete();
      _cachedChoice = 'xnnpack';
      return _cachedChoice!;
    } catch (e) {
      debugPrint('⚠️ XNNPACK delegate unavailable: $e');
    }

    _cachedChoice = 'cpu';
    return _cachedChoice!;
  }

  /// Create interpreter options + delegate instances for the best available acceleration.
  ///
  /// Callers should keep the returned bundle and dispose it when the interpreter is closed.
  static TfliteAccelerationBundle createOptions({int? threads}) {
    final t = threads ?? _defaultThreads();
    final choice = detectBestAccelerator();

    final options = InterpreterOptions()..threads = t;
    final delegates = <Delegate>[];

    bool hw = false;
    String accelerator = 'cpu';

    try {
      if (choice == 'nnapi') {
        options.useNnApiForAndroid = true;
        accelerator = 'nnapi';
        hw = true;
      } else if (choice == 'coreml') {
        final d = CoreMlDelegate(options: CoreMlDelegateOptions());
        options.addDelegate(d);
        delegates.add(d);
        accelerator = 'coreml';
        hw = true;
      } else if (choice == 'metal') {
        final d = GpuDelegate();
        options.addDelegate(d);
        delegates.add(d);
        accelerator = 'metal';
        hw = true;
      } else if (choice == 'gpu') {
        final d = GpuDelegateV2();
        options.addDelegate(d);
        delegates.add(d);
        accelerator = 'gpu';
        hw = true;
      } else if (choice == 'xnnpack') {
        final d = XNNPackDelegate(options: XNNPackDelegateOptions(numThreads: t));
        options.addDelegate(d);
        delegates.add(d);
        accelerator = 'xnnpack';
        hw = false;
      } else {
        accelerator = 'cpu';
        hw = false;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to attach TFLite delegate ($choice): $e');
      accelerator = 'cpu';
      hw = false;
    }

    return TfliteAccelerationBundle(
      options: options,
      delegates: delegates,
      info: TfliteAccelerationInfo(
        accelerator: accelerator,
        isHardwareAccelerated: hw,
        threads: t,
      ),
    );
  }
}

