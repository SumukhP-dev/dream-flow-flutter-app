import 'package:flutter/material.dart';
import '../core/story_service.dart';
import '../widgets/story_card.dart';
import 'story_detail_screen.dart';

class StoryDiscoveryScreen extends StatefulWidget {
  final String? initialAgeRating;

  const StoryDiscoveryScreen({
    super.key,
    this.initialAgeRating,
  });

  @override
  State<StoryDiscoveryScreen> createState() => _StoryDiscoveryScreenState();
}

class _StoryDiscoveryScreenState extends State<StoryDiscoveryScreen> {
  final StoryService _storyService = StoryService();
  List<PublicStoryItem> _stories = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  String? _selectedTheme;
  String? _selectedAgeRating;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialAgeRating != null) {
      _selectedAgeRating = widget.initialAgeRating;
    }
    _loadStories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStories({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
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
        });
        // Only show error if it's not a 401 (missing auth is expected for public stories)
        final errorStr = e.toString();
        if (!errorStr.contains('401') &&
            !errorStr.contains('Missing Authorization')) {
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

  void _applyFilters() {
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and filters
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search stories...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter chips
                  Row(
                    children: [
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedTheme,
                          decoration: InputDecoration(
                            labelText: 'Theme',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          dropdownColor: const Color(0xFF1E1B2E),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Themes',
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const DropdownMenuItem(
                              value: 'Study Grove',
                              child: Text('Study Grove',
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const DropdownMenuItem(
                              value: 'Family Hearth',
                              child: Text('Family Hearth',
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const DropdownMenuItem(
                              value: 'Oceanic Serenity',
                              child: Text('Oceanic Serenity',
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedTheme = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedAgeRating,
                          decoration: InputDecoration(
                            labelText: 'Age Rating',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          dropdownColor: const Color(0xFF1E1B2E),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('All Ages',
                                  overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Ages',
                                  overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: '5+',
                              child:
                                  Text('5+', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: '7+',
                              child:
                                  Text('7+', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: '10+',
                              child:
                                  Text('10+', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: '13+',
                              child:
                                  Text('13+', overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedAgeRating = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Stories grid
            Expanded(
              child: _isLoading && _stories.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _stories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '📚',
                                style: const TextStyle(fontSize: 64),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No stories found',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Try adjusting your filters or check back later for new stories!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadStories(refresh: true),
                          color: const Color(0xFF8B5CF6),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _stories.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _stories.length) {
                                // Load more trigger
                                _loadStories();
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                );
                              }
                              final story = _stories[index];
                              return StoryCard(
                                story: story,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StoryDetailScreen(
                                        sessionId: story.sessionId,
                                      ),
                                    ),
                                  );
                                },
                                onLike: () async {
                                  try {
                                    final liked = await _storyService
                                        .likeStory(story.sessionId);
                                    setState(() {
                                      _stories[index] = PublicStoryItem(
                                        sessionId: story.sessionId,
                                        theme: story.theme,
                                        prompt: story.prompt,
                                        storyText: story.storyText,
                                        thumbnailUrl: story.thumbnailUrl,
                                        ageRating: story.ageRating,
                                        likeCount: liked
                                            ? story.likeCount + 1
                                            : story.likeCount - 1,
                                        createdAt: story.createdAt,
                                        isLiked: liked,
                                      );
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Failed to like story: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                onReport: () {
                                  _showReportDialog(story);
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(PublicStoryItem story) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text(
          'Report Story',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Why are you reporting this story?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _storyService.reportStory(
                  sessionId: story.sessionId,
                  reason: 'inappropriate',
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Thank you for reporting. We\'ll review this story.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
