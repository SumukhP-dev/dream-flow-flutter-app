import 'dart:async';
import 'dart:io' show Platform;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../services/audio_service.dart';
import '../services/video_service.dart';
import '../services/session_asset_service.dart';
import '../services/story_service.dart';
import '../services/feedback_service.dart';
import '../services/sentry_service.dart';
import 'feedback_modal.dart';

class SessionScreen extends StatefulWidget {
  final StoryExperience experience;

  const SessionScreen({super.key, required this.experience});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final AudioService _audioService = AudioService();
  final VideoService _videoService = VideoService();
  final SessionAssetService _assetService = SessionAssetService();
  final StoryCardService _storyCardService = StoryCardService();
  final FeedbackService _feedbackService = FeedbackService();
  bool _isAudioPlaying = false;
  bool _isVideoReady = false;
  bool _isVideoError = false;
  String? _error;
  bool _offlineEnabled = false;
  bool _hasOfflineNarration = false;
  bool _isCachingNarration = false;
  bool _hasOfflineVideo = false;
  bool _isCachingVideo = false;
  String? _offlineError;
  bool _isDownloadingVideo = false;
  bool _isDownloadingAudio = false;
  bool _isSavingFrames = false;
  bool _isSharingSession = false;
  bool _hasShownFeedback = false;
  DateTime? _playbackStartTime;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    // Set session ID in Sentry context if available
    if (widget.experience.sessionId != null) {
      SentryService.setSessionId(widget.experience.sessionId);
    }
    _loadOfflineState();
    _initializeExperience();
    // Process any queued feedback on startup
    _feedbackService.processQueue().catchError((_) {
      // Silently fail - queue processing is not critical
    });
  }

  Future<void> _initializeExperience() async {
    final videoUrl = widget.experience.videoUrl;
    final audioUrl = widget.experience.audioUrl;

    // Reset error state
    setState(() {
      _isVideoError = false;
      _error = null;
    });

    try {
      // Initialize video controller
      _videoController?.dispose();
      _chewieController?.dispose();
      
      // Check for cached video first
      final cachedVideo = await _videoService.getCachedVideo(videoUrl);
      if (cachedVideo != null && await cachedVideo.exists()) {
        // Use cached video
        _videoController = VideoPlayerController.file(cachedVideo);
      } else {
        // Use network video
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        // Cache video in background if offline mode is enabled
        if (_offlineEnabled) {
          _cacheVideoInBackground(videoUrl);
        }
      }
      
      // Attempt to initialize video - this can fail
      await _videoController!.initialize();
      
      // Check if initialization was successful
      if (!_videoController!.value.isInitialized) {
        throw Exception('Video player failed to initialize');
      }
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        looping: true,
        autoPlay: true,
        showControls: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: false,
      );
      
      setState(() {
        _isVideoReady = true;
        _isVideoError = false;
      });
      
      // Try to play audio (non-blocking for video errors)
      try {
        await _audioService.playUrl(
          audioUrl,
          preferCache: _offlineEnabled,
        );
        setState(() {
          _isAudioPlaying = true;
          _playbackStartTime = DateTime.now();
        });
        // Start timer to show feedback after 2 minutes of playback
        _startFeedbackTimer();
      } catch (audioError) {
        // Audio error doesn't block the experience
        setState(() => _isAudioPlaying = false);
      }
    } catch (e) {
      // Clean up failed controllers
      _chewieController?.dispose();
      _chewieController = null;
      _videoController?.dispose();
      _videoController = null;
      
      setState(() {
        _isVideoReady = false;
        _isVideoError = true;
        _error = 'Unable to load video: ${e.toString()}';
      });
    }
  }

  Future<void> _retryVideoInitialization() async {
    await _initializeExperience();
  }

  @override
  Widget build(BuildContext context) {
    final experience = widget.experience;
    final paragraphs =
        experience.storyText.split('\n').where((p) => p.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF05020C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          experience.theme,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
            _buildVideoCard(),
            const SizedBox(height: 16),
            _buildAssetActions(),
            const SizedBox(height: 24),
            _buildStoryCard(paragraphs),
            const SizedBox(height: 20),
            _buildFramesGallery(experience.frames),
            const SizedBox(height: 24),
            _buildAudioControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _isVideoError
              ? _buildVideoErrorPlaceholder()
              : _isVideoReady && _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildVideoErrorPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withValues(alpha: 0.2),
            Colors.blue.withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.videocam_off_rounded,
              size: 64,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Video unavailable',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unable to load video playback',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _retryVideoInitialization,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.download_rounded, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'Session assets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Save or share your generated video, narration, and postcards.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _assetActionButton(
                icon: Icons.smart_display_outlined,
                label: 'Download video',
                busy: _isDownloadingVideo,
                onPressed: _isDownloadingVideo ? null : _handleDownloadVideo,
              ),
              _assetActionButton(
                icon: Icons.graphic_eq_rounded,
                label: 'Download narration',
                busy: _isDownloadingAudio,
                onPressed: _isDownloadingAudio ? null : _handleDownloadAudio,
              ),
              _assetActionButton(
                icon: Icons.photo_library_outlined,
                label: 'Save frames to gallery',
                busy: _isSavingFrames,
                onPressed: _isSavingFrames || widget.experience.frames.isEmpty
                    ? null
                    : _handleSaveFrames,
              ),
              _assetActionButton(
                icon: Icons.share_rounded,
                label: 'Share session',
                busy: _isSharingSession,
                onPressed: _isSharingSession ? null : _handleShareSession,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assetActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool busy,
  }) {
    return SizedBox(
      width: 185,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          backgroundColor: Colors.white.withValues(alpha: 0.02),
        ),
        icon: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _handleDownloadVideo() async {
    if (!await _ensurePermission(_PermissionScope.downloads)) return;

    setState(() => _isDownloadingVideo = true);
    try {
      final extension = _extensionFromUrl(
        widget.experience.videoUrl,
        fallback: '.mp4',
      );
      final fileName = _buildFileName(
        suffix: 'session',
        extension: extension,
      );
      final file = await _assetService.downloadVideo(
        url: widget.experience.videoUrl,
        fileName: fileName,
      );
      _showSnack('Video saved to ${file.path}');
    } catch (_) {
      _showSnack('Failed to download video.', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isDownloadingVideo = false);
    }
  }

  Future<void> _handleDownloadAudio() async {
    if (!await _ensurePermission(_PermissionScope.downloads)) return;

    setState(() => _isDownloadingAudio = true);
    try {
      final extension = _extensionFromUrl(
        widget.experience.audioUrl,
        fallback: '.m4a',
      );
      final fileName = _buildFileName(
        suffix: 'narration',
        extension: extension,
      );
      final file = await _assetService.downloadAudio(
        url: widget.experience.audioUrl,
        fileName: fileName,
      );
      _showSnack('Narration saved to ${file.path}');
    } catch (_) {
      _showSnack('Failed to download narration.', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isDownloadingAudio = false);
    }
  }

  Future<void> _handleSaveFrames() async {
    if (widget.experience.frames.isEmpty) {
      _showSnack('No frames available to save.', isError: true);
      return;
    }

    if (!await _ensurePermission(_PermissionScope.gallery)) return;

    setState(() => _isSavingFrames = true);
    try {
      final saved = await _assetService.saveFramesToGallery(
        widget.experience.frames,
        albumName: 'Dream Flow',
      );
      final suffix = saved == 1 ? '' : 's';
      _showSnack('Saved $saved frame$suffix to gallery.');
    } catch (_) {
      _showSnack('Failed to save frames.', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isSavingFrames = false);
    }
  }

  Future<void> _handleShareSession() async {
    setState(() => _isSharingSession = true);
    try {
      final attachments = <XFile>[];

      try {
        final videoExt = _extensionFromUrl(
          widget.experience.videoUrl,
          fallback: '.mp4',
        );
        final videoFile = await _assetService.cacheForShare(
          url: widget.experience.videoUrl,
          fileName: _buildFileName(
            suffix: 'session-share',
            extension: videoExt,
          ),
        );
        attachments.add(
          XFile(
            videoFile.path,
            mimeType: _mimeTypeForExtension(videoExt),
          ),
        );
      } catch (_) {
        // Ignore failures so we can still share other assets.
      }

      try {
        final audioExt = _extensionFromUrl(
          widget.experience.audioUrl,
          fallback: '.m4a',
        );
        final audioFile = await _assetService.cacheForShare(
          url: widget.experience.audioUrl,
          fileName: _buildFileName(
            suffix: 'narration-share',
            extension: audioExt,
          ),
        );
        attachments.add(
          XFile(
            audioFile.path,
            mimeType: _mimeTypeForExtension(audioExt),
          ),
        );
      } catch (_) {
        // Ignore failures so long as we have something to share.
      }

      // Generate and add story card
      try {
        final storyCard = await _storyCardService.generateStoryCard(
          experience: widget.experience,
          customMessage: 'A bedtime story just for you',
        );
        attachments.add(
          XFile(
            storyCard.path,
            mimeType: 'image/png',
          ),
        );
      } catch (_) {
        // Ignore story card generation failures
      }

      if (attachments.isEmpty) {
        throw Exception('No files available');
      }

      await Share.shareXFiles(
        attachments,
        subject: 'Dream Flow session: ${widget.experience.theme}',
        text:
            'Take a look at my Dream Flow session "${widget.experience.theme}". Created with Dream Flow - AI-powered bedtime stories.',
      );
    } catch (_) {
      _showSnack('Unable to share session assets.', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isSharingSession = false);
    }
  }

  Future<bool> _ensurePermission(_PermissionScope scope) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final permissions = <Permission>[];
    if (scope == _PermissionScope.gallery) {
      if (Platform.isIOS) {
        permissions.add(Permission.photos);
      } else {
        permissions.addAll([Permission.photos, Permission.storage]);
      }
    } else {
      if (Platform.isAndroid) {
        permissions.add(Permission.storage);
      }
    }

    if (permissions.isEmpty) {
      return true;
    }

    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isGranted) {
        return true;
      }

      final result = await permission.request();
      if (result.isGranted) {
        return true;
      }

      if (result.isPermanentlyDenied) {
        _showPermissionSnack();
        return false;
      }
    }

    _showSnack('Storage permission denied.', isError: true);
    return false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.redAccent : const Color(0xFF16A34A),
      ),
    );
  }

  void _showPermissionSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please enable storage access in Settings.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  String _buildFileName({
    required String suffix,
    required String extension,
  }) {
    final sanitized = widget.experience.theme
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safeBase = sanitized.isEmpty ? 'dream_flow' : sanitized;
    final safeExtension = extension.startsWith('.') ? extension : '.$extension';
    return '$safeBase-$suffix$safeExtension';
  }

  String _extensionFromUrl(String url, {required String fallback}) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final ext = p.extension(uri.path);
      if (ext.isNotEmpty) {
        return ext;
      }
    }
    return fallback.startsWith('.') ? fallback : '.$fallback';
  }

  String _mimeTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.m4a':
        return 'audio/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  Widget _buildStoryCard(List<String> paragraphs) {
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
          const SizedBox(height: 12),
          ...paragraphs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                p,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFramesGallery(List<String> frames) {
    if (frames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.panorama_fish_eye, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              'Scene postcards',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: frames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final frame = frames[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.network(
                    frame,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                    return Container(
                      color: Colors.white.withValues(alpha: 0.04),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAudioControls() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                  ),
                ),
                child:
                    const Icon(Icons.spatial_audio_off, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAudioPlaying ? 'Narration playing' : 'Narration paused',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gentle ${_isAudioPlaying ? 'looping' : 'ready'} voice linked to your profile.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 32,
                icon: Icon(
                  _isAudioPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Colors.white,
                ),
                onPressed: () async {
                  if (_isAudioPlaying) {
                    await _audioService.stop();
                    setState(() => _isAudioPlaying = false);
                    // Show feedback modal if user stopped playback and hasn't shown it yet
                    if (!_hasShownFeedback && _playbackStartTime != null) {
                      final playbackDuration = DateTime.now().difference(_playbackStartTime!);
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
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          _buildOfflineToggle(),
        ],
      ),
    );
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
    _chewieController?.dispose();
    _videoController?.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineState() async {
    try {
      final hasAudioCache =
          await _audioService.hasCachedNarration(widget.experience.audioUrl);
      final hasVideoCache =
          await _videoService.hasCachedVideo(widget.experience.videoUrl);
      if (!mounted) return;
      setState(() {
        _hasOfflineNarration = hasAudioCache;
        _hasOfflineVideo = hasVideoCache;
        _offlineEnabled = hasAudioCache || hasVideoCache;
      });
    } catch (_) {
      // Ignore failures when checking cache.
    }
  }

  Future<void> _cacheVideoInBackground(String videoUrl) async {
    if (_isCachingVideo) return;
    
    setState(() => _isCachingVideo = true);
    
    try {
      await _videoService.cacheVideo(videoUrl);
      await _videoService.trimCacheIfNeeded();
      if (!mounted) return;
      setState(() {
        _hasOfflineVideo = true;
        _isCachingVideo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCachingVideo = false;
        // Don't show error for background caching
      });
    }
  }

  Future<void> _handleOfflineToggle(bool value) async {
    setState(() {
      _offlineError = null;
      _offlineEnabled = value;
      _isCachingNarration = true;
      _isCachingVideo = true;
    });

    if (value) {
      try {
        // Cache both audio and video
        await Future.wait([
          _audioService.cacheNarration(widget.experience.audioUrl),
          _videoService.cacheVideo(widget.experience.videoUrl),
        ]);
        await _audioService.trimCacheIfNeeded();
        await _videoService.trimCacheIfNeeded();
        if (!mounted) return;
        setState(() {
          _hasOfflineNarration = true;
          _hasOfflineVideo = true;
          _isCachingNarration = false;
          _isCachingVideo = false;
        });
        if (_isAudioPlaying) {
          await _restartAudio(preferCache: true);
        }
        // Reload video if it's ready
        if (_isVideoReady) {
          await _initializeExperience();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _offlineEnabled = false;
          _offlineError = 'Failed to download content for offline use.';
          _isCachingNarration = false;
          _isCachingVideo = false;
        });
      }
    } else {
      try {
        await Future.wait([
          _audioService.deleteCachedNarration(widget.experience.audioUrl),
          _videoService.deleteCachedVideo(widget.experience.videoUrl),
        ]);
        if (!mounted) return;
        setState(() {
          _hasOfflineNarration = false;
          _hasOfflineVideo = false;
          _isCachingNarration = false;
          _isCachingVideo = false;
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
    if (_isCachingNarration || _isCachingVideo) {
      if (_isCachingNarration && _isCachingVideo) {
        return 'Preparing content for offline playback...';
      } else if (_isCachingNarration) {
        return 'Preparing narration for offline playback...';
      } else {
        return 'Preparing video for offline playback...';
      }
    }
    if (_offlineEnabled) {
      if (_hasOfflineNarration && _hasOfflineVideo) {
        return 'Content stored on device. No data needed.';
      } else if (_hasOfflineNarration) {
        return 'Narration stored on device. No data needed.';
      } else {
        return 'Video stored on device. No data needed.';
      }
    }
    if (_hasOfflineNarration || _hasOfflineVideo) {
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
    if (_hasShownFeedback || widget.experience.sessionId == null) {
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

}

enum _PermissionScope { downloads, gallery }
