import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/story_service.dart';
import '../shared/feedback_service.dart';
import '../shared/sentry_service.dart';
import '../widgets/feedback_modal.dart';
import '../widgets/youtube_badge.dart';
import '../widgets/reflection_capture_sheet.dart';
import '../services/reflection_service.dart';
import '../shared/preferences_service.dart';
import '../widgets/bilingual_webtoons_story.dart';
import '../widgets/webtoons_story_viewer.dart';
import '../services/achievement_service.dart'
    show AchievementService, Achievement;
import '../services/streak_service.dart';
import '../services/parental_control_service.dart';
import '../services/reading_comprehension_service.dart';
import '../services/ad_service.dart';
import '../widgets/comprehension_quiz_widget.dart';
import '../widgets/celebration_animation_widget.dart';

class SessionScreen extends StatefulWidget {
  final StoryExperience experience;

  const SessionScreen({super.key, required this.experience});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  static const List<String> _reflectionPrompts = [
    '✨ Peak sparkle moment',
    '🌊 Travel or movement motif',
    '🛌 Cozy sensory detail',
    '🎧 Sound or song that lingered',
  ];
  final AudioService _audioService = AudioService();
  final StoryService _storyService = StoryService();
  final FeedbackService _feedbackService = FeedbackService();
  final ReflectionService _reflectionService = ReflectionService();
  final PreferencesService _preferencesService = PreferencesService();
  final AchievementService _achievementService = AchievementService();
  final StreakService _streakService = StreakService();
  final ParentalControlService _parentalControlService =
      ParentalControlService();
  final ReadingComprehensionService _comprehensionService =
      ReadingComprehensionService();
  final AdService _adService = AdService();
  bool _isAudioPlaying = false;
  bool _hasTrackedCompletion = false;
  List<ComprehensionQuestion> _comprehensionQuestions = [];
  bool _showComprehensionQuiz = false;
  bool _offlineEnabled = false;
  bool _hasOfflineNarration = false;
  bool _isCachingNarration = false;
  String? _offlineError;
  bool _isSharingStory = false;
  bool _hasShownFeedback = false;
  DateTime? _playbackStartTime;
  Timer? _feedbackTimer;
  bool _isLoggingReflection = false;
  bool _isChildMode = false;
  String _primaryLanguage = 'en';
  String _secondaryLanguage = 'es';
  bool get _isOfflineSession =>
      widget.experience.sessionId
          ?.startsWith(StoryService.offlineSessionPrefix) ??
      false;

  @override
  void initState() {
    super.initState();
    // Set session ID in Sentry context if available
    if (widget.experience.sessionId != null) {
      SentryService.setSessionId(widget.experience.sessionId);
    }
    _loadOfflineState();
    _initializeExperience();
    _loadComprehensionQuestions();
    // Process any queued feedback on startup
    _feedbackService.processQueue().catchError((_) {
      // Silently fail - queue processing is not critical
    });
    _loadLanguageSettings();
  }

  Future<void> _loadLanguageSettings() async {
    try {
      // Detect child mode from story experience
      setState(() {
        _isChildMode =
            widget.experience.isChildMode || widget.experience.childAge != null;
        // Use languages from story experience, fallback to defaults
        _primaryLanguage = widget.experience.primaryLanguage ?? 'en';
        _secondaryLanguage = widget.experience.secondaryLanguage ?? 'es';
      });
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> _initializeExperience() async {
    final audioUrl = widget.experience.audioUrl;

    // Only try to play audio if URL is provided and not empty
    if (audioUrl.isNotEmpty) {
      try {
        await _audioService.playUrl(audioUrl, preferCache: _offlineEnabled);
        setState(() {
          _isAudioPlaying = true;
          _playbackStartTime = DateTime.now();
        });
        // Start timer to show feedback after 2 minutes of playback
        _startFeedbackTimer();
      } catch (audioError) {
        // Audio error doesn't block the experience
        print('⚠️ Audio playback failed: $audioError');
        setState(() => _isAudioPlaying = false);
      }
    } else {
      // No audio provided - this is normal for text-only stories
      print('ℹ️ No audio URL provided, showing text-only experience');
      setState(() => _isAudioPlaying = false);
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
        leading: Semantics(
          button: true,
          label: 'Back to home screen',
          child: IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: _navigateHome,
            tooltip: 'Back to home',
          ),
        ),
        title: Text(
          widget.experience.theme,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          YouTubeBadge(
            youtubeUrl: widget.experience.youtubeUrl,
            isFeatured: widget.experience.isFeatured ?? false,
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Nightly arc',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWebtoonsStoryViewer(),
            const SizedBox(height: 24),
            _buildShareStoryButton(),
            const SizedBox(height: 24),
            _buildAudioControls(),
            if (!_isChildMode && !_isOfflineSession) ...[
              const SizedBox(height: 24),
              _buildReflectionPromptCard(),
            ],
            if (_isChildMode &&
                _comprehensionQuestions.isNotEmpty &&
                _showComprehensionQuiz) ...[
              const SizedBox(height: 24),
              _buildComprehensionQuiz(),
            ],
            if (_isChildMode &&
                _comprehensionQuestions.isNotEmpty &&
                !_showComprehensionQuiz) ...[
              const SizedBox(height: 24),
              _buildComprehensionQuizButton(),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF16A34A),
      ),
    );
  }

  Widget _buildStoryCard(List<String> paragraphs) {
    // Use webtoons-style bilingual display
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_stories, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'Story Arc',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Use bilingual webtoons widget if we have secondary language, otherwise fallback
          if (_secondaryLanguage.isNotEmpty &&
              _secondaryLanguage != _primaryLanguage)
            BilingualWebtoonsStory(
              storyText: widget.experience.storyText,
              primaryLanguage: _primaryLanguage,
              secondaryLanguage: _secondaryLanguage,
              isChildMode: _isChildMode,
            )
          else
            // Fallback to simple display if no bilingual support
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: paragraphs
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          p,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.7,
                            fontSize: _isChildMode ? 20 : 18,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebtoonsStoryViewer() {
    final experience = widget.experience;

    if (experience.frames.isEmpty) {
      // Fallback to old layout if no frames
      final paragraphs = experience.storyText
          .split('\n')
          .where((p) => p.trim().isNotEmpty)
          .toList();
      return Column(
        children: [
          _buildStoryCard(paragraphs),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.auto_stories, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              'Story',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        WebtoonsStoryViewer(
          frames: experience.frames,
          storyText: experience.storyText,
          primaryLanguage: _primaryLanguage,
          secondaryLanguage: _secondaryLanguage,
          isChildMode: _isChildMode,
        ),
      ],
    );
  }

  Widget _buildShareStoryButton() {
    if (widget.experience.sessionId == null || _isOfflineSession) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share_rounded, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Share Story',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _isChildMode ? 20 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Share this story with the Dream Flow community. It will be visible after moderation.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSharingStory ? null : _handleShareStory,
              icon: _isSharingStory
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.share_rounded),
              label: Text(_isSharingStory ? 'Sharing...' : 'Share Story'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShareStory() async {
    if (widget.experience.sessionId == null || _isOfflineSession) return;

    setState(() => _isSharingStory = true);

    try {
      await _storyService.shareStory(
        sessionId: widget.experience.sessionId!,
        ageRating: 'all', // Default age rating
      );

      if (!mounted) return;
      _showSnack(
        'Story shared! It will be visible after moderation.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'Failed to share story: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSharingStory = false);
    }
  }

  Widget _buildAudioControls() {
    final buttonSize = _isChildMode ? 80.0 : 64.0;
    final iconSize = _isChildMode ? 40.0 : 32.0;
    final fontSize = _isChildMode ? 20.0 : 16.0;
    final descriptionSize = _isChildMode ? 16.0 : 13.0;

    return Container(
      padding: EdgeInsets.all(_isChildMode ? 24 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                  ),
                ),
                child: Icon(
                  Icons.spatial_audio_off,
                  color: Colors.white,
                  size: _isChildMode ? 36 : 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAudioPlaying
                          ? (_isChildMode
                              ? 'Story is playing! 🎵'
                              : 'Narration playing')
                          : (_isChildMode
                              ? 'Story is paused ⏸️'
                              : 'Narration paused'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_isChildMode) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Gentle ${_isAudioPlaying ? 'looping' : 'ready'} voice linked to your profile.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: descriptionSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: iconSize,
                icon: Icon(
                  _isAudioPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white,
                ),
                onPressed: widget.experience.audioUrl.isNotEmpty ? () async {
                  if (_isAudioPlaying) {
                    await _audioService.stop();
                    setState(() => _isAudioPlaying = false);
                    // Show feedback modal if user stopped playback and hasn't shown it yet
                    if (!_hasShownFeedback && _playbackStartTime != null) {
                      final playbackDuration = DateTime.now().difference(
                        _playbackStartTime!,
                      );
                      // Only show if they played for at least 30 seconds
                      if (playbackDuration.inSeconds >= 30) {
                        _showFeedbackModal();
                      }
                    }
                  } else {
                    await _audioService.playUrl(
                      widget.experience.audioUrl,
                      preferCache: _offlineEnabled,
                    );
                    setState(() {
                      _isAudioPlaying = true;
                      _playbackStartTime = DateTime.now();
                    });
                    // Start timer to show feedback after 2 minutes of playback
                    _startFeedbackTimer();
                  }
                } : null, // Disable button if no audio URL
              ),
            ],
          ),
          if (!_isChildMode) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            _buildOfflineToggle(),
          ],
        ],
      ),
    );
  }

  Widget _buildReflectionPromptCard() {
    // Skip reflection for kids - it's optional and can be overwhelming
    if (_isChildMode) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.nightlight_round, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'Narrative journaling',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Log a quick emoji mood, note, or 30s whisper to unlock insights.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reflectionPrompts
                .map((prompt) => _reflectionPromptChip(prompt))
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isLoggingReflection ? null : () => _openReflectionComposer(),
              icon: _isLoggingReflection
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(
                _isLoggingReflection
                    ? 'Saving...'
                    : 'Log tonight\'s reflection',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reflectionPromptChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: _isLoggingReflection
          ? null
          : () => _openReflectionComposer(seedPrompt: label),
    );
  }

  Future<void> _openReflectionComposer({String? seedPrompt}) async {
    if (_isOfflineSession || widget.experience.sessionId == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReflectionCaptureSheet(
          sessionId: widget.experience.sessionId,
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
    if (_isOfflineSession || widget.experience.sessionId == null) {
      _showSnack('Sign in to log reflections.', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoggingReflection = true);
    try {
      await _reflectionService.submitReflection(
        sessionId: widget.experience.sessionId,
        mood: mood,
        note: note,
        audioPath: audioPath,
      );
      if (mounted) {
        _showSnack('Reflection saved. Weekly insights updating.');
      }
    } catch (error) {
      if (mounted) {
        _showSnack('Unable to save reflection: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingReflection = false);
      }
    }
  }

  Widget _buildOfflineToggle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_download_outlined,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Offline narration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _offlineError ?? _offlineStatusText,
                style: TextStyle(
                  color: _offlineError != null
                      ? Colors.redAccent
                      : Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
              if (_isCachingNarration) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: _offlineEnabled,
          onChanged: _isCachingNarration ? null : _handleOfflineToggle,
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withValues(alpha: 0.5),
          inactiveThumbColor: Colors.grey.shade400,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _trackStoryCompletion();
    _showInterstitialIfEligible();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _showInterstitialIfEligible() async {
    // Show interstitial ad when user leaves the session
    await _adService.showInterstitialIfEligible();
  }

  Future<void> _trackStoryCompletion() async {
    if (_hasTrackedCompletion) return;

    // Only track if audio was played (user engaged with story)
    if (!_isAudioPlaying && _playbackStartTime == null) return;

    try {
      // Get child profile ID if in child mode
      String? childProfileId;
      if (_isChildMode && widget.experience.childAge != null) {
        // Try to get child profile from parent profiles
        try {
          final profiles = await _parentalControlService.getChildProfiles();
          // Use first profile for now (in production, match by age or other criteria)
          if (profiles.isNotEmpty) {
            childProfileId = profiles.first['id'] as String?;
          }
        } catch (e) {
          // Silently fail
        }
      }

      if (childProfileId != null) {
        _hasTrackedCompletion = true;

        // Record streak activity
        await _streakService.recordActivity(childProfileId: childProfileId);

        // Check and unlock achievements
        final newlyUnlocked =
            await _achievementService.checkAndUnlockAchievements(
          childProfileId: childProfileId,
          eventType: 'story_completed',
          eventData: {
            'theme': widget.experience.theme,
            'session_id': widget.experience.sessionId,
          },
        );

        // Show achievement notification if any were unlocked
        if (newlyUnlocked.isNotEmpty && mounted) {
          _showAchievementNotification(newlyUnlocked.first);
        }
      }
    } catch (e) {
      // Silently fail - achievement tracking is non-critical
    }
  }

  void _showAchievementNotification(Achievement achievement) {
    // Show celebration animation overlay
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: true,
      builder: (context) => Stack(
        children: [
          // Celebration animation background
          CelebrationAnimationWidget(
            duration: const Duration(seconds: 2),
            onComplete: () {
              Navigator.pop(context);
            },
          ),
          // Achievement card
          Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    achievement.type.emoji,
                    style: const TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Achievement Unlocked!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    achievement.type.title,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Also show snackbar for quick notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              achievement.type.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Achievement Unlocked!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    achievement.type.title,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadOfflineState() async {
    try {
      final hasAudioCache = await _audioService.hasCachedNarration(
        widget.experience.audioUrl,
      );
      if (!mounted) return;
      setState(() {
        _hasOfflineNarration = hasAudioCache;
        _offlineEnabled = hasAudioCache;
      });
    } catch (_) {
      // Ignore failures when checking cache.
    }
  }

  Future<void> _handleOfflineToggle(bool value) async {
    setState(() {
      _offlineError = null;
      _offlineEnabled = value;
      _isCachingNarration = true;
    });

    if (value) {
      try {
        await _audioService.cacheNarration(widget.experience.audioUrl);
        await _audioService.trimCacheIfNeeded();
        if (!mounted) return;
        setState(() {
          _hasOfflineNarration = true;
          _isCachingNarration = false;
        });
        if (_isAudioPlaying) {
          await _restartAudio(preferCache: true);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _offlineEnabled = false;
          _offlineError = 'Failed to download content for offline use.';
          _isCachingNarration = false;
        });
      }
    } else {
      try {
        await _audioService.deleteCachedNarration(widget.experience.audioUrl);
        if (!mounted) return;
        setState(() {
          _hasOfflineNarration = false;
          _isCachingNarration = false;
        });
        if (_isAudioPlaying) {
          await _restartAudio(preferCache: false);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _offlineError = 'Failed to remove offline narration.';
          _isCachingNarration = false;
        });
      }
    }
  }

  Future<void> _restartAudio({required bool preferCache}) async {
    setState(() => _isAudioPlaying = false);
    await _audioService.stop();
    try {
      await _audioService.playUrl(
        widget.experience.audioUrl,
        preferCache: preferCache,
      );
      if (!mounted) return;
      setState(() => _isAudioPlaying = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAudioPlaying = false;
        _offlineError ??= 'Unable to restart narration.';
      });
    }
  }

  String get _offlineStatusText {
    if (_isCachingNarration) {
      return 'Preparing narration for offline playback...';
    }
    if (_offlineEnabled) {
      if (_hasOfflineNarration) {
        return 'Narration stored on device. No data needed.';
      }
    }
    if (_hasOfflineNarration) {
      return 'Download available. Toggle to enable offline use.';
    }
    return 'Stream content over your current connection.';
  }

  void _startFeedbackTimer() {
    _feedbackTimer?.cancel();
    // Show feedback modal after 2 minutes of playback
    _feedbackTimer = Timer(const Duration(minutes: 2), () {
      if (mounted && _isAudioPlaying && !_hasShownFeedback) {
        _showFeedbackModal();
      }
    });
  }

  void _showFeedbackModal() {
    if (_hasShownFeedback ||
        widget.experience.sessionId == null ||
        _isOfflineSession) {
      return;
    }

    _feedbackTimer?.cancel();

    setState(() {
      _hasShownFeedback = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FeedbackModal(
        sessionId: widget.experience.sessionId!,
        onSubmitted: (rating, moodDelta) {
          // Feedback is already submitted by the modal
          // This callback is just for notification
        },
        onDismissed: () {
          // User dismissed without submitting
        },
      ),
    );
  }

  Future<void> _loadComprehensionQuestions() async {
    if (_isOfflineSession ||
        widget.experience.sessionId == null ||
        !_isChildMode) {
      return;
    }

    try {
      final questions = await _comprehensionService.getQuestionsForStory(
        widget.experience.sessionId!,
      );
      if (mounted) {
        setState(() {
          _comprehensionQuestions = questions;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Widget _buildComprehensionQuizButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            '🧠',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          const Text(
            'Test Your Understanding!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Answer questions about the story you just read',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _showComprehensionQuiz = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Start Quiz',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComprehensionQuiz() {
    // Get child profile ID for tracking (will be loaded asynchronously)
    String? childProfileId;
    if (widget.experience.childAge != null) {
      _parentalControlService.getChildProfiles().then((profiles) {
        if (profiles.isNotEmpty && mounted) {
          setState(() {
            // Store for use in quiz widget
          });
        }
      }).catchError((_) {
        // Silently fail
      });
    }

    return ComprehensionQuizWidget(
      questions: _comprehensionQuestions,
      childProfileId: childProfileId,
      onComplete: (correct, total) {
        // Show completion message
        _showSnack(
          'Great job! You got $correct out of $total questions correct!',
        );
      },
    );
  }
}

enum _PermissionScope { downloads, gallery }
