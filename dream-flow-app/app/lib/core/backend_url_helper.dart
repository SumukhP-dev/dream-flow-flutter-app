import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Helper utility for processing backend URLs
/// Handles Android emulator localhost conversion automatically
class BackendUrlHelper {
  /// Process backend URL to handle Android emulator localhost conversion
  /// On Android emulator, converts localhost/127.0.0.1 to 10.0.2.2 to access host machine
  /// On web, returns URL as-is (no conversion needed)
  static String processUrl(String url) {
    if (url.isEmpty) return url;

    // On web, Platform.isAndroid is not available, so return URL as-is
    if (kIsWeb) {
      return url;
    }

    // On Android emulator, convert localhost/127.0.0.1 to 10.0.2.2 to access host machine
    try {
      if (Platform.isAndroid) {
        return url
            .replaceAll('http://localhost:', 'http://10.0.2.2:')
            .replaceAll('http://127.0.0.1:', 'http://10.0.2.2:')
            .replaceAll('https://localhost:', 'https://10.0.2.2:')
            .replaceAll('https://127.0.0.1:', 'https://10.0.2.2:');
      }
    } catch (e) {
      // Platform.isAndroid not available (e.g., on web), return URL as-is
      return url;
    }
    return url;
  }

  /// Get backend URL from environment with Android emulator support
  ///
  /// IMPORTANT: Only converts localhost to 10.0.2.2 for EXTERNAL backends (on host machine).
  /// For LOCAL backends (running on device), keeps localhost as-is.
  static String getBackendUrl({
    String? baseUrl,
    String defaultValue = 'http://localhost:8080',
  }) {
    final url = baseUrl ??
        const String.fromEnvironment(
          'BACKEND_URL',
          defaultValue: 'http://localhost:8080',
        );

    // If URL is empty or matches the default local backend pattern, don't convert
    // (local backend runs on device, so localhost/127.0.0.1 should not be converted)
    if (url.isEmpty) {
      return defaultValue;
    }
    
    // Check if this is a local backend URL (localhost or 127.0.0.1 with default port)
    final isLocalBackend = url == defaultValue ||
        url == 'http://localhost:8080' ||
        url == 'http://127.0.0.1:8080';
    
    if (isLocalBackend) {
      // For localhost URLs, always process them (converts to 10.0.2.2 on Android emulator)
      // This allows connection to FastAPI backend running on host machine
      return processUrl(url);
    }

    // Only convert for external backends (running on host machine)
    return processUrl(url);
  }
}
