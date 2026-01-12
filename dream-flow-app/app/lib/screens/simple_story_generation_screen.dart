import 'package:flutter/material.dart';
import '../core/story_service.dart';
import 'session_screen.dart';

class SimpleStoryGenerationScreen extends StatefulWidget {
  final StoryGenerationRequest request;

  const SimpleStoryGenerationScreen({
    super.key,
    required this.request,
  });

  @override
  State<SimpleStoryGenerationScreen> createState() => _SimpleStoryGenerationScreenState();
}

class _SimpleStoryGenerationScreenState extends State<SimpleStoryGenerationScreen> {
  bool _isGenerating = false;
  bool _isDone = false;
  String _storyText = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateStory();
  }

  Future<void> _generateStory() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      print('🚀 Simple story generation starting...');
      
      // Create story directly without complex backend calls
      final storyText = _createPersonalizedStory(
        widget.request.prompt,
        widget.request.theme,
        widget.request.profile?.toJson(),
      );

      print('✅ Story created: ${storyText.length} characters');

      // Simulate progressive display
      final sentences = storyText
          .split(RegExp(r'[.!?]+\s*'))
          .where((s) => s.trim().isNotEmpty)
          .toList();

      for (int i = 0; i < sentences.length; i++) {
        if (!mounted) break;
        
        final sentence = sentences[i].trim();
        if (sentence.isEmpty) continue;

        final chunk = i < sentences.length - 1 ? '$sentence. ' : sentence;
        setState(() {
          _storyText += chunk;
        });

        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!mounted) return;

      setState(() {
        _isDone = true;
        _isGenerating = false;
      });

      // Auto-navigate after showing complete story
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;

      final experience = StoryExperience(
        storyText: storyText,
        theme: widget.request.theme,
        audioUrl: '',
        frames: <String>[],
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionScreen(experience: experience),
        ),
      );

    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = 'Story creation failed: ${e.toString()}';
      });
    }
  }

  String _createPersonalizedStory(String prompt, String theme, Map<String, dynamic>? profile) {
    final mood = profile?['mood'] ?? 'peaceful';
    final routine = profile?['routine'] ?? 'bedtime';
    final preferences = (profile?['preferences'] as List?)?.map((e) => e.toString()).join(', ') ?? 'adventure';
    final favoriteCharacters = (profile?['favorite_characters'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    final character = favoriteCharacters.isNotEmpty 
        ? favoriteCharacters.first 
        : _getThemeCharacter(theme);

    return '''In the magical realm of $theme, $character discovered something wonderful about "$prompt".

The adventure began on a $mood evening, during a peaceful $routine. With interests in $preferences, $character embarked on a journey that would touch their heart.

As the story unfolded, $character learned that every dream holds a special truth. Through gentle discoveries and moments of wonder, they found that the most precious treasures are the ones we carry in our hearts.

The soft glow of twilight reminded $character that some stories never truly end—they become part of who we are, living on in our dreams and memories.

And so, with a smile of contentment and eyes growing peacefully heavy, $character settled into the sweetest dreams, knowing that tomorrow would bring new adventures and endless possibilities.''';
  }

  String _getThemeCharacter(String theme) {
    final characters = {
      'Ocean Dreams': 'Luna the dolphin',
      'Forest Friends': 'Oliver the wise owl',
      'Space Explorer': 'Captain Maya',
      'Study Grove': 'Sage the reading fox',
      'Enchanted Garden': 'Lily the fairy',
      'Mountain Adventure': 'Scout the mountain goat',
    };
    return characters[theme] ?? 'a gentle friend';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05020C),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF120E2B), Color(0xFF07040F)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Creating Your Story',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Progress indicator
                if (_isGenerating) ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Weaving your story...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ] else if (_isDone) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Story complete!',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // Story text display
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _storyText.isEmpty ? 'Your personalized story will appear here...' : _storyText,
                        style: TextStyle(
                          color: _storyText.isEmpty ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _generateStory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}