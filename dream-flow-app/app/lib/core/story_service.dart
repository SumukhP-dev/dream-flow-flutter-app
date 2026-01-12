import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_url_helper.dart';

typedef SharedPreferencesFactory = Future<SharedPreferences> Function();

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
  /// Approximate target length in **characters** (used to derive token budget).
  ///
  /// UI screens may present a word-count slider and convert words -> chars.
  final int targetLength;
  final int numScenes;
  final String? voice;
  final StoryProfileInput? profile;
  final String? primaryLanguage;
  final String? secondaryLanguage;
  final String? childProfileId;
  final int? childAge;
  final String? userId;
  final bool includeTextOverlay;

  StoryGenerationRequest({
    required this.prompt,
    required this.theme,
    this.targetLength = 1160,
    this.numScenes = 4,
    this.voice,
    this.profile,
    this.primaryLanguage,
    this.secondaryLanguage,
    this.childProfileId,
    this.childAge,
    this.userId,
    this.includeTextOverlay = false, // Default to false for cleaner images
  });

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'theme': theme,
        'target_length': targetLength,
        'num_scenes': numScenes,
        'include_text_overlay': includeTextOverlay, // Add text overlay parameter
        if (voice != null) 'voice': voice,
        if (profile != null) 'profile': profile!.toJson(),
        if (primaryLanguage != null) 'primary_language': primaryLanguage,
        if (secondaryLanguage != null) 'secondary_language': secondaryLanguage,
        // Also include legacy 'language' field for backward compatibility
        if (primaryLanguage != null) 'language': primaryLanguage,
        if (childProfileId != null) 'child_profile_id': childProfileId,
        if (childAge != null) 'child_age': childAge,
        if (userId != null) 'user_id': userId,
      };

  StoryGenerationRequest copyWith({
    String? prompt,
    String? theme,
    int? targetLength,
    int? numScenes,
    String? voice,
    StoryProfileInput? profile,
    String? primaryLanguage,
    String? secondaryLanguage,
    String? childProfileId,
    int? childAge,
    String? userId,
    bool? includeTextOverlay,
  }) {
    return StoryGenerationRequest(
      prompt: prompt ?? this.prompt,
      theme: theme ?? this.theme,
      targetLength: targetLength ?? this.targetLength,
      numScenes: numScenes ?? this.numScenes,
      voice: voice ?? this.voice,
      profile: profile ?? this.profile,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      secondaryLanguage: secondaryLanguage ?? this.secondaryLanguage,
      childProfileId: childProfileId ?? this.childProfileId,
      childAge: childAge ?? this.childAge,
      userId: userId ?? this.userId,
      includeTextOverlay: includeTextOverlay ?? this.includeTextOverlay,
    );
  }
}

class StoryExperience {
  final String storyText;
  final String theme;
  final String audioUrl;
  final List<String> frames;
  final String? sessionId;
  final bool? isFeatured;
  final String? youtubeVideoId;
  final String? youtubeUrl;
  final bool isChildMode;
  final int? childAge;
  final String? primaryLanguage;
  final String? secondaryLanguage;

  const StoryExperience({
    required this.storyText,
    required this.theme,
    required this.audioUrl,
    required this.frames,
    this.sessionId,
    this.isFeatured,
    this.youtubeVideoId,
    this.youtubeUrl,
    this.isChildMode = false,
    this.childAge,
    this.primaryLanguage,
    this.secondaryLanguage,
  });

  factory StoryExperience.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] as Map<String, dynamic>? ?? {};
    final youtubeVideoId = json['youtube_video_id'] as String?;
    final youtubeUrl = youtubeVideoId != null
        ? 'https://www.youtube.com/watch?v=$youtubeVideoId'
        : null;

    // Extract child mode information
    final childAge = json['child_age'] as int?;
    final isChildMode =
        childAge != null || (json['is_child_mode'] as bool? ?? false);

    // Extract language information from response
    final primaryLanguage = json['primary_language'] as String?;
    final secondaryLanguage = json['secondary_language'] as String?;

    // Convert relative URLs to full backend URLs if needed
    final rawAudioUrl = assets['audio'] as String? ?? '';
    final rawFrames = (assets['frames'] as List<dynamic>? ?? []).cast<String>();

    final backendUrl = BackendUrlHelper.getBackendUrl();
    String audioUrl = rawAudioUrl;
    List<String> frames = rawFrames;

    // Convert audio URL if it's a relative path
    if (audioUrl.isNotEmpty &&
        !audioUrl.startsWith('http://') &&
        !audioUrl.startsWith('https://')) {
      final cleanPath = audioUrl.startsWith('/') ? audioUrl : '/$audioUrl';
      audioUrl = '$backendUrl$cleanPath';
    }

    // Convert frame URLs if they're relative paths
    frames = rawFrames.map((frameUrl) {
      if (frameUrl.startsWith('http://') || frameUrl.startsWith('https://')) {
        return frameUrl;
      }
      final cleanPath = frameUrl.startsWith('/') ? frameUrl : '/$frameUrl';
      return '$backendUrl$cleanPath';
    }).toList();

    return StoryExperience(
      storyText: json['story_text'] as String,
      theme: json['theme'] as String,
      audioUrl: audioUrl,
      frames: frames,
      sessionId: json['session_id'] as String?,
      isFeatured: json['is_featured'] as bool?,
      youtubeVideoId: youtubeVideoId,
      youtubeUrl: youtubeUrl,
      isChildMode: isChildMode,
      childAge: childAge,
      primaryLanguage: primaryLanguage,
      secondaryLanguage: secondaryLanguage,
    );
  }

  StoryExperience copyWith({
    String? storyText,
    String? theme,
    String? audioUrl,
    List<String>? frames,
    String? sessionId,
    bool? isFeatured,
    String? youtubeVideoId,
    String? youtubeUrl,
    bool? isChildMode,
    int? childAge,
    String? primaryLanguage,
    String? secondaryLanguage,
  }) {
    return StoryExperience(
      storyText: storyText ?? this.storyText,
      theme: theme ?? this.theme,
      audioUrl: audioUrl ?? this.audioUrl,
      frames: frames ?? List<String>.from(this.frames),
      sessionId: sessionId ?? this.sessionId,
      isFeatured: isFeatured ?? this.isFeatured,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      isChildMode: isChildMode ?? this.isChildMode,
      childAge: childAge ?? this.childAge,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      secondaryLanguage: secondaryLanguage ?? this.secondaryLanguage,
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
  final bool isOffline;

  SessionHistoryItem({
    required this.sessionId,
    required this.theme,
    required this.prompt,
    this.thumbnailUrl,
    required this.createdAt,
    this.isOffline = false,
  });

  factory SessionHistoryItem.fromJson(Map<String, dynamic> json) {
    return SessionHistoryItem(
      sessionId: json['session_id'] as String,
      theme: json['theme'] as String,
      prompt: json['prompt'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: json['created_at'] as String,
      isOffline: json['is_offline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'theme': theme,
        'prompt': prompt,
        'thumbnail_url': thumbnailUrl,
        'created_at': createdAt,
        'is_offline': isOffline,
      };
}

class PublicStoryItem {
  final String sessionId;
  final String theme;
  final String prompt;
  final String storyText;
  final String? thumbnailUrl;
  final String ageRating;
  final int likeCount;
  final String createdAt;
  final bool isLiked;

  PublicStoryItem({
    required this.sessionId,
    required this.theme,
    required this.prompt,
    required this.storyText,
    this.thumbnailUrl,
    required this.ageRating,
    required this.likeCount,
    required this.createdAt,
    required this.isLiked,
  });

  factory PublicStoryItem.fromJson(Map<String, dynamic> json) {
    return PublicStoryItem(
      sessionId: json['session_id'] as String,
      theme: json['theme'] as String,
      prompt: json['prompt'] as String,
      storyText: json['story_text'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      ageRating: json['age_rating'] as String? ?? 'all',
      likeCount: json['like_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }
}

class PublicStoriesResponse {
  final List<PublicStoryItem> stories;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  PublicStoriesResponse({
    required this.stories,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory PublicStoriesResponse.fromJson(Map<String, dynamic> json) {
    return PublicStoriesResponse(
      stories: (json['stories'] as List<dynamic>?)
              ?.map((item) =>
                  PublicStoryItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class StoryDetail {
  final String sessionId;
  final String theme;
  final String prompt;
  final String storyText;
  final String? thumbnailUrl;
  final List<String> frames;
  final String? audioUrl;
  final String ageRating;
  final int likeCount;
  final bool isLiked;
  final bool isPublic;
  final bool isApproved;
  final String createdAt;
  final bool canShare;

  StoryDetail({
    required this.sessionId,
    required this.theme,
    required this.prompt,
    required this.storyText,
    this.thumbnailUrl,
    required this.frames,
    this.audioUrl,
    required this.ageRating,
    required this.likeCount,
    required this.isLiked,
    required this.isPublic,
    required this.isApproved,
    required this.createdAt,
    required this.canShare,
  });

  factory StoryDetail.fromJson(Map<String, dynamic> json) {
    return StoryDetail(
      sessionId: json['session_id'] as String,
      theme: json['theme'] as String,
      prompt: json['prompt'] as String,
      storyText: json['story_text'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      frames: (json['frames'] as List<dynamic>?)?.cast<String>() ?? [],
      audioUrl: json['audio_url'] as String?,
      ageRating: json['age_rating'] as String? ?? 'all',
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isPublic: json['is_public'] as bool? ?? false,
      isApproved: json['is_approved'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      canShare: json['can_share'] as bool? ?? false,
    );
  }

}

class StoryService {
  StoryService({
    String? baseUrl,
    http.Client? client,
    SharedPreferencesFactory? preferences,
  })  : _baseUrl = BackendUrlHelper.getBackendUrl(
          baseUrl: baseUrl,
          defaultValue: 'http://localhost:8080', // Default to local backend
        ),
        _client = client ?? http.Client(),
        _preferences = preferences ?? SharedPreferences.getInstance {
    print('📡 StoryService initialized with baseUrl: $_baseUrl');
  }

  final String _baseUrl;
  final http.Client _client;
  final SharedPreferencesFactory _preferences;
  static const String _cacheKey = 'session_history_cache';
  static const String _cacheTimestampKey = 'session_history_cache_timestamp';
  static const Duration _cacheValidDuration = Duration(hours: 1);
  static const String offlineSessionPrefix = 'offline-';
  static const String _offlineHistoryKey = 'offline_story_history_v1';
  static const int _offlineHistoryLimit = 20;

  String get baseUrl => _baseUrl;
  http.Client get client => _client;

  /// Get authentication token from Supabase
  Future<String?> _getAuthToken() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      print('Failed to get auth token: $e');
      return null;
    }
  }

  Future<StoryExperience> generateStory(StoryGenerationRequest request) async {
    final uri = Uri.parse('$_baseUrl/api/v1/story');

    try {
      final response = await _client
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      )
          .timeout(
        const Duration(seconds: 300), // 5 minute timeout
        onTimeout: () {
          throw StoryServiceException(
            'Request timed out. Please check your internet connection and try again.',
          );
        },
      );

      if (response.statusCode >= 400) {
        String errorMessage = 'Generation failed';
        try {
          final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
          if (errorBody != null) {
            final error = errorBody['error'] as String?;
            final detailValue = errorBody['detail'];

            // Handle detail as either a string or an array of violation objects
            if (detailValue is List) {
              // Guardrail violations: extract messages from array of objects
              final violations = detailValue.cast<Map<String, dynamic>>();
              final violationMessages = violations
                  .map((v) {
                    final detail = v['detail'] as String?;
                    if (detail != null) return detail;
                    // Fallback to category if detail is missing
                    final category = v['category'] as String?;
                    return category != null
                        ? 'Violation in category: $category'
                        : 'Unknown violation';
                  })
                  .where((msg) => msg.isNotEmpty)
                  .join('; ');
              errorMessage = violationMessages.isNotEmpty
                  ? violationMessages
                  : 'Content violates safety guidelines. Please try a different story prompt.';
            } else if (detailValue is String) {
              errorMessage = detailValue;
            } else {
              errorMessage = error ?? response.body;
            }

            // Fallback to error field if detail parsing didn't work
            if (errorMessage == 'Generation failed' && error != null) {
              errorMessage = error;
            }
          } else {
            errorMessage =
                response.body.isNotEmpty ? response.body : 'Unknown error';
          }
        } catch (_) {
          errorMessage =
              response.body.isNotEmpty ? response.body : 'Unknown error';
        }

        throw StoryServiceException(
          'Generation failed (${response.statusCode}): $errorMessage',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return StoryExperience.fromJson(decoded);
    } on SocketException {
      throw StoryServiceException(
        'Connection failed. If the problem persists, please check your internet connection or VPN.',
      );
    } on HttpException {
      throw StoryServiceException(
        'Connection failed. If the problem persists, please check your internet connection or VPN.',
      );
    } on FormatException {
      throw StoryServiceException(
        'Invalid response from server. Please try again.',
      );
    } on StoryServiceException {
      rethrow;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('connection') ||
          errorStr.contains('network') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('socket')) {
        throw StoryServiceException(
          'Connection failed. If the problem persists, please check your internet connection or VPN.',
        );
      }
      throw StoryServiceException(
        'An unexpected error occurred: ${e.toString()}',
      );
    }
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
      final uri =
          Uri.parse('$_baseUrl/api/v1/history').replace(queryParameters: {
        'user_id': userId,
        'limit': limit.toString(),
      });

      final response = await _client.get(uri);

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
          .map((json) =>
              SessionHistoryItem.fromJson(json as Map<String, dynamic>))
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
      final prefs = await _preferences();
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
          .map((json) =>
              SessionHistoryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If cache is corrupted, return null to force refresh
      return null;
    }
  }

  /// Save history to cache
  Future<void> _saveCachedHistory(List<SessionHistoryItem> sessions) async {
    try {
      final prefs = await _preferences();
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
      final prefs = await _preferences();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      // Silently fail
      print('Warning: Failed to clear history cache: $e');
    }
  }

  String _generateOfflineSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 997) % 1000000;
    return '$offlineSessionPrefix$timestamp-$random';
  }

  Future<List<Map<String, dynamic>>> _loadOfflineEntries() async {
    try {
      final prefs = await _preferences();
      final raw = prefs.getString(_offlineHistoryKey);
      if (raw == null || raw.isEmpty) {
        return [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistOfflineEntries(List<Map<String, dynamic>> entries) async {
    final prefs = await _preferences();
    await prefs.setString(_offlineHistoryKey, jsonEncode(entries));
  }

  bool _isOfflineSessionId(String sessionId) {
    return sessionId.startsWith(offlineSessionPrefix);
  }

  Future<Map<String, dynamic>?> _findOfflineEntry(String sessionId) async {
    final entries = await _loadOfflineEntries();
    for (final entry in entries) {
      if (entry['session_id'] == sessionId) {
        return entry;
      }
    }
    return null;
  }

  Future<String> saveOfflineStory({
    required StoryGenerationRequest request,
    required StoryExperience experience,
  }) async {
    final offlineId = _generateOfflineSessionId();
    final entry = {
      'session_id': offlineId,
      'prompt': request.prompt,
      'theme': experience.theme,
      'story_text': experience.storyText,
      'thumbnail_url':
          experience.frames.isNotEmpty ? experience.frames.first : null,
      'frames': List<String>.from(experience.frames),
      'audio_url': experience.audioUrl,
      'age_rating': 'all',
      'like_count': 0,
      'is_liked': false,
      'is_public': false,
      'is_approved': false,
      'created_at': DateTime.now().toIso8601String(),
      'can_share': false,
      'is_offline': true,
    };

    final entries = await _loadOfflineEntries();
    entries.insert(0, entry);
    if (entries.length > _offlineHistoryLimit) {
      entries.removeRange(_offlineHistoryLimit, entries.length);
    }
    await _persistOfflineEntries(entries);
    return offlineId;
  }

  Future<List<SessionHistoryItem>> getOfflineHistory() async {
    final entries = await _loadOfflineEntries();
    return entries
        .map(
          (entry) => SessionHistoryItem(
            sessionId: entry['session_id'] as String,
            theme: entry['theme'] as String,
            prompt: entry['prompt'] as String,
            thumbnailUrl: entry['thumbnail_url'] as String?,
            createdAt: entry['created_at'] as String? ??
                DateTime.now().toIso8601String(),
            isOffline: true,
          ),
        )
        .toList();
  }

  /// Get public stories that have been approved for sharing
  Future<PublicStoriesResponse> getPublicStories({
    int limit = 20,
    int offset = 0,
    String? theme,
    String? ageRating,
    String sortBy = 'created_at',
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort_by': sortBy,
      };
      if (theme != null) queryParams['theme'] = theme;
      if (ageRating != null) queryParams['age_rating'] = ageRating;

      final uri = Uri.parse('$_baseUrl/api/v1/stories/public')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode >= 400) {
        throw StoryServiceException(
          'Failed to fetch public stories (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return PublicStoriesResponse.fromJson(decoded);
    } catch (e) {
      if (e is StoryServiceException) rethrow;
      throw StoryServiceException(
        'Failed to fetch public stories: ${e.toString()}',
      );
    }
  }

  /// Share a story (make it public)
  Future<void> shareStory({
    required String sessionId,
    String? ageRating,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw StoryServiceException(
          'You must be logged in to share stories',
        );
      }

      final uri = Uri.parse('$_baseUrl/api/v1/stories/$sessionId/share');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'is_public': true,
          if (ageRating != null) 'age_rating': ageRating,
        }),
      );

      if (response.statusCode >= 400) {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final error = errorBody?['detail'] as String? ?? response.body;
        throw StoryServiceException(
          'Failed to share story (${response.statusCode}): $error',
        );
      }
    } catch (e) {
      if (e is StoryServiceException) rethrow;
      throw StoryServiceException(
        'Failed to share story: ${e.toString()}',
      );
    }
  }

  /// Unshare a story (make it private)
  Future<void> unshareStory(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw StoryServiceException(
          'You must be logged in to unshare stories',
        );
      }

      final uri = Uri.parse('$_baseUrl/api/v1/stories/$sessionId/share');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'is_public': false}),
      );

      if (response.statusCode >= 400) {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final error = errorBody?['detail'] as String? ?? response.body;
        throw StoryServiceException(
          'Failed to unshare story (${response.statusCode}): $error',
        );
      }
    } catch (e) {
      if (e is StoryServiceException) rethrow;
      throw StoryServiceException(
        'Failed to unshare story: ${e.toString()}',
      );
    }
  }

  /// Report an inappropriate story
  Future<void> reportStory({
    required String sessionId,
    required String reason,
    String? details,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw StoryServiceException(
          'You must be logged in to report stories',
        );
      }

      final uri = Uri.parse('$_baseUrl/api/v1/stories/$sessionId/report');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'reason': reason,
          if (details != null) 'details': details,
        }),
      );

      if (response.statusCode >= 400) {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final error = errorBody?['detail'] as String? ?? response.body;
        throw StoryServiceException(
          'Failed to report story (${response.statusCode}): $error',
        );
      }
    } catch (e) {
      if (e is StoryServiceException) rethrow;
      throw StoryServiceException(
        'Failed to report story: ${e.toString()}',
      );
    }
  }

  /// Like or unlike a story
  Future<bool> likeStory(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw StoryServiceException(
          'You must be logged in to like stories',
        );
      }

      final uri = Uri.parse('$_baseUrl/api/v1/stories/$sessionId/like');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.post(
        uri,
        headers: headers,
      );

      if (response.statusCode >= 400) {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final error = errorBody?['detail'] as String? ?? response.body;
        throw StoryServiceException(
          'Failed to like story (${response.statusCode}): $error',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['liked'] as bool? ?? false;
    } catch (e) {
      if (e is StoryServiceException) rethrow;
      throw StoryServiceException(
        'Failed to like story: ${e.toString()}',
      );
    }
  }

  /// Fetch a single story as a `StoryExperience`.
  ///
  /// This is a convenience wrapper used by services like `FamilyLibraryService`.
  /// It maps the story detail response into the `StoryExperience` shape used by
  /// playback screens.
  Future<StoryExperience?> getStoryById(String sessionId) async {
    try {
      final detail = await getStoryDetails(sessionId);

      // Convert relative URLs to full backend URLs if needed (same logic as
      // StoryExperience.fromJson).
      final backendUrl = BackendUrlHelper.getBackendUrl();

      String audioUrl = detail.audioUrl ?? '';
      if (audioUrl.isNotEmpty &&
          !audioUrl.startsWith('http://') &&
          !audioUrl.startsWith('https://')) {
        final cleanPath = audioUrl.startsWith('/') ? audioUrl : '/$audioUrl';
        audioUrl = '$backendUrl$cleanPath';
      }

      final frames = detail.frames.map((frameUrl) {
        if (frameUrl.startsWith('http://') || frameUrl.startsWith('https://')) {
          return frameUrl;
        }
        final cleanPath = frameUrl.startsWith('/') ? frameUrl : '/$frameUrl';
        return '$backendUrl$cleanPath';
      }).toList();

      return StoryExperience(
        storyText: detail.storyText,
        theme: detail.theme,
        audioUrl: audioUrl,
        frames: frames,
        sessionId: detail.sessionId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get detailed information about a story
  Future<StoryDetail> getStoryDetails(String sessionId) async {
    if (_isOfflineSessionId(sessionId)) {
      final entry = await _findOfflineEntry(sessionId);
      if (entry == null || entry.isEmpty) {
        throw StoryServiceException('Story not found');
      }
      return StoryDetail(
        sessionId: sessionId,
        theme: entry['theme'] as String,
        prompt: entry['prompt'] as String,
        storyText: entry['story_text'] as String,
        thumbnailUrl: entry['thumbnail_url'] as String?,
        frames: (entry['frames'] as List<dynamic>? ?? []).cast<String>(),
        audioUrl: entry['audio_url'] as String?,
        ageRating: entry['age_rating'] as String? ?? 'all',
        likeCount: entry['like_count'] as int? ?? 0,
        isLiked: entry['is_liked'] as bool? ?? false,
        isPublic: entry['is_public'] as bool? ?? false,
        isApproved: entry['is_approved'] as bool? ?? false,
        createdAt:
            entry['created_at'] as String? ?? DateTime.now().toIso8601String(),
        canShare: entry['can_share'] as bool? ?? false,
      );
    }
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/stories/$sessionId');

      final response = await _client.get(uri);

      if (response.statusCode >= 400) {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final error = errorBody?['detail'] as String? ?? response.body;
        throw StoryServiceException(
          'Failed to fetch story details (${response.statusCode}): $error',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return StoryDetail.fromJson(decoded);
    } catch (e) {
      if (e is StoryServiceException) rethrow;
      throw StoryServiceException(
        'Failed to fetch story details: ${e.toString()}',
      );
    }
  }
}
