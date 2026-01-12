import 'package:supabase_flutter/supabase_flutter.dart';
import 'kid_engagement_service.dart';

/// Streak data model
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final Map<DateTime, bool> calendar; // Map of dates to activity status

  StreakData({
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
    Map<DateTime, bool>? calendar,
  }) : calendar = calendar ?? {};

  factory StreakData.fromJson(Map<String, dynamic> json) {
    final calendarData = json['calendar'] as Map<String, dynamic>? ?? {};
    final calendar = <DateTime, bool>{};
    calendarData.forEach((key, value) {
      calendar[DateTime.parse(key)] = value as bool;
    });

    return StreakData(
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
      calendar: calendar,
    );
  }

  Map<String, dynamic> toJson() => {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_activity_date': lastActivityDate?.toIso8601String(),
        'calendar': calendar.map((key, value) =>
            MapEntry(key.toIso8601String(), value)),
      };
}

/// Service for managing daily reading streaks
class StreakService {
  SupabaseClient? _supabase;
  final KidEngagementService _engagementService = KidEngagementService();

  SupabaseClient? _getSupabaseClient() {
    if (_supabase != null) return _supabase;
    try {
      _supabase = Supabase.instance.client;
      return _supabase;
    } catch (_) {
      return null;
    }
  }

  /// Record story activity and update streak
  Future<StreakData> recordActivity({
    required String childProfileId,
    DateTime? activityDate,
  }) async {
    final date = activityDate ?? DateTime.now();
    final today = DateTime(date.year, date.month, date.day);

    try {
      // Get current streak data
      final currentStreak = await getStreak(childProfileId);

      // Check if activity already recorded for today
      if (currentStreak.lastActivityDate != null) {
        final lastDate = DateTime(
          currentStreak.lastActivityDate!.year,
          currentStreak.lastActivityDate!.month,
          currentStreak.lastActivityDate!.day,
        );

        if (lastDate == today) {
          // Already recorded today, return current streak
          return currentStreak;
        }
      }

      // Calculate new streak
      int newStreak = 1;
      if (currentStreak.lastActivityDate != null) {
        final yesterday = today.subtract(const Duration(days: 1));
        final lastDate = DateTime(
          currentStreak.lastActivityDate!.year,
          currentStreak.lastActivityDate!.month,
          currentStreak.lastActivityDate!.day,
        );

        if (lastDate == yesterday) {
          // Consecutive day - increment streak
          newStreak = currentStreak.currentStreak + 1;
        }
        // If not consecutive, streak resets to 1
      }

      // Update longest streak if needed
      final longestStreak = newStreak > currentStreak.longestStreak
          ? newStreak
          : currentStreak.longestStreak;

      // Update calendar
      final updatedCalendar = Map<DateTime, bool>.from(currentStreak.calendar);
      updatedCalendar[today] = true;

      // Save to database
      final newStreakData = StreakData(
        currentStreak: newStreak,
        longestStreak: longestStreak,
        lastActivityDate: today,
        calendar: updatedCalendar,
      );

      await _saveStreak(childProfileId, newStreakData);

      return newStreakData;
    } catch (e) {
      // Return current streak on error
      return await getStreak(childProfileId);
    }
  }

  /// Get current streak for a child
  Future<StreakData> getStreak(String childProfileId) async {
    try {
      final streakData = await _engagementService.getStreak(childProfileId);
      if (streakData != null) {
        return StreakData.fromJson(streakData);
      }
    } catch (e) {
      // Fall through to default
    }

    // Return default streak data
    return StreakData(
      currentStreak: 0,
      longestStreak: 0,
    );
  }

  /// Get streak calendar for the last 30 days
  Future<Map<DateTime, bool>> getStreakCalendar(String childProfileId) async {
    try {
      final streak = await getStreak(childProfileId);
      final calendar = <DateTime, bool>{};

      // Get last 30 days
      final today = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        calendar[dateKey] = streak.calendar[dateKey] ?? false;
      }

      return calendar;
    } catch (e) {
      return {};
    }
  }

  /// Check if streak is at risk (missed yesterday)
  Future<bool> isStreakAtRisk(String childProfileId) async {
    try {
      final streak = await getStreak(childProfileId);
      if (streak.currentStreak == 0) {
        return false; // No streak to lose
      }

      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey = DateTime(yesterday.year, yesterday.month, yesterday.day);

      // Streak is at risk if yesterday had no activity but streak > 0
      return streak.calendar[yesterdayKey] != true && streak.currentStreak > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get streak milestone rewards
  List<Map<String, dynamic>> getStreakMilestones() {
    return [
      {'days': 3, 'title': 'Getting Started', 'emoji': '🌱', 'reward': 'New theme'},
      {'days': 7, 'title': 'Week Warrior', 'emoji': '🔥', 'reward': 'Character unlock'},
      {'days': 14, 'title': 'Two Week Champion', 'emoji': '⭐', 'reward': 'Special badge'},
      {'days': 30, 'title': 'Month Master', 'emoji': '👑', 'reward': 'Premium theme'},
      {'days': 60, 'title': 'Dedication Hero', 'emoji': '🏆', 'reward': 'Exclusive character'},
      {'days': 100, 'title': 'Century Streak', 'emoji': '💯', 'reward': 'Legendary badge'},
    ];
  }

  /// Get next milestone
  Map<String, dynamic>? getNextMilestone(int currentStreak) {
    final milestones = getStreakMilestones();
    for (final milestone in milestones) {
      final days = milestone['days'] as int;
      if (currentStreak < days) {
        return milestone;
      }
    }
    return null; // All milestones achieved
  }

  /// Save streak to database
  Future<void> _saveStreak(String childProfileId, StreakData streakData) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    try {
      // Get parent user ID from child profile
      final childProfile = await supabase
          .from('family_profiles')
          .select('parent_user_id')
          .eq('id', childProfileId)
          .maybeSingle();

      if (childProfile == null || childProfile['parent_user_id'] == null) {
        return; // Can't save without parent user
      }

      final parentUserId = childProfile['parent_user_id'] as String;

      // Upsert streak data
      await supabase.from('user_streaks').upsert({
        'user_id': parentUserId,
        'current_streak': streakData.currentStreak,
        'longest_streak': streakData.longestStreak,
        'last_activity_date': streakData.lastActivityDate?.toIso8601String(),
        'calendar': streakData.calendar.map((key, value) =>
            MapEntry(key.toIso8601String(), value)),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - streak tracking is non-critical
    }
  }
}

