import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum VideoQuality { low, medium, high, original }

class CDNService {
  static const String cdnBaseUrl = 'CDN_BASE_URL'; // Set from config
  static const String originalBaseUrl = 'ORIGINAL_BASE_URL'; // Set from config

  /// Get CDN URL for an asset
  static String getCdnUrl(String originalUrl, {VideoQuality? quality}) {
    if (cdnBaseUrl == 'CDN_BASE_URL' || cdnBaseUrl.isEmpty) {
      // CDN not configured, return original URL
      return originalUrl;
    }

    // Extract path from original URL
    final uri = Uri.parse(originalUrl);
    final path = uri.path;

    // If quality is specified, add quality parameter
    if (quality != null && quality != VideoQuality.original) {
      final qualityParam = _getQualityParam(quality);
      return '$cdnBaseUrl$path?quality=$qualityParam';
    }

    return '$cdnBaseUrl$path';
  }

  static String _getQualityParam(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.low:
        return '360p';
      case VideoQuality.medium:
        return '720p';
      case VideoQuality.high:
        return '1080p';
      case VideoQuality.original:
        return 'original';
    }
  }

  /// Get appropriate quality based on network connection
  static Future<VideoQuality> getRecommendedQuality() async {
    if (kIsWeb) {
      // Web: default to medium quality
      return VideoQuality.medium;
    }

    try {
      final connectivityResults = await Connectivity().checkConnectivity();

      if (connectivityResults.contains(ConnectivityResult.mobile)) {
        // Mobile data: use low quality to save bandwidth
        return VideoQuality.low;
      } else if (connectivityResults.contains(ConnectivityResult.wifi) ||
          connectivityResults.contains(ConnectivityResult.ethernet)) {
        // WiFi/Ethernet: use high quality
        return VideoQuality.high;
      } else if (connectivityResults.contains(ConnectivityResult.none)) {
        // No connection: return original (will use cached if available)
        return VideoQuality.original;
      } else {
        return VideoQuality.medium;
      }
    } catch (e) {
      // Error checking connectivity: default to medium
      return VideoQuality.medium;
    }
  }

  /// Get progressive loading URLs (multiple qualities for adaptive streaming)
  static List<String> getProgressiveUrls(String originalUrl) {
    final baseUrl = getCdnUrl(originalUrl);
    return [
      '$baseUrl?quality=360p', // Low quality
      '$baseUrl?quality=720p', // Medium quality
      '$baseUrl?quality=1080p', // High quality
      originalUrl, // Original as fallback
    ];
  }

  /// Check if URL is a CDN URL
  static bool isCdnUrl(String url) {
    if (cdnBaseUrl == 'CDN_BASE_URL' || cdnBaseUrl.isEmpty) {
      return false;
    }
    return url.startsWith(cdnBaseUrl);
  }
}

