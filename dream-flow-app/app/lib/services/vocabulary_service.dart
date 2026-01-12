import 'package:supabase_flutter/supabase_flutter.dart';

/// Vocabulary highlight model
class VocabularyHighlight {
  final String id;
  final String storyId;
  final String word;
  final String definition;
  final String? ageLevel;
  final String? contextSentence;

  VocabularyHighlight({
    required this.id,
    required this.storyId,
    required this.word,
    required this.definition,
    this.ageLevel,
    this.contextSentence,
  });

  factory VocabularyHighlight.fromJson(Map<String, dynamic> json) {
    return VocabularyHighlight(
      id: json['id'] as String,
      storyId: json['story_id'] as String,
      word: json['word'] as String,
      definition: json['definition'] as String,
      ageLevel: json['age_level'] as String?,
      contextSentence: json['context_sentence'] as String?,
    );
  }
}

/// Service for vocabulary highlights
class VocabularyService {
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

  /// Get vocabulary highlights for a story
  Future<List<VocabularyHighlight>> getHighlightsForStory(
    String storyId,
  ) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return [];
    try {
      final response = await supabase
          .from('vocabulary_highlights')
          .select('*')
          .eq('story_id', storyId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) =>
              VocabularyHighlight.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Mark word as learned
  Future<void> markWordLearned({
    required String childProfileId,
    required String word,
  }) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    try {
      // Update learning progress
      final progress = await supabase
          .from('learning_progress')
          .select('metrics')
          .eq('child_profile_id', childProfileId)
          .maybeSingle();

      final metrics = progress?['metrics'] as Map<String, dynamic>? ?? {};
      final learnedWords = List<String>.from(metrics['learned_words'] ?? []);

      if (!learnedWords.contains(word)) {
        learnedWords.add(word);
        metrics['learned_words'] = learnedWords;
        metrics['vocabulary_count'] = learnedWords.length;

        await supabase.from('learning_progress').upsert({
          'child_profile_id': childProfileId,
          'metrics': metrics,
          'new_vocabulary_count': learnedWords.length,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Get learned words for a child
  Future<List<String>> getLearnedWords(String childProfileId) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return [];
    try {
      final progress = await supabase
          .from('learning_progress')
          .select('metrics')
          .eq('child_profile_id', childProfileId)
          .maybeSingle();

      final metrics = progress?['metrics'] as Map<String, dynamic>? ?? {};
      return List<String>.from(metrics['learned_words'] ?? []);
    } catch (e) {
      return [];
    }
  }
}

