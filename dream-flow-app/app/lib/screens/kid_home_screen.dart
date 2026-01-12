import 'package:flutter/material.dart';
import '../services/parental_control_service.dart';
import '../shared/accessibility_service.dart';
import '../services/streak_service.dart';
import '../services/achievement_service.dart';
import '../widgets/streak_widget.dart';
import '../widgets/achievement_badge_widget.dart';
import 'kid_create_story_screen.dart';
import 'my_stories_screen.dart';
import 'kid_story_discovery_screen.dart';
import 'achievements_screen.dart';
import 'family_library_screen.dart';

class KidHomeScreen extends StatefulWidget {
  final String? childProfileId;
  final String? childName;

  const KidHomeScreen({
    super.key,
    this.childProfileId,
    this.childName,
  });

  @override
  State<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends State<KidHomeScreen>
    with SingleTickerProviderStateMixin {
  final ParentalControlService _parentalControlService =
      ParentalControlService();
  final AccessibilityService _accessibilityService = AccessibilityService();
  final StreakService _streakService = StreakService();
  final AchievementService _achievementService = AchievementService();
  Map<String, dynamic>? _childProfile;
  bool _isLoading = true;
  StreakData? _streak;
  List<Achievement> _recentAchievements = [];
  late AnimationController _animationController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create staggered animations for the five cards
    _fadeAnimations = List.generate(
      5,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.2,
            0.6 + (index * 0.2),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );

    _slideAnimations = List.generate(
      5,
      (index) => Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.2,
            0.6 + (index * 0.2),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );

    _loadChildProfile();
    _loadStreakAndAchievements();
    _animationController.forward();
    _applyDefaultAccessibility();
  }

  Future<void> _applyDefaultAccessibility() async {
    // Apply default accessibility settings for kids
    try {
      await _accessibilityService.setFontScale(1.2); // 20% larger for kids
    } catch (e) {
      // Silently fail - accessibility is optional
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String? _getAgeRating(int age) {
    if (age <= 5) return 'G';
    if (age <= 8) return 'PG';
    if (age <= 12) return 'PG-13';
    return null;
  }

  Future<void> _loadChildProfile() async {
    if (widget.childProfileId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final profiles = await _parentalControlService.getChildProfiles();
      final profile = profiles.firstWhere(
        (p) => p['id'] == widget.childProfileId,
        orElse: () => <String, dynamic>{},
      );

      setState(() {
        _childProfile = profile.isNotEmpty ? profile : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStreakAndAchievements() async {
    if (widget.childProfileId == null) return;

    try {
      final streak = await _streakService.getStreak(widget.childProfileId!);
      final achievements = await _achievementService.getAchievements(
        widget.childProfileId!,
      );
      // Get recent achievements (last 3)
      final recent = achievements.take(3).toList();

      setState(() {
        _streak = streak;
        _recentAchievements = recent;
      });
    } catch (e) {
      // Silently fail
    }
  }

  String get _displayName {
    if (widget.childName != null && widget.childName!.isNotEmpty) {
      return widget.childName!;
    }
    if (_childProfile != null && _childProfile!['child_name'] != null) {
      return _childProfile!['child_name'] as String;
    }
    return 'Friend';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF8B5CF6),
              const Color(0xFF06B6D4),
              const Color(0xFFEC4899),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      // Streak and achievements display
                      if (_streak != null || _recentAchievements.isNotEmpty)
                        _buildStreakAndAchievementsSection(),
                      const SizedBox(height: 24),
                      _buildActionCard(
                        index: 0,
                        title: 'Create New Story',
                        emoji: '✨',
                        description: 'Make your own magical story!',
                        color: const Color(0xFFFF6B6B),
                        onTap: () {
                          final childAge = _childProfile?['age'] as int?;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KidCreateStoryScreen(
                                childProfileId: widget.childProfileId,
                                childAge: childAge,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildActionCard(
                        index: 1,
                        title: 'My Stories',
                        emoji: '📚',
                        description: 'See all your stories',
                        color: const Color(0xFF4ECDC4),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const MyStoriesScreen(isKidMode: true),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildActionCard(
                        index: 2,
                        title: 'Stories by Others',
                        emoji: '🌍',
                        description: 'Discover stories from friends',
                        color: const Color(0xFFFFD93D),
                        onTap: () {
                          // Pass child age for filtering if available
                          final childAge = _childProfile?['age'] as int?;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KidStoryDiscoveryScreen(
                                initialAgeRating: childAge != null
                                    ? _getAgeRating(childAge)
                                    : null,
                                childAge: childAge,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildActionCard(
                        index: 3,
                        title: 'Family Stories',
                        emoji: '👨‍👩‍👧‍👦',
                        description: 'Stories shared by family',
                        color: const Color(0xFF9B59B6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FamilyLibraryScreen(
                                childProfileId: widget.childProfileId,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildActionCard(
                        index: 4,
                        title: 'Achievements',
                        emoji: '🏆',
                        description: 'View your badges and progress',
                        color: const Color(0xFFFFB84D),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AchievementsScreen(
                                childProfileId: widget.childProfileId,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dream Flow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Hi, $_displayName! 👋',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required int index,
    required String title,
    required String emoji,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakAndAchievementsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak display
          if (_streak != null && _streak!.currentStreak > 0)
            CompactStreakWidget(streak: _streak!),
          if (_streak != null && _streak!.currentStreak > 0)
            const SizedBox(height: 16),
          // Recent achievements
          if (_recentAchievements.isNotEmpty) ...[
            const Text(
              'Recent Achievements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _recentAchievements
                  .map((achievement) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: AchievementBadgeWidget(
                          achievement: achievement,
                          size: 60,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
