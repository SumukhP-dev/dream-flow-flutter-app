import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/story_service.dart';
import '../services/reflection_service.dart';
import '../shared/story_card_service.dart';
import '../widgets/reflection_capture_sheet.dart';
import '../widgets/reflections_timeline.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final StoryService _storyService = StoryService();
  final StoryCardService _storyCardService = StoryCardService();
  final ReflectionService _reflectionService = ReflectionService();
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;
  bool _isSharingStreak = false;
  ReflectionInsights? _reflectionInsights;
  bool _isLoggingReflection = false;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final reflectionsFuture = _reflectionService.getInsights();
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        final reflections = await reflectionsFuture;
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _reflectionInsights = reflections;
          _analytics = null;
        });
        return;
      }

      // Get session history
      final history = await _storyService.getHistory(userId: user.id);
      final reflections = await reflectionsFuture;

      // Calculate analytics
      final totalStories = history.length;
      final thisWeek = _getStoriesThisWeek(history);
      final thisMonth = _getStoriesThisMonth(history);
      final favoriteThemes = _getFavoriteThemes(history);
      final averageLength = _getAverageStoryLength(history);
      final streak = _calculateStreak(history);

      if (!mounted) return;
      setState(() {
        _analytics = {
          'totalStories': totalStories,
          'thisWeek': thisWeek,
          'thisMonth': thisMonth,
          'favoriteThemes': favoriteThemes,
          'averageLength': averageLength,
          'streak': streak,
        };
        _reflectionInsights = reflections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      ..sort(
        (a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)),
      );

    int streak = 0;
    DateTime? lastDate;

    for (final session in sorted) {
      final created = DateTime.parse(session.createdAt);
      final storyDate = DateTime(created.year, created.month, created.day);

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
                  _buildStreakCard(
                    streak: _analytics!['streak'] as int,
                    onShare: _shareStreak,
                    isSharing: _isSharingStreak,
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
                      .map(
                        (entry) => Card(
                          child: ListTile(
                            title: Text(entry.key),
                            trailing: Text(
                              '${entry.value}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                  if (_reflectionInsights != null) ...[
                    const SizedBox(height: 32),
                    _buildReflectionSection(),
                  ],
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
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard({
    required int streak,
    required VoidCallback onShare,
    required bool isSharing,
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
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 32,
                ),
                Text(
                  '$streak days',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Current Streak',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (streak > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSharing ? null : onShare,
                  icon: isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share),
                  label: Text(isSharing ? 'Sharing...' : 'Share Achievement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _shareStreak() async {
    final streak = _analytics!['streak'] as int;
    if (streak == 0) return;

    setState(() => _isSharingStreak = true);

    try {
      // Generate streak card image
      final streakCard = await _storyCardService.generateStreakCard(
        streakDays: streak,
        context: context,
      );

      // Share the card with text
      String shareText =
          '🔥 I\'ve maintained a $streak-day streak on Dream Flow! '
          'Join me in creating peaceful bedtime stories. '
          'Download Dream Flow and start your own journey!';

      await Share.shareXFiles(
        [XFile(streakCard.path, mimeType: 'image/png')],
        text: shareText,
        subject: '$streak-Day Streak on Dream Flow!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share streak: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingStreak = false);
      }
    }
  }

  Widget _buildReflectionSection() {
    final insights = _reflectionInsights!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Narrative reflections',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton.icon(
              onPressed: _isLoggingReflection
                  ? null
                  : () => _openReflectionComposer(),
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(
                _isLoggingReflection ? 'Logging...' : 'Add reflection',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ReflectionsTimelineWidget(insights: insights),
        const SizedBox(height: 16),
        _buildWeeklyClusters(insights.weeklyClusters),
        const SizedBox(height: 16),
        _buildRecommendations(insights.recommendations),
        const SizedBox(height: 16),
        _buildCelebrations(insights),
      ],
    );
  }

  Widget _buildWeeklyClusters(List<ReflectionWeekCluster> clusters) {
    if (clusters.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Log at least two reflections to unlock weekly clustering and trend highlights.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly clusters', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: clusters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cluster = clusters[index];
              final weekLabel =
                  'Week of ${cluster.weekStart.month}/${cluster.weekStart.day}';
              final topTopic = cluster.topTopics.isEmpty
                  ? 'New motifs pending'
                  : cluster.topTopics.first;
              return Container(
                width: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.deepPurple.shade100),
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.withValues(alpha: 0.15),
                      Colors.deepPurpleAccent.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${cluster.dominantMood.emoji} ${cluster.dominantMood.label}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Motif: $topTopic',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      cluster.recommendation,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(List<ReflectionRecommendation> recommendations) {
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...recommendations.map(
              (rec) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_iconForRecommendation(rec.type)),
                title: Text(rec.title),
                subtitle: Text(rec.detail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrations(ReflectionInsights insights) {
    final recap = insights.celebrations.weeklyRecap;
    final badges = insights.celebrations.badges;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Celebrations & recap',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges.isEmpty
                  ? [
                      Chip(
                        label: const Text('Log 3 reflections to unlock badges'),
                        avatar: const Icon(Icons.emoji_events_outlined),
                      ),
                    ]
                  : badges
                        .map(
                          (badge) => Chip(
                            avatar: const Icon(Icons.emoji_events, size: 16),
                            label: Text(badge.label),
                          ),
                        )
                        .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _recapStat(
                  '${recap.entriesLogged}',
                  'entries logged this week',
                ),
                _recapStat('${recap.audioNotes}', 'voice notes'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recap.newTopics.isEmpty
                  ? 'New motifs will appear after your next reflection.'
                  : 'Fresh motifs: ${recap.newTopics.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForRecommendation(String type) {
    switch (type) {
      case 'ritual':
        return Icons.self_improvement_outlined;
      case 'journaling':
        return Icons.mic_none_outlined;
      case 'story_seed':
        return Icons.psychology_alt_outlined;
      case 'celebration':
        return Icons.celebration_outlined;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  Widget _recapStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  Future<void> _openReflectionComposer({String? seedPrompt}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReflectionCaptureSheet(
          initialPrompt: seedPrompt,
          onSubmitted: (mood, note, audioPath) =>
              _handleReflectionSubmit(mood, note, audioPath),
        ),
      ),
    );
  }

  Future<void> _handleReflectionSubmit(
    ReflectionMood mood,
    String? note,
    String? audioPath,
  ) async {
    setState(() => _isLoggingReflection = true);
    try {
      await _reflectionService.submitReflection(
        mood: mood,
        note: note,
        audioPath: audioPath,
      );
      final refreshed = await _reflectionService.getInsights();
      if (!mounted) return;
      setState(() => _reflectionInsights = refreshed);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reflection saved and insights updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save reflection: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingReflection = false);
      }
    }
  }
}
