import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StoryProfileInput {
  final String mood;
  final String routine;
  final List<String> preferences;
  final List<String> favoriteCharacters;
  final List<String> calmingElements;

  StoryProfileInput({
    required this.mood,
    required this.routine,
    this.preferences = const [],
    this.favoriteCharacters = const [],
    this.calmingElements = const [],
  });

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'routine': routine,
        'preferences': preferences,
        'favorite_characters': favoriteCharacters,
        'calming_elements': calmingElements,
      };
}

class StoryGenerationRequest {
  final String prompt;
  final String theme;
  final int targetLength;
  final int numScenes;
  final String? voice;
  final StoryProfileInput? profile;

  StoryGenerationRequest({
    required this.prompt,
    required this.theme,
    this.targetLength = 400,
    this.numScenes = 4,
    this.voice,
    this.profile,
  });

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'theme': theme,
        'target_length': targetLength,
        'num_scenes': numScenes,
        if (voice != null) 'voice': voice,
        if (profile != null) 'profile': profile!.toJson(),
      };
}

class StoryExperience {
  final String storyText;
  final String theme;
  final String audioUrl;
  final String videoUrl;
  final List<String> frames;
  final String? sessionId;

  const StoryExperience({
    required this.storyText,
    required this.theme,
    required this.audioUrl,
    required this.videoUrl,
    required this.frames,
    this.sessionId,
  });

  factory StoryExperience.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] as Map<String, dynamic>;
    return StoryExperience(
      storyText: json['story_text'] as String,
      theme: json['theme'] as String,
      audioUrl: assets['audio'] as String,
      videoUrl: assets['video'] as String,
      frames: (assets['frames'] as List<dynamic>).cast<String>(),
      sessionId: json['session_id'] as String?,
    );
  }
}

class StoryServiceException implements Exception {
  final String message;
  StoryServiceException(this.message);

  @override
  String toString() => 'StoryServiceException: $message';
}

class SessionHistoryItem {
  final String sessionId;
  final String theme;
  final String prompt;
  final String? thumbnailUrl;
  final String createdAt;

  SessionHistoryItem({
    required this.sessionId,
    required this.theme,
    required this.prompt,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory SessionHistoryItem.fromJson(Map<String, dynamic> json) {
    return SessionHistoryItem(
      sessionId: json['session_id'] as String,
      theme: json['theme'] as String,
      prompt: json['prompt'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'theme': theme,
        'prompt': prompt,
        'thumbnail_url': thumbnailUrl,
        'created_at': createdAt,
      };
}

class StoryService {
  StoryService({String? baseUrl})
      : _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8080',
            );

  final String _baseUrl;
  static const String _cacheKey = 'session_history_cache';
  static const String _cacheTimestampKey = 'session_history_cache_timestamp';
  static const Duration _cacheValidDuration = Duration(hours: 1);

  Future<StoryExperience> generateStory(StoryGenerationRequest request) async {
    final uri = Uri.parse('$_baseUrl/api/v1/story');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode >= 400) {
      final detail = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw StoryServiceException(
        'Generation failed (${response.statusCode}): $detail',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return StoryExperience.fromJson(decoded);
  }

  /// Get session history with offline caching support.
  /// Returns cached data if available and fresh, otherwise fetches from API.
  Future<List<SessionHistoryItem>> getHistory({
    required String userId,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cached = await _loadCachedHistory();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    // Fetch from API
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/history')
          .replace(queryParameters: {
        'user_id': userId,
        'limit': limit.toString(),
      });

      final response = await http.get(uri);

      if (response.statusCode >= 400) {
        // If API fails, try to return cached data
        final cached = await _loadCachedHistory();
        if (cached != null && cached.isNotEmpty) {
          return cached;
        }
        throw StoryServiceException(
          'Failed to fetch history (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final sessions = (decoded['sessions'] as List<dynamic>)
          .map((json) => SessionHistoryItem.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache the results
      await _saveCachedHistory(sessions);

      return sessions;
    } catch (e) {
      // If network fails, try to return cached data
      final cached = await _loadCachedHistory();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  /// Load cached history if it exists and is still valid
  Future<List<SessionHistoryItem>?> _loadCachedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      
      if (timestamp == null) return null;

      final cacheAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );

      // Check if cache is still valid
      if (cacheAge > _cacheValidDuration) {
        return null;
      }

      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null) return null;

      final decoded = jsonDecode(cachedJson) as List<dynamic>;
      return decoded
          .map((json) => SessionHistoryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If cache is corrupted, return null to force refresh
      return null;
    }
  }

  /// Save history to cache
  Future<void> _saveCachedHistory(List<SessionHistoryItem> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
        sessions.map((s) => s.toJson()).toList(),
      );
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silently fail - caching is not critical
      print('Warning: Failed to cache session history: $e');
    }
  }

  /// Clear cached history
  Future<void> clearHistoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      // Silently fail
      print('Warning: Failed to clear history cache: $e');
    }
  }
}









