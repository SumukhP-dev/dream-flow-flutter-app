import 'package:flutter/material.dart';
import '../core/story_service.dart' show StoryService, StoryDetail, StoryServiceException;

class StoryDetailScreen extends StatefulWidget {
  final String sessionId;

  const StoryDetailScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final StoryService _storyService = StoryService();
  StoryDetail? _story;
  bool _isLoading = true;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _loadStoryDetails();
  }

  Future<void> _loadStoryDetails() async {
    try {
      final story = await _storyService.getStoryDetails(widget.sessionId);
      if (mounted) {
        setState(() {
          _story = story;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load story: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_story == null || _isLiking) return;

    setState(() {
      _isLiking = true;
    });

    try {
      final liked = await _storyService.likeStory(_story!.sessionId);
      if (mounted) {
        setState(() {
          _story = StoryDetail(
            sessionId: _story!.sessionId,
            theme: _story!.theme,
            prompt: _story!.prompt,
            storyText: _story!.storyText,
            thumbnailUrl: _story!.thumbnailUrl,
            frames: _story!.frames,
            audioUrl: _story!.audioUrl,
            ageRating: _story!.ageRating,
            likeCount: liked ? _story!.likeCount + 1 : _story!.likeCount - 1,
            isLiked: liked,
            isPublic: _story!.isPublic,
            isApproved: _story!.isApproved,
            createdAt: _story!.createdAt,
            canShare: _story!.canShare,
          );
          _isLiking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like story: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareStory() async {
    if (_story == null) return;

    try {
      await _storyService.shareStory(
        sessionId: _story!.sessionId,
        ageRating: _story!.ageRating,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story shared! It will be visible after moderation.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStoryDetails(); // Refresh to get updated status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share story: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_story?.canShare == true)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareStory,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _story == null
                ? const Center(
                    child: Text(
                      'Story not found',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail
                        if (_story!.thumbnailUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              _story!.thumbnailUrl!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Theme and metadata
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _story!.theme,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _story!.prompt,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Like button and age rating
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _story!.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _story!.isLiked
                                    ? Colors.red
                                    : Colors.white70,
                              ),
                              onPressed: _isLiking ? null : _toggleLike,
                            ),
                            Text(
                              '${_story!.likeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _story!.ageRating,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Story text
                        Text(
                          _story!.storyText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Privacy status
                        if (_story!.isPublic)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _story!.isApproved
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _story!.isApproved
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _story!.isApproved
                                      ? Icons.check_circle
                                      : Icons.pending,
                                  color: _story!.isApproved
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _story!.isApproved
                                        ? 'This story is public and visible to others'
                                        : 'This story is pending moderation review',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

