import 'package:flutter/material.dart';
import '../services/family_library_service.dart';
import '../core/auth_service.dart';
import '../core/story_service.dart';
import '../widgets/family_library_widget.dart';
import 'session_screen.dart';

class FamilyLibraryScreen extends StatefulWidget {
  final String? childProfileId;

  const FamilyLibraryScreen({
    super.key,
    this.childProfileId,
  });

  @override
  State<FamilyLibraryScreen> createState() => _FamilyLibraryScreenState();
}

class _FamilyLibraryScreenState extends State<FamilyLibraryScreen> {
  final FamilyLibraryService _familyLibraryService = FamilyLibraryService();
  final AuthService _authService = AuthService();
  final StoryService _storyService = StoryService();

  List<StoryExperience> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyStories();
  }

  Future<void> _loadFamilyStories() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stories = await _familyLibraryService.getFamilyStories(
        parentUserId: user.id,
        childProfileId: widget.childProfileId,
      );

      setState(() {
        _stories = stories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamilyStories,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: FamilyLibraryWidget(
            stories: _stories,
            isLoading: _isLoading,
            onStoryTap: (story) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionScreen(experience: story),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

