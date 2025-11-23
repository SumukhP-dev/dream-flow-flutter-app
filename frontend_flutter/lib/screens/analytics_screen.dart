import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/story_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final StoryService _storyService = StoryService();
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get session history
      final history = await _storyService.getHistory(userId: user.id);

      // Calculate analytics
      final totalStories = history.length;
      final thisWeek = _getStoriesThisWeek(history);
      final thisMonth = _getStoriesThisMonth(history);
      final favoriteThemes = _getFavoriteThemes(history);
      final averageLength = _getAverageStoryLength(history);
      final streak = _calculateStreak(history);

      setState(() {
        _analytics = {
          'totalStories': totalStories,
          'thisWeek': thisWeek,
          'thisMonth': thisMonth,
          'favoriteThemes': favoriteThemes,
          'averageLength': averageLength,
          'streak': streak,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _getStoriesThisWeek(List<SessionHistoryItem> sessions) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return sessions.where((s) {
      final created = DateTime.parse(s.createdAt);
      return created.isAfter(weekStart);
    }).length;
  }

  int _getStoriesThisMonth(List<SessionHistoryItem> sessions) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return sessions.where((s) {
      final created = DateTime.parse(s.createdAt);
      return created.isAfter(monthStart);
    }).length;
  }

  Map<String, int> _getFavoriteThemes(List<SessionHistoryItem> sessions) {
    final themeCounts = <String, int>{};
    for (final session in sessions) {
      themeCounts[session.theme] = (themeCounts[session.theme] ?? 0) + 1;
    }
    return themeCounts;
  }

  int _getAverageStoryLength(List<SessionHistoryItem> sessions) {
    // SessionHistoryItem doesn't have story_text, so we'll use prompt length as approximation
    if (sessions.isEmpty) return 0;
    final total = sessions.fold<int>(
      0,
      (sum, session) => sum + (session.prompt.length),
    );
    return total ~/ sessions.length;
  }

  int _calculateStreak(List<SessionHistoryItem> sessions) {
    if (sessions.isEmpty) return 0;

    // Sort by date descending
    final sorted = List<SessionHistoryItem>.from(sessions)
      ..sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

    int streak = 0;
    DateTime? lastDate;

    for (final session in sorted) {
      final created = DateTime.parse(session.createdAt);
      final storyDate = DateTime(
        created.year,
        created.month,
        created.day,
      );

      if (lastDate == null) {
        // First story - check if it's today or yesterday
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final yesterdayDate = todayDate.subtract(const Duration(days: 1));

        if (storyDate == todayDate || storyDate == yesterdayDate) {
          streak = 1;
          lastDate = storyDate;
        } else {
          break;
        }
      } else {
        // Check if this story is the day before the last one
        final expectedDate = lastDate.subtract(const Duration(days: 1));
        if (storyDate == expectedDate || storyDate == lastDate) {
          if (storyDate == expectedDate) {
            streak++;
          }
          lastDate = storyDate;
        } else {
          break;
        }
      }
    }

    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Progress'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('No analytics available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatCard(
                        title: 'Total Stories',
                        value: '${_analytics!['totalStories']}',
                        icon: Icons.auto_stories,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'This Week',
                              value: '${_analytics!['thisWeek']}',
                              icon: Icons.calendar_today,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              title: 'This Month',
                              value: '${_analytics!['thisMonth']}',
                              icon: Icons.calendar_month,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        title: 'Current Streak',
                        value: '${_analytics!['streak']} days',
                        icon: Icons.local_fire_department,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Favorite Themes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...((_analytics!['favoriteThemes'] as Map<String, int>)
                          .entries
                          .toList()
                          ..sort((a, b) => b.value.compareTo(a.value))
                          ..take(5))
                          .map((entry) => Card(
                                child: ListTile(
                                  title: Text(entry.key),
                                  trailing: Text(
                                    '${entry.value}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

