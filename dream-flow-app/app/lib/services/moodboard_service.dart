import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MoodboardService {
  MoodboardService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8080',
            );

  static const _cacheKey = 'moodboard_loops';
  static const _cacheVersion = 2;
  static const _maxCachedFrames = 6;

  final http.Client _client;
  final String _baseUrl;

  Future<MoodboardUploadResult> uploadInspiration(
    MoodboardInspiration inspiration, {
    String? sessionId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/moodboard/inspiration');
      final payload = inspiration.toPayload(sessionId: sessionId);
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 400) {
        throw Exception('Upload failed');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = MoodboardUploadResult.fromJson(decoded);
      if (sessionId != null) {
        await _cacheLoop(sessionId, result.frames);
      }
      return result;
    } catch (_) {
      final fallback = MoodboardUploadResult(
        previewUrl: inspiration.previewPlaceholder,
        frames: inspiration.generateLocalFrames(),
        requiresModeration: false,
      );
      if (sessionId != null) {
        await _cacheLoop(sessionId, fallback.frames);
      }
      return fallback;
    }
  }

  Future<List<String>> loadCachedLoop(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entry = decoded[sessionId];
      if (entry is List) {
        return entry.map((item) => item.toString()).toList();
      }
      if (entry is Map<String, dynamic>) {
        final frames = entry['frames'];
        if (frames is List) {
          return frames.map((item) => item.toString()).toList();
        }
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  Future<List<String>> ensureOfflineLoop(
    String sessionId,
    List<String> fallbackFrames,
  ) async {
    final cached = await loadCachedLoop(sessionId);
    if (cached.isNotEmpty) {
      return cached;
    }
    if (fallbackFrames.isEmpty) {
      return [];
    }
    await _cacheLoop(sessionId, fallbackFrames);
    return await loadCachedLoop(sessionId);
  }

  Future<void> _cacheLoop(String sessionId, List<String> frames) async {
    if (frames.isEmpty) return;
    final normalizedFrames = <String>[];
    for (final frame in frames.take(_maxCachedFrames)) {
      if (frame.startsWith('data:image')) {
        normalizedFrames.add(frame);
        continue;
      }
      final normalized = await _downloadAsDataUri(frame);
      normalizedFrames.add(normalized ?? frame);
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    Map<String, dynamic> decoded = {};
    if (raw != null) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = {};
      }
    }
    decoded[sessionId] = {
      'frames': normalizedFrames,
      'updated_at': DateTime.now().toIso8601String(),
      'version': _cacheVersion,
    };
    await prefs.setString(_cacheKey, jsonEncode(decoded));
  }

  Future<String?> _downloadAsDataUri(String url) async {
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode >= 400) {
        return null;
      }
      final encoded = base64Encode(response.bodyBytes);
      return 'data:image/png;base64,$encoded';
    } catch (_) {
      return null;
    }
  }
}

class MoodboardInspiration {
  MoodboardInspiration.photo({
    required this.bytes,
    this.caption,
    this.caregiverConsent = true,
  })  : type = 'photo',
        strokes = const [];

  MoodboardInspiration.canvas({
    required this.strokes,
    this.caption,
    this.caregiverConsent = true,
  })  : type = 'sketch',
        bytes = null;

  final String type;
  final Uint8List? bytes;
  final List<MoodboardStroke> strokes;
  final String? caption;
  final bool caregiverConsent;

  Map<String, dynamic> toPayload({String? sessionId}) => {
        'type': type,
        if (sessionId != null) 'session_id': sessionId,
        if (bytes != null) 'data': base64Encode(bytes!),
        if (strokes.isNotEmpty)
          'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
        if (caption != null) 'caption': caption,
        'caregiver_consent': caregiverConsent,
      };

  List<String> generateLocalFrames() {
    if (bytes != null) {
      return ['data:image/png;base64,${base64Encode(bytes!)}'];
    }
    if (strokes.isNotEmpty) {
      final encoded = strokes.map((stroke) => stroke.colorHex).join('-');
      return [
        'https://placehold.co/600x400/${encoded.substring(0, 6)}/ffffff.png',
      ];
    }
    return [
      'https://placehold.co/600x400/0f172a/94a3b8.png?text=Moodboard+Preview'
    ];
  }

  String get previewPlaceholder {
    if (bytes != null) {
      return 'data:image/png;base64,${base64Encode(bytes!)}';
    }
    return 'https://placehold.co/400x240/0f172a/94a3b8.png?text=Sketch';
  }
}

class MoodboardStroke {
  MoodboardStroke({
    required this.points,
    required this.width,
    required this.colorHex,
  });

  final List<Map<String, double>> points;
  final double width;
  final String colorHex;

  Map<String, dynamic> toJson() => {
        'points': points,
        'width': width,
        'color': colorHex,
      };
}

class MoodboardUploadResult {
  MoodboardUploadResult({
    required this.previewUrl,
    required this.frames,
    required this.requiresModeration,
  });

  final String previewUrl;
  final List<String> frames;
  final bool requiresModeration;

  factory MoodboardUploadResult.fromJson(Map<String, dynamic> json) {
    return MoodboardUploadResult(
      previewUrl: json['preview_url'] as String? ??
          'https://placehold.co/400x240/0f172a/94a3b8.png?text=Moodboard',
      frames: (json['frames'] as List<dynamic>? ?? [])
          .map((f) => f.toString())
          .toList(),
      requiresModeration: json['requires_moderation'] as bool? ?? false,
    );
  }
}

