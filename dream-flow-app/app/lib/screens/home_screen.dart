import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/story_service.dart'
    show StoryService, SessionHistoryItem, StoryExperience;
import '../core/auth_service.dart';
import '../shared/preferences_service.dart';
import '../services/feature_flag_service.dart';
import '../services/travel_service.dart';
import '../services/ad_service.dart';
import '../widgets/reflection_insights_widget.dart';
import 'maestro_dashboard_screen.dart';
import 'smart_scene_screen.dart';
import 'calm_quests_screen.dart';
import 'create_story_screen.dart';
import 'my_stories_screen.dart';
import 'story_discovery_screen.dart';
import 'session_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'reflections_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StoryService _storyService = StoryService();
  final PreferencesService _preferencesService = PreferencesService();
  final FeatureFlagService _flagService = FeatureFlagService();
  final TravelService _travelService = TravelService();
  final AuthService _authService = AuthService();
  final AdService _adService = AdService();
  static const double _featuredWorldHeight = 210;

  // Ad state
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;
  bool _isPremium = true; // Default to true to hide ads until confirmed

  // All available themes organized by category
  final List<Map<String, String>> _allThemes = [
    // Calm Focus themes
    {
      'title': 'Study Grove',
      'emoji': '🌿',
      'description':
          'Tranquil forest with gentle streams, rustling leaves, and distant bird songs.',
      'mood': 'Focused and clear',
      'routine': 'Deep breathing and intention setting',
      'category': 'focus',
    },
    {
      'title': 'Focus Falls',
      'emoji': '💧',
      'description':
          'Cascading waterfall with rhythmic sounds in a secluded, peaceful setting.',
      'mood': 'Centered and attentive',
      'routine': 'Mindful listening and concentration',
      'category': 'focus',
    },
    {
      'title': 'Zen Garden',
      'emoji': '🪨',
      'description':
          'Minimalist Japanese garden with raked sand patterns and soft wind chimes.',
      'mood': 'Calm and present',
      'routine': 'Meditation and quiet reflection',
      'category': 'focus',
    },
    // Cozy Family themes
    {
      'title': 'Family Hearth',
      'emoji': '🔥',
      'description':
          'Warm living room with crackling fireplace, cozy blankets, and shared stories.',
      'mood': 'Warm and connected',
      'routine': 'Gathering together for storytime',
      'category': 'family',
    },
    {
      'title': 'Campfire Chronicles',
      'emoji': '🏕️',
      'description':
          'Outdoor campfire setting with stars above, perfect for family adventures.',
      'mood': 'Adventurous and together',
      'routine': 'Sharing tales under the night sky',
      'category': 'family',
    },
    {
      'title': 'Storybook Nook',
      'emoji': '📚',
      'description':
          'Enchanted library corner with floating books and a magical reading space.',
      'mood': 'Curious and imaginative',
      'routine': 'Cozy reading and discovery',
      'category': 'family',
    },
    // Solo Unwind themes
    {
      'title': 'Oceanic Serenity',
      'emoji': '🌊',
      'description':
          'Peaceful beach at night with gentle waves and distant seagull calls.',
      'mood': 'Peaceful and relaxed',
      'routine': 'Listening to the rhythm of the ocean',
      'category': 'unwind',
    },
    {
      'title': 'Starlit Sanctuary',
      'emoji': '✨',
      'description':
          'Celestial garden with bioluminescent river paths under a star-filled sky.',
      'mood': 'Dreamy and serene',
      'routine': 'Breathing ritual by the window',
      'category': 'unwind',
    },
    {
      'title': 'Whispering Woods',
      'emoji': '🌲',
      'description':
          'Forest spirits hum lullabies with your spirit guide in a tranquil grove.',
      'mood': 'Grounded with soft curiosity',
      'routine': 'Herbal tea and journaling',
      'category': 'unwind',
    },
    {
      'title': 'Aurora Dreams',
      'emoji': '🌌',
      'description':
          'Northern lights swirl above floating lagoons in an ethereal landscape.',
      'mood': 'In awe, ready to unwind',
      'routine': 'Stretching + gratitude whisper',
      'category': 'unwind',
    },
  ];

  // Featured worlds showcase - one from each category
  List<Map<String, String>> get _featuredWorlds {
    final focus = _allThemes.where((t) => t['category'] == 'focus').first;
    final family = _allThemes.where((t) => t['category'] == 'family').first;
    final unwind = _allThemes.where((t) => t['category'] == 'unwind').first;
    return [focus, family, unwind];
  }

  bool _maestroEnabled = false;
  bool _smartScenesEnabled = false;
  bool _calmQuestsEnabled = false;
  // These fields are set but not directly used - they're used to compute _maestroEnabled
  // ignore: unused_field
  bool _isCaregiver = false;
  // ignore: unused_field
  bool _maestroOptIn = false;
  TravelStatus? _travelStatus;
  List<SessionHistoryItem> _recentStories = [];
  bool _isLoadingRecentStories = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _hydrateAdvancedContext();
    _loadRecentStories();
  }

  Future<void> _checkPremiumStatus() async {
    final isPremium = await _adService.isUserPremium();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
      });
      if (!isPremium) {
        _loadNativeAd();
      }
    }
  }

  void _loadNativeAd() {
    _nativeAd = _adService.createNativeAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isNativeAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('Home Native Ad failed to load: $error');
      },
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  Future<void> _hydrateAdvancedContext() async {
    try {
      final maestro = await _flagService.isEnabled(FeatureFlag.maestro);
      final smartScenes = await _flagService.isEnabled(FeatureFlag.smartScenes);
      final quests = await _flagService.isEnabled(FeatureFlag.calmQuests);
      final travel = await _travelService.getStatus();
      final caregiver = await _preferencesService.isCaregiver();
      final maestroOptIn = await _preferencesService.isMaestroOptedIn();
      if (!mounted) return;
      setState(() {
        _isCaregiver = caregiver;
        _maestroOptIn = maestroOptIn;
        _maestroEnabled = maestro && caregiver && maestroOptIn;
        _smartScenesEnabled = smartScenes;
        _calmQuestsEnabled = quests;
        _travelStatus = travel;
      });
    } catch (_) {
      // Non-blocking
    }
  }

  Future<void> _loadRecentStories() async {
    if (_isLoadingRecentStories) return;

    setState(() {
      _isLoadingRecentStories = true;
    });

    try {
      final user = _authService.currentUser;
      List<SessionHistoryItem> stories;
      if (user == null) {
        stories = await _storyService.getOfflineHistory();
      } else {
        stories = await _storyService.getHistory(
          userId: user.id,
          limit: 5,
          forceRefresh: false,
        );
      }

      if (mounted) {
        setState(() {
          _recentStories = stories;
          _isLoadingRecentStories = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRecentStories = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05020C),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF120E2B), Color(0xFF07040F)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -30,
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -40,
              child: Container(
                height: 280,
                width: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildQuickActionsBar(),
                  const SizedBox(height: 24),
                  if (_maestroEnabled ||
                      _smartScenesEnabled ||
                      _calmQuestsEnabled) ...[
                    _buildGlassCard(child: _buildCaregiverHub()),
                    const SizedBox(height: 24),
                  ],
                  // Reflection Insights Widget
                  ReflectionInsightsWidget(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReflectionsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildRecentStories(),
                  const SizedBox(height: 24),
                  _buildFeaturedWorlds(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Column(
      children: [
        // Main Create Story Button - Full Width
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateStoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text(
              'Create New Story',
              style: TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Secondary Actions Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyStoriesScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history, color: Colors.white70),
                label: const Text(
                  'My Stories',
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoryDiscoveryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.explore, color: Colors.white70),
                label: const Text(
                  'Discover',
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              const SizedBox(height: 4),
              Text(
                'Personalized bedtime cinema infused with your nightly rhythm.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 24,
              ),
              tooltip: 'Settings',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _handleLogout,
              icon: const Icon(
                Icons.logout,
                color: Colors.white,
                size: 24,
              ),
              tooltip: 'Logout',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFF8B5CF6)),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to logout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildCaregiverHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caregiver hub',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        // Grid layout for better organization
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1, // Reduced from 1.3 to give more vertical space
          children: [
            if (_smartScenesEnabled)
              _CaregiverChip(
                icon: Icons.graphic_eq,
                title: 'Smart scenes',
                subtitle: 'Lights, diffuser &\nroutines',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SmartSceneScreen(),
                    ),
                  );
                },
              ),
            if (_calmQuestsEnabled)
              _CaregiverChip(
                icon: Icons.auto_awesome,
                title: 'Calm quests',
                subtitle: 'Rewards for mindful\nstreaks',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalmQuestsScreen(),
                    ),
                  );
                },
              ),
          ],
        ),
        // Maestro dashboard as a full-width card if enabled
        if (_maestroEnabled) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _CaregiverChip(
              icon: Icons.insights_rounded,
              title: 'Maestro dashboard',
              subtitle: 'Nightly tips & nudges',
              isFullWidth: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MaestroDashboardScreen(),
                  ),
                ).then((_) => _hydrateAdvancedContext());
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildRecentStories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recently Created',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_recentStories.length >= 5)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyStoriesScreen(),
                    ),
                  ).then((_) => _loadRecentStories());
                },
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: _isLoadingRecentStories
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : _recentStories.isEmpty
                  ? Center(
                      child: Text(
                        'No stories yet. Create your first story!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentStories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _buildRecentStoryCard(_recentStories[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRecentStoryCard(SessionHistoryItem session) {
    // Find theme emoji from all themes
    final themeData = _allThemes.firstWhere(
      (theme) => theme['title'] == session.theme,
      orElse: () => {'emoji': '✨', 'title': session.theme},
    );

    return GestureDetector(
      onTap: () async {
        try {
          final storyDetail =
              await _storyService.getStoryDetails(session.sessionId);
          final experience = StoryExperience(
            storyText: storyDetail.storyText,
            theme: storyDetail.theme,
            audioUrl: storyDetail.audioUrl ?? '',
            frames: storyDetail.frames,
            sessionId: storyDetail.sessionId,
          );
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionScreen(experience: experience),
              ),
            ).then((_) => _loadRecentStories());
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load story: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Container(
                height: 100,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.05),
                child: session.thumbnailUrl != null
                    ? Image.network(
                        session.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildStoryThumbnailPlaceholder(
                            themeData['emoji']!,
                          );
                        },
                      )
                    : _buildStoryThumbnailPlaceholder(themeData['emoji']!),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.theme,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.prompt,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryThumbnailPlaceholder(String emoji) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            const Color(0xFF06B6D4).withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }

  Widget _buildFeaturedWorlds() {
    final featured = _featuredWorlds;
    final displayCount = _isNativeAdLoaded ? featured.length + 1 : featured.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured Worlds',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _featuredWorldHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              // Inject ad at the second position if loaded
              if (_isNativeAdLoaded && index == 1) {
                return _buildNativeAdCard();
              }
              
              final presetIndex = (_isNativeAdLoaded && index > 1) ? index - 1 : index;
              return _buildPresetCard(featured[presetIndex]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNativeAdCard() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: AdWidget(ad: _nativeAd!),
    );
  }

  Widget _buildPresetCard(Map<String, String> preset) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateStoryScreen(
              presetTheme: preset['title'],
              presetMood: preset['mood'],
              presetRoutine: preset['routine'],
            ),
          ),
        );
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preset['emoji'] ?? '✨', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              preset['title']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preset['description']!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
            const Spacer(),
            Row(
              children: const [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Tap to infuse profile',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CaregiverChip extends StatelessWidget {
  const _CaregiverChip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFullWidth = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(12), // Reduced from 14 to save space
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isFullWidth 
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon, 
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced from 10
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8), // Reduced from 10
                  ),
                  child: Icon(
                    icon, 
                    color: Colors.white,
                    size: 20, // Reduced from 22
                  ),
                ),
                const SizedBox(height: 10), // Reduced from 12
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14, // Reduced from 15
                  ),
                ),
                const SizedBox(height: 3), // Reduced from 4
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11, // Reduced from 12
                    height: 1.1, // Reduced from 1.2 for tighter line spacing
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      ),
    );
  }
}
