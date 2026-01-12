import 'package:supabase_flutter/supabase_flutter.dart';
import 'kid_engagement_service.dart';
import 'vocabulary_service.dart';

/// Achievement types that can be unlocked
enum AchievementType {
  firstStory('first_story', 'First Story', '🌟', 'Complete your first story!'),
  tenStories('ten_stories', 'Story Explorer', '📚', 'Complete 10 stories'),
  fiftyStories('fifty_stories', 'Story Master', '👑', 'Complete 50 stories'),
  hundredStories('hundred_stories', 'Story Legend', '🏆', 'Complete 100 stories'),
  allThemes('all_themes', 'World Explorer', '🌍', 'Explore all story themes'),
  dailyStreak7('streak_7', 'Week Warrior', '🔥', '7 day reading streak'),
  dailyStreak30('streak_30', 'Month Master', '⭐', '30 day reading streak'),
  vocabularyMaster('vocabulary_master', 'Word Wizard', '📖', 'Learn 50 new words'),
  comprehensionChampion('comprehension_champion', 'Thinker', '🧠', 'Answer 100 questions correctly');

  final String id;
  final String title;
  final String emoji;
  final String description;

  const AchievementType(this.id, this.title, this.emoji, this.description);
}

/// Achievement unlock condition
class AchievementCondition {
  final AchievementType type;
  final Map<String, dynamic> conditionData; // e.g., {'count': 10} for tenStories

  AchievementCondition({
    required this.type,
    required this.conditionData,
  });
}

/// Achievement model
class Achievement {
  final String id;
  final AchievementType type;
  final String childProfileId;
  final DateTime unlockedAt;
  final bool isNew; // For showing notification

  Achievement({
    required this.id,
    required this.type,
    required this.childProfileId,
    required this.unlockedAt,
    this.isNew = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    final typeId = json['achievement_type'] as String;
    final type = AchievementType.values.firstWhere(
      (t) => t.id == typeId,
      orElse: () => AchievementType.firstStory,
    );

    return Achievement(
      id: json['id'] as String,
      type: type,
      childProfileId: json['child_profile_id'] as String,
      unlockedAt: DateTime.parse(json['unlocked_at'] as String),
      isNew: json['is_new'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'achievement_type': type.id,
        'child_profile_id': childProfileId,
        'unlocked_at': unlockedAt.toIso8601String(),
        'is_new': isNew,
      };
}

/// Service for managing achievements and badges
class AchievementService {
  SupabaseClient? _supabase;
  final KidEngagementService _engagementService = KidEngagementService();
  final VocabularyService _vocabularyService = VocabularyService();

  SupabaseClient? _getSupabaseClient() {
    if (_supabase != null) return _supabase;
    try {
      _supabase = Supabase.instance.client;
      return _supabase;
    } catch (_) {
      return null;
    }
  }
  /// Check and unlock achievements based on user activity
  Future<List<Achievement>> checkAndUnlockAchievements({
    required String childProfileId,
    required String eventType, // 'story_completed', 'theme_explored', etc.
    Map<String, dynamic>? eventData, // Additional data about the event
  }) async {
    final newlyUnlocked = <Achievement>[];

    try {
      // Get current achievements
      final currentAchievements = await _engagementService.getAchievements(childProfileId);
      final unlockedTypes = currentAchievements
          .map((a) => a['achievement_type'] as String)
          .toSet();

      // Get user stats for condition checking
      final stats = await getUserStats(childProfileId);

      // Check each achievement type
      for (final achievementType in AchievementType.values) {
        // Skip if already unlocked
        if (unlockedTypes.contains(achievementType.id)) {
          continue;
        }

        // Check if condition is met
        if (await _checkAchievementCondition(
          achievementType,
          eventType,
          eventData,
          stats,
        )) {
          // Unlock achievement
          final achievement = await _unlockAchievement(
            childProfileId: childProfileId,
            type: achievementType,
          );
          if (achievement != null) {
            newlyUnlocked.add(achievement);
          }
        }
      }

      return newlyUnlocked;
    } catch (e) {
      // Silently fail - achievements are non-critical
      return [];
    }
  }

  /// Get all achievements for a child
  Future<List<Achievement>> getAchievements(String childProfileId) async {
    try {
      final achievements = await _engagementService.getAchievements(childProfileId);
      return achievements.map((a) => Achievement.fromJson(a)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get achievement progress (for achievements not yet unlocked)
  Future<Map<AchievementType, double>> getAchievementProgress(
    String childProfileId,
  ) async {
    final progress = <AchievementType, double>{};

    try {
      final stats = await getUserStats(childProfileId);
      final currentAchievements = await getAchievements(childProfileId);
      final unlockedTypes = currentAchievements.map((a) => a.type).toSet();

      for (final type in AchievementType.values) {
        if (unlockedTypes.contains(type)) {
          progress[type] = 1.0; // Already unlocked
        } else {
          progress[type] = _calculateProgress(type, stats);
        }
      }
    } catch (e) {
      // Return empty progress on error
    }

    return progress;
  }

  /// Mark achievements as viewed (no longer "new")
  Future<void> markAsViewed(String childProfileId) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    try {
      await supabase
          .from('kid_achievements')
          .update({'is_new': false})
          .eq('child_profile_id', childProfileId)
          .eq('is_new', true);
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if achievement condition is met
  Future<bool> _checkAchievementCondition(
    AchievementType type,
    String eventType,
    Map<String, dynamic>? eventData,
    Map<String, dynamic> stats,
  ) async {
    switch (type) {
      case AchievementType.firstStory:
        return stats['stories_completed'] as int >= 1;

      case AchievementType.tenStories:
        return stats['stories_completed'] as int >= 10;

      case AchievementType.fiftyStories:
        return stats['stories_completed'] as int >= 50;

      case AchievementType.hundredStories:
        return stats['stories_completed'] as int >= 100;

      case AchievementType.allThemes:
        final themesExplored = stats['themes_explored'] as Set<String>;
        // Check if all available themes are explored
        return themesExplored.length >= 10; // Assuming 10 themes

      case AchievementType.dailyStreak7:
        return stats['current_streak'] as int >= 7;

      case AchievementType.dailyStreak30:
        return stats['current_streak'] as int >= 30;

      case AchievementType.vocabularyMaster:
        return stats['vocabulary_words_learned'] as int >= 50;

      case AchievementType.comprehensionChampion:
        return stats['questions_answered_correctly'] as int >= 100;

    }
  }

  /// Calculate progress percentage for an achievement
  double _calculateProgress(AchievementType type, Map<String, dynamic> stats) {
    switch (type) {
      case AchievementType.firstStory:
        return (stats['stories_completed'] as int).clamp(0, 1).toDouble();

      case AchievementType.tenStories:
        return ((stats['stories_completed'] as int) / 10).clamp(0.0, 1.0);

      case AchievementType.fiftyStories:
        return ((stats['stories_completed'] as int) / 50).clamp(0.0, 1.0);

      case AchievementType.hundredStories:
        return ((stats['stories_completed'] as int) / 100).clamp(0.0, 1.0);

      case AchievementType.allThemes:
        final themesExplored = stats['themes_explored'] as Set<String>;
        return (themesExplored.length / 10).clamp(0.0, 1.0);

      case AchievementType.dailyStreak7:
        return ((stats['current_streak'] as int) / 7).clamp(0.0, 1.0);

      case AchievementType.dailyStreak30:
        return ((stats['current_streak'] as int) / 30).clamp(0.0, 1.0);

      case AchievementType.vocabularyMaster:
        return ((stats['vocabulary_words_learned'] as int) / 50).clamp(0.0, 1.0);

      case AchievementType.comprehensionChampion:
        return ((stats['questions_answered_correctly'] as int) / 100).clamp(0.0, 1.0);
    }
  }

  /// Unlock an achievement
  Future<Achievement?> _unlockAchievement({
    required String childProfileId,
    required AchievementType type,
  }) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return null;
    try {
      final response = await supabase.from('kid_achievements').insert({
        'child_profile_id': childProfileId,
        'achievement_type': type.id,
        'unlocked_at': DateTime.now().toIso8601String(),
        'is_new': true,
      }).select().single();

      return Achievement.fromJson(response);
    } catch (e) {
      // Achievement might already exist, try to get it
      try {
        final existing = await supabase
            .from('kid_achievements')
            .select()
            .eq('child_profile_id', childProfileId)
            .eq('achievement_type', type.id)
            .maybeSingle();

        if (existing != null) {
          return Achievement.fromJson(existing);
        }
      } catch (_) {
        // Ignore
      }
      return null;
    }
  }

  /// Get user statistics for achievement checking
  Future<Map<String, dynamic>> getUserStats(String childProfileId) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) {
      return {
        'stories_completed': 0,
        'themes_explored': <String>{},
        'current_streak': 0,
        'vocabulary_words_learned': 0,
        'questions_answered_correctly': 0,
      };
    }
    try {
      // Get story completion count
      final sessions = await supabase
          .from('sessions')
          .select('theme, created_at')
          .eq('child_profile_id', childProfileId);

      final storiesCompleted = sessions.length;
      final themesExplored = sessions
          .map((s) => s['theme'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toSet();

      // Get streak (from KidEngagementService)
      final streakData = await _engagementService.getStreak(childProfileId);
      final currentStreak = streakData?['current_streak'] as int? ?? 0;

      // Get vocabulary words learned
      int vocabularyWordsLearned = 0;
      try {
        final learnedWords = await _vocabularyService.getLearnedWords(childProfileId);
        vocabularyWordsLearned = learnedWords.length;
      } catch (e) {
        // Fallback: try reading_progress table
        try {
          final progress = await supabase
              .from('reading_progress')
              .select('vocabulary_words_learned')
              .eq('child_profile_id', childProfileId)
              .maybeSingle();
          vocabularyWordsLearned = progress?['vocabulary_words_learned'] as int? ?? 0;
        } catch (_) {
          vocabularyWordsLearned = 0;
        }
      }

      // Get comprehension questions answered correctly
      int questionsAnsweredCorrectly = 0;
      try {
        // Get all stories for this child
        final childStories = await supabase
            .from('sessions')
            .select('id')
            .eq('child_profile_id', childProfileId);
        
        if (childStories.isNotEmpty) {
          // Count correct answers from learning_progress
          final progress = await supabase
              .from('learning_progress')
              .select('metrics')
              .eq('child_profile_id', childProfileId)
              .maybeSingle();
          
          final metrics = progress?['metrics'] as Map<String, dynamic>? ?? {};
          final correctAnswers = metrics['correct_answers_count'] as int? ?? 0;
          
          // If not in metrics, try to count from reading_progress
          if (correctAnswers == 0) {
            final readingProgress = await supabase
                .from('reading_progress')
                .select('questions_answered_correctly')
                .eq('child_profile_id', childProfileId)
                .maybeSingle();
            questionsAnsweredCorrectly = readingProgress?['questions_answered_correctly'] as int? ?? 0;
          } else {
            questionsAnsweredCorrectly = correctAnswers;
          }
        }
      } catch (e) {
        // Fallback: try reading_progress table
        try {
          final progress = await supabase
              .from('reading_progress')
              .select('questions_answered_correctly')
              .eq('child_profile_id', childProfileId)
              .maybeSingle();
          questionsAnsweredCorrectly = progress?['questions_answered_correctly'] as int? ?? 0;
        } catch (_) {
          questionsAnsweredCorrectly = 0;
        }
      }

      return {
        'stories_completed': storiesCompleted,
        'themes_explored': themesExplored,
        'current_streak': currentStreak,
        'vocabulary_words_learned': vocabularyWordsLearned,
        'questions_answered_correctly': questionsAnsweredCorrectly,
      };
    } catch (e) {
      // Return default stats on error
      return {
        'stories_completed': 0,
        'themes_explored': <String>{},
        'current_streak': 0,
        'vocabulary_words_learned': 0,
        'questions_answered_correctly': 0,
      };
    }
  }
}

