import 'package:flutter/material.dart';
import '../core/story_service.dart';
import '../widgets/kid_friendly_error_widget.dart';
import '../widgets/kid_empty_state_widget.dart';
import '../widgets/kid_loading_indicator.dart';
import '../widgets/parental_control_badge.dart';
import 'story_detail_screen.dart';

class KidStoryDiscoveryScreen extends StatefulWidget {
  final String? initialAgeRating;
  final int? childAge;

  const KidStoryDiscoveryScreen({
    super.key,
    this.initialAgeRating,
    this.childAge,
  });

  @override
  State<KidStoryDiscoveryScreen> createState() =>
      _KidStoryDiscoveryScreenState();
}

class _KidStoryDiscoveryScreenState extends State<KidStoryDiscoveryScreen> {
  final StoryService _storyService = StoryService();
  List<PublicStoryItem> _stories = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  String? _selectedTheme;
  String? _selectedAgeRating;
  String? _errorMessage;

  // Visual category filters
  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'emoji': '🌟', 'theme': null},
    {'name': 'Family', 'emoji': '🔥', 'theme': 'Family Hearth'},
    {'name': 'Nature', 'emoji': '🌿', 'theme': 'Study Grove'},
    {'name': 'Ocean', 'emoji': '🌊', 'theme': 'Oceanic Serenity'},
    {'name': 'Space', 'emoji': '✨', 'theme': 'Starlit Sanctuary'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialAgeRating != null) {
      _selectedAgeRating = widget.initialAgeRating;
    } else if (widget.childAge != null) {
      // Auto-select age rating based on child age
      if (widget.childAge! <= 5) {
        _selectedAgeRating = 'G';
      } else if (widget.childAge! <= 8) {
        _selectedAgeRating = 'PG';
      } else if (widget.childAge! <= 12) {
        _selectedAgeRating = 'PG-13';
      }
    }
    _loadStories();
  }

  Future<void> _loadStories({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (refresh) {
        _offset = 0;
        _stories = [];
        _hasMore = true;
      }
    });

    try {
      final response = await _storyService.getPublicStories(
        limit: _limit,
        offset: _offset,
        theme: _selectedTheme,
        ageRating: _selectedAgeRating,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _stories = response.stories;
          } else {
            _stories.addAll(response.stories);
          }
          _offset += response.stories.length;
          _hasMore = response.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Only show error if it's not a 401 (missing auth is expected for public stories)
          final errorStr = e.toString();
          if (!errorStr.contains('401') &&
              !errorStr.contains('Missing Authorization')) {
            _errorMessage = 'Oops! Couldn\'t load stories. Let\'s try again!';
          }
        });
      }
    }
  }

  void _applyCategoryFilter(Map<String, dynamic> category) {
    setState(() {
      _selectedTheme = category['theme'] as String?;
    });
    _loadStories(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05020C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Discover Stories',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
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
            Column(
              children: [
                // Visual category filters
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedTheme == category['theme'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => _applyCategoryFilter(category),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 100,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    category['emoji'] as String,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    category['name'] as String,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Stories grid
                Expanded(
                  child: _isLoading && _stories.isEmpty
                      ? const Center(
                          child: KidLoadingIndicator(
                            message: 'Loading stories...',
                          ),
                        )
                      : _errorMessage != null && _stories.isEmpty
                          ? Center(
                              child: KidFriendlyErrorWidget(
                                message: _errorMessage!,
                                type: KidFriendlyErrorType.error,
                                onRetry: () => _loadStories(refresh: true),
                              ),
                            )
                          : _stories.isEmpty
                              ? KidEmptyStateWidget(
                                  emoji: '📚',
                                  message:
                                      'No stories found!\nTry a different category 🌟',
                                  actionLabel: 'Refresh',
                                  onAction: () => _loadStories(refresh: true),
                                )
                              : RefreshIndicator(
                                  onRefresh: () => _loadStories(refresh: true),
                                  color: const Color(0xFF8B5CF6),
                                  child: GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.7,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    itemCount:
                                        _stories.length + (_hasMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == _stories.length) {
                                        _loadStories();
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        );
                                      }
                                      final story = _stories[index];
                                      return _buildKidStoryCard(story);
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKidStoryCard(PublicStoryItem story) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryDetailScreen(sessionId: story.sessionId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                height: 140,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.05),
                child: story.thumbnailUrl != null
                    ? Image.network(
                        story.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              '📖',
                              style: const TextStyle(fontSize: 48),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text('📖', style: TextStyle(fontSize: 48)),
                      ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          story.theme,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ParentalControlBadge(
                        ageRating:
                            story.ageRating != 'all' ? story.ageRating : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    story.prompt,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        color: story.isLiked
                            ? Colors.red
                            : Colors.white.withValues(alpha: 0.5),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${story.likeCount}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
