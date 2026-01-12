// Web / non-FFI stub.
//
// The real implementation uses `tflite_flutter` (FFI), which is not supported on Flutter Web.

class TfliteAcceleration {
  TfliteAcceleration._();

  /// On Web there is no on-device TFLite acceleration via FFI.
  static String detectBestAccelerator() => 'none';
}

