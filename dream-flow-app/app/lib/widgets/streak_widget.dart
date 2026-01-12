import 'package:flutter/material.dart';
import '../services/streak_service.dart';

/// Widget to display daily reading streak
class StreakWidget extends StatelessWidget {
  final StreakData streak;
  final bool showCalendar;
  final VoidCallback? onTap;

  const StreakWidget({
    super.key,
    required this.streak,
    this.showCalendar = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade400,
              Colors.red.shade400,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak header
            Row(
              children: [
                const Text(
                  '🔥',
                  style: TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${streak.currentStreak}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        streak.currentStreak == 1 ? 'Day Streak' : 'Day Streak',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Longest streak badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${streak.longestStreak}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Best',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showCalendar) ...[
              const SizedBox(height: 16),
              _buildStreakCalendar(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCalendar(BuildContext context) {
    final today = DateTime.now();
    final calendarDays = <DateTime>[];

    // Get last 7 days
    for (int i = 6; i >= 0; i--) {
      calendarDays.add(today.subtract(Duration(days: i)));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: calendarDays.map((date) {
        final dateKey = DateTime(date.year, date.month, date.day);
        final hasActivity = streak.calendar[dateKey] ?? false;
        final isToday = dateKey == DateTime(today.year, today.month, today.day);

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasActivity
                ? Colors.white
                : Colors.white.withValues(alpha: 0.2),
            border: isToday ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: hasActivity
                    ? Colors.orange.shade700
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Compact streak display for headers
class CompactStreakWidget extends StatelessWidget {
  final StreakData streak;

  const CompactStreakWidget({
    super.key,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            '${streak.currentStreak}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak milestone widget showing progress to next milestone
class StreakMilestoneWidget extends StatelessWidget {
  final StreakData streak;
  final Map<String, dynamic>? nextMilestone;

  const StreakMilestoneWidget({
    super.key,
    required this.streak,
    this.nextMilestone,
  });

  @override
  Widget build(BuildContext context) {
    if (nextMilestone == null) {
      return const SizedBox.shrink();
    }

    final milestoneDays = nextMilestone!['days'] as int;
    final progress = (streak.currentStreak / milestoneDays).clamp(0.0, 1.0);
    final daysRemaining =
        (milestoneDays - streak.currentStreak).clamp(0, milestoneDays);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                nextMilestone!['emoji'] as String,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextMilestone!['title'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      '$daysRemaining days to go',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.blue.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.blue.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reward: ${nextMilestone!['reward']}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
