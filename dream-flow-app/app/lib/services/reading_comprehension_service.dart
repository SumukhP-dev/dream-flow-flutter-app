import 'package:supabase_flutter/supabase_flutter.dart';

/// Comprehension question model
class ComprehensionQuestion {
  final String id;
  final String storyId;
  final String question;
  final List<String> options;
  final int correctAnswer; // Index of correct answer
  final String questionType;

  ComprehensionQuestion({
    required this.id,
    required this.storyId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.questionType = 'multiple_choice',
  });

  factory ComprehensionQuestion.fromJson(Map<String, dynamic> json) {
    return ComprehensionQuestion(
      id: json['id'] as String,
      storyId: json['story_id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correct_answer'] as int,
      questionType: json['question_type'] as String? ?? 'multiple_choice',
    );
  }
}

/// Service for reading comprehension questions
class ReadingComprehensionService {
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

  /// Get comprehension questions for a story
  Future<List<ComprehensionQuestion>> getQuestionsForStory(
    String storyId,
  ) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return [];
    try {
      final response = await supabase
          .from('comprehension_questions')
          .select('*')
          .eq('story_id', storyId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) =>
              ComprehensionQuestion.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Record answer to a question
  Future<void> recordAnswer({
    required String childProfileId,
    required String questionId,
    required int selectedAnswer,
    required bool isCorrect,
  }) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    try {
      // Store answer in learning_progress or a separate answers table
      // For now, just update learning progress
      await supabase.from('learning_progress').upsert({
        'child_profile_id': childProfileId,
        'metrics': {
          'last_question_id': questionId,
          'last_answer': selectedAnswer,
          'last_correct': isCorrect,
        },
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail
    }
  }
}

