import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/backend_url_helper.dart';

class StoryTemplate {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final String mood;
  final String routine;
  final String category;
  final bool isFeatured;
  final String? sampleStoryText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoryTemplate({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.mood,
    required this.routine,
    required this.category,
    required this.isFeatured,
    this.sampleStoryText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoryTemplate.fromJson(Map<String, dynamic> json) {
    return StoryTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      emoji: json['emoji'] as String,
      description: json['description'] as String,
      mood: json['mood'] as String,
      routine: json['routine'] as String,
      category: json['category'] as String,
      isFeatured: json['is_featured'] as bool? ?? false,
      sampleStoryText: json['sample_story_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Convert to Map for compatibility with existing theme usage
  Map<String, String> toThemeMap() {
    return {
      'title': title,
      'emoji': emoji,
      'description': description,
      'mood': mood,
      'routine': routine,
      'category': category,
    };
  }
}

class StoryTemplatesResponse {
  final List<StoryTemplate> templates;
  final List<StoryTemplate> featured;
  final Map<String, List<StoryTemplate>> categories;

  const StoryTemplatesResponse({
    required this.templates,
    required this.featured,
    required this.categories,
  });

  factory StoryTemplatesResponse.fromJson(Map<String, dynamic> json) {
    final templatesList = (json['templates'] as List<dynamic>)
        .map((item) => StoryTemplate.fromJson(item as Map<String, dynamic>))
        .toList();
    
    final featuredList = (json['featured'] as List<dynamic>)
        .map((item) => StoryTemplate.fromJson(item as Map<String, dynamic>))
        .toList();

    final categoriesMap = <String, List<StoryTemplate>>{};
    final categoriesJson = json['categories'] as Map<String, dynamic>;
    for (final entry in categoriesJson.entries) {
      categoriesMap[entry.key] = (entry.value as List<dynamic>)
          .map((item) => StoryTemplate.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return StoryTemplatesResponse(
      templates: templatesList,
      featured: featuredList,
      categories: categoriesMap,
    );
  }
}

class StoryTemplateService {
  static const String _defaultBackendUrl = 'http://localhost:8080';
  
  // Cache templates to avoid repeated API calls
  StoryTemplatesResponse? _cachedTemplates;
  DateTime? _lastFetchTime;
  static const Duration _cacheTimeout = Duration(minutes: 30);

  String get _backendUrl {
    // Use BackendUrlHelper to get the properly processed URL for Android emulator
    return BackendUrlHelper.getBackendUrl(
      defaultValue: 'http://localhost:8080',
    );
  }

  Future<StoryTemplatesResponse> getStoryTemplates({bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh && _cachedTemplates != null && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _cacheTimeout) {
        debugPrint('📦 Using cached story templates');
        return _cachedTemplates!;
      }
    }

    try {
      debugPrint('🔍 Fetching story templates from backend: $_backendUrl');
      final url = Uri.parse('$_backendUrl/api/v1/templates');
      
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final templatesResponse = StoryTemplatesResponse.fromJson(jsonData);
        
        // Cache the result
        _cachedTemplates = templatesResponse;
        _lastFetchTime = DateTime.now();
        
        debugPrint('✅ Successfully fetched ${templatesResponse.templates.length} story templates');
        return templatesResponse;
      } else {
        debugPrint('⚠️ Backend returned ${response.statusCode}: ${response.body}');
        return _getFallbackTemplates();
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching story templates: $e');
      return _getFallbackTemplates();
    }
  }

  StoryTemplatesResponse _getFallbackTemplates() {
    debugPrint('🔄 Using fallback story templates');
    
    final fallbackTemplates = [
      StoryTemplate(
        id: 'fallback-1',
        title: 'Study Grove',
        emoji: '🌿',
        description: 'Tranquil forest with gentle streams, rustling leaves, and distant bird songs.',
        mood: 'Focused and clear',
        routine: 'Deep breathing and intention setting',
        category: 'focus',
        isFeatured: true,
        sampleStoryText: 'Once upon a time, in the heart of Study Grove, gentle streams carried whispers of ancient wisdom...',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      StoryTemplate(
        id: 'fallback-2',
        title: 'Family Hearth',
        emoji: '🔥',
        description: 'Warm living room with crackling fireplace, cozy blankets, and shared stories.',
        mood: 'Warm and connected',
        routine: 'Gathering together for storytime',
        category: 'family',
        isFeatured: true,
        sampleStoryText: 'Around the Family Hearth, golden flames danced with stories of love and togetherness...',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      StoryTemplate(
        id: 'fallback-3',
        title: 'Oceanic Serenity',
        emoji: '🌊',
        description: 'Peaceful beach at night with gentle waves and distant seagull calls.',
        mood: 'Peaceful and relaxed',
        routine: 'Listening to the rhythm of the ocean',
        category: 'unwind',
        isFeatured: true,
        sampleStoryText: 'As twilight painted the sky in soft pastels, Oceanic Serenity revealed its magic...',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final featured = fallbackTemplates.where((t) => t.isFeatured).toList();
    final categories = <String, List<StoryTemplate>>{};
    
    for (final template in fallbackTemplates) {
      categories.putIfAbsent(template.category, () => []).add(template);
    }

    return StoryTemplatesResponse(
      templates: fallbackTemplates,
      featured: featured,
      categories: categories,
    );
  }

  // Clear cache (useful for testing or when user manually refreshes)
  void clearCache() {
    _cachedTemplates = null;
    _lastFetchTime = null;
    debugPrint('🧹 Story templates cache cleared');
  }
}