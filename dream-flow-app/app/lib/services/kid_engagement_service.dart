import 'package:supabase_flutter/supabase_flutter.dart';

class KidEngagementService {
  SupabaseClient? _supabase;

  SupabaseClient? _getSupabaseClient() {
    if (_supabase != null) return _supabase;
    try {
      _supabase = Supabase.instance.client;
      return _supabase;
    } catch (_) {
      return null;
    }
  }

  /// Get all achievements for a child
  Future<List<Map<String, dynamic>>> getAchievements(String childProfileId) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return [];
    try {
      final response = await supabase
          .from('kid_achievements')
          .select('*')
          .eq('child_profile_id', childProfileId)
          .order('unlocked_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error loading achievements: $e');
    }
  }

  /// Add a story to child's collection
  Future<void> addToCollection({
    required String childProfileId,
    required String sessionId,
    bool isFavorite = false,
    String? collectionName,
  }) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    try {
      await supabase.from('story_collections').insert({
        'child_profile_id': childProfileId,
        'session_id': sessionId,
        'is_favorite': isFavorite,
        if (collectionName != null) 'collection_name': collectionName,
      });
    } catch (e) {
      throw Exception('Error adding to collection: $e');
    }
  }

  /// Get child's story collection
  Future<List<Map<String, dynamic>>> getStoryCollection(String childProfileId) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return [];
    try {
      final response = await supabase
          .from('story_collections')
          .select('*, sessions(*)')
          .eq('child_profile_id', childProfileId)
          .order('added_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error loading story collection: $e');
    }
  }

  /// Remove story from collection
  Future<void> removeFromCollection({
    required String childProfileId,
    required String sessionId,
  }) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    try {
      await supabase
          .from('story_collections')
          .delete()
          .eq('child_profile_id', childProfileId)
          .eq('session_id', sessionId);
    } catch (e) {
      throw Exception('Error removing from collection: $e');
    }
  }

  /// Get child's current streak (for visual display)
  Future<Map<String, dynamic>?> getStreak(String childProfileId) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return null;
    try {
      // Get streak from user_streaks table via parent user
      final childProfile = await supabase
          .from('family_profiles')
          .select('parent_user_id')
          .eq('id', childProfileId)
          .maybeSingle();

      if (childProfile == null || childProfile['parent_user_id'] == null) {
        return null;
      }

      final parentUserId = childProfile['parent_user_id'];
      final streak = await supabase
          .from('user_streaks')
          .select('*')
          .eq('user_id', parentUserId)
          .maybeSingle();

      return streak;
    } catch (e) {
      return null; // Return null if streak not found
    }
  }
}










































