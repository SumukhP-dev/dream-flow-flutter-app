import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/story_service.dart';

/// Service for managing family story library
class FamilyLibraryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StoryService _storyService = StoryService();

  /// Get family ID from parent user ID
  Future<String?> _getFamilyId(String parentUserId) async {
    try {
      // Family ID can be the parent user ID or a separate family grouping
      // For simplicity, using parent user ID as family ID
      return parentUserId;
    } catch (e) {
      return null;
    }
  }

  /// Share a story with family
  Future<void> shareStoryWithFamily({
    required String parentUserId,
    required String sessionId,
  }) async {
    try {
      final familyId = await _getFamilyId(parentUserId);
      if (familyId == null) throw Exception('Could not determine family ID');

      await _supabase.from('family_libraries').insert({
        'family_id': familyId,
        'story_id': sessionId,
        'shared_by': parentUserId,
        'shared_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to share story: $e');
    }
  }

  /// Get all stories in family library
  Future<List<StoryExperience>> getFamilyStories({
    required String parentUserId,
    String? childProfileId,
  }) async {
    try {
      final familyId = await _getFamilyId(parentUserId);
      if (familyId == null) return [];

      final response = await _supabase
          .from('family_libraries')
          .select('story_id, shared_by, shared_at')
          .eq('family_id', familyId)
          .order('shared_at', ascending: false);

      final storyIds = (response as List)
          .map((item) => item['story_id'] as String)
          .toList();

      // Fetch story details
      final stories = <StoryExperience>[];
      for (final storyId in storyIds) {
        try {
          final story = await _storyService.getStoryById(storyId);
          if (story != null) {
            stories.add(story);
          }
        } catch (e) {
          // Skip stories that can't be loaded
        }
      }

      return stories;
    } catch (e) {
      return [];
    }
  }

  /// Remove story from family library
  Future<void> removeFromFamilyLibrary({
    required String parentUserId,
    required String sessionId,
  }) async {
    try {
      final familyId = await _getFamilyId(parentUserId);
      if (familyId == null) throw Exception('Could not determine family ID');

      await _supabase
          .from('family_libraries')
          .delete()
          .eq('family_id', familyId)
          .eq('story_id', sessionId);
    } catch (e) {
      throw Exception('Failed to remove story: $e');
    }
  }

  /// Check if story is in family library
  Future<bool> isInFamilyLibrary({
    required String parentUserId,
    required String sessionId,
  }) async {
    try {
      final familyId = await _getFamilyId(parentUserId);
      if (familyId == null) return false;

      final response = await _supabase
          .from('family_libraries')
          .select('id')
          .eq('family_id', familyId)
          .eq('story_id', sessionId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }
}

