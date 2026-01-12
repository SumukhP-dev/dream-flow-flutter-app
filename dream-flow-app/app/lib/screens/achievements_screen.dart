import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../widgets/achievement_badge_widget.dart';
import '../widgets/streak_widget.dart';
import '../services/streak_service.dart';

class AchievementsScreen extends StatefulWidget {
  final String? childProfileId;

  const AchievementsScreen({
    super.key,
    this.childProfileId,
  });

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _achievementService = AchievementService();
  final StreakService _streakService = StreakService();

  List<Achievement> _achievements = [];
  Map<AchievementType, double> _progress = {};
  StreakData? _streak;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.childProfileId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final achievements = await _achievementService.getAchievements(
        widget.childProfileId!,
      );
      final progress = await _achievementService.getAchievementProgress(
        widget.childProfileId!,
      );
      final streak = await _streakService.getStreak(widget.childProfileId!);

      setState(() {
        _achievements = achievements;
        _progress = progress;
        _streak = streak;
        _isLoading = false;
      });

      // Mark achievements as viewed
      await _achievementService.markAsViewed(widget.childProfileId!);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streak display
                    if (_streak != null) ...[
                      StreakWidget(
                        streak: _streak!,
                        showCalendar: true,
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Unlocked achievements section
                    const Text(
                      'Unlocked Achievements',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_achievements.isEmpty)
                      _buildEmptyState('No achievements unlocked yet!')
                    else
                      ..._achievements.map((achievement) {
                        return AchievementCardWidget(
                          achievement: achievement,
                        );
                      }),
                    const SizedBox(height: 32),
                    // Locked achievements section
                    const Text(
                      'Locked Achievements',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLockedAchievements(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '🌟',
            style: TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLockedAchievements() {
    final unlockedTypes = _achievements.map((a) => a.type).toSet();
    final lockedTypes = AchievementType.values
        .where((type) => !unlockedTypes.contains(type))
        .toList();

    if (lockedTypes.isEmpty) {
      return _buildEmptyState('All achievements unlocked! 🎉');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: lockedTypes.length,
      itemBuilder: (context, index) {
        final type = lockedTypes[index];
        final progress = _progress[type] ?? 0.0;

        return Column(
          children: [
            LockedAchievementWidget(
              type: type,
              progress: progress,
              size: 80,
            ),
            const SizedBox(height: 8),
            Text(
              type.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

