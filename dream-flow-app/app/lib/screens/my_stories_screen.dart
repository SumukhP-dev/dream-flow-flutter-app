import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/story_service.dart'
    show StoryService, SessionHistoryItem, StoryExperience;
import '../core/auth_service.dart';
import '../services/ad_service.dart';
import '../widgets/kid_empty_state_widget.dart';
import '../widgets/kid_loading_indicator.dart';
import 'session_screen.dart';
import 'reflections_screen.dart';

class MyStoriesScreen extends StatefulWidget {
  final bool isKidMode;

  const MyStoriesScreen({super.key, this.isKidMode = false});

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen> {
  final StoryService _storyService = StoryService();
  final AuthService _authService = AuthService();
  final AdService _adService = AdService();

  List<SessionHistoryItem> _sessions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  // Ad state
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;
  bool _isPremium = true;

  // All available themes for emoji lookup
  final List<Map<String, String>> _allThemes = [
    {'title': 'Study Grove', 'emoji': '🌿'},
    {'title': 'Focus Falls', 'emoji': '💧'},
    {'title': 'Zen Garden', 'emoji': '🪨'},
    {'title': 'Family Hearth', 'emoji': '🔥'},
    {'title': 'Campfire Chronicles', 'emoji': '🏕️'},
    {'title': 'Storybook Nook', 'emoji': '📚'},
    {'title': 'Oceanic Serenity', 'emoji': '🌊'},
    {'title': 'Starlit Sanctuary', 'emoji': '✨'},
    {'title': 'Whispering Woods', 'emoji': '🌲'},
    {'title': 'Aurora Dreams', 'emoji': '🌌'},
  ];

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _loadSessions();
  }

  Future<void> _checkPremiumStatus() async {
    if (widget.isKidMode) return;

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
        debugPrint('MyStories Native Ad failed to load: $error');
      },
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({bool refresh = false}) async {
    if (_isLoading) return;

    final user = _authService.currentUser;
    final isOfflineUser = user == null;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _offset = 0;
        _sessions = [];
        _hasMore = !isOfflineUser;
      }
    });

    try {
      List<SessionHistoryItem> sessions;
      if (isOfflineUser) {
        sessions = await _storyService.getOfflineHistory();
      } else {
        sessions = await _storyService.getHistory(
          userId: user.id,
          limit: _limit,
        );
      }

      if (mounted) {
        setState(() {
          if (refresh) {
            _sessions = sessions;
          } else {
            _sessions.addAll(sessions);
          }
          _offset += sessions.length;
          _hasMore = !isOfflineUser && sessions.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (widget.isKidMode) {
          setState(() {
            // Error will be shown in UI
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load stories: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05020C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'My Stories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: widget.isKidMode ? 24 : null,
          ),
        ),
        actions: [
          if (!widget.isKidMode)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'My Reflections',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReflectionsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
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
            _isLoading && _sessions.isEmpty
                ? Center(
                    child: widget.isKidMode
                        ? const KidLoadingIndicator(
                            message: 'Loading your stories...',
                          )
                        : const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                  )
                : _sessions.isEmpty
                    ? widget.isKidMode
                        ? KidEmptyStateWidget(
                            emoji: '📚',
                            message:
                                'No stories yet!\nCreate your first magical story ✨',
                            actionLabel: 'Create Story',
                            onAction: () => Navigator.pop(context),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_stories,
                                  size: 64,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No stories yet',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first story to get started',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                    : RefreshIndicator(
                        onRefresh: () => _loadSessions(refresh: true),
                        color: const Color(0xFF8B5CF6),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: widget.isKidMode ? 0.7 : 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _sessions.length +
                              (_hasMore ? 1 : 0) +
                              (_isNativeAdLoaded ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isNativeAdLoaded && index == 4) {
                              return _buildNativeAdCard();
                            }

                            final sessionIndex =
                                (_isNativeAdLoaded && index > 4)
                                    ? index - 1
                                    : index;

                            if (sessionIndex == _sessions.length) {
                              // Load more trigger
                              _loadSessions();
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              );
                            }
                            final session = _sessions[sessionIndex];
                            return _buildSessionCard(session);
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeAdCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: AdWidget(ad: _nativeAd!),
    );
  }

  Widget _buildSessionCard(SessionHistoryItem session) {
    // Find theme emoji from all themes
    final themeData = _allThemes.firstWhere(
      (theme) => theme['title'] == session.theme,
      orElse: () => {'emoji': '✨', 'title': session.theme},
    );

    return GestureDetector(
      onTap: () async {
        // Load the full story experience from the session ID
        try {
          final storyDetail =
              await _storyService.getStoryDetails(session.sessionId);
          // Convert StoryDetail to StoryExperience
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
            );
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
            // Thumbnail or placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Container(
                height: widget.isKidMode ? 140 : 120,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.05),
                child: session.thumbnailUrl != null
                    ? Image.network(
                        session.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildThumbnailPlaceholder(
                            themeData['emoji']!,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          );
                        },
                      )
                    : _buildThumbnailPlaceholder(themeData['emoji']!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.theme,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.isKidMode ? 16 : 14,
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
                      fontSize: widget.isKidMode ? 13 : 11,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (session.isOffline) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Stored locally',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(String emoji) {
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
          style: TextStyle(fontSize: widget.isKidMode ? 40 : 32),
        ),
      ),
    );
  }
}
