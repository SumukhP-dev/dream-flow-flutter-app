import 'package:flutter/material.dart';
import '../core/story_service.dart' show StoryProfileInput, StoryGenerationRequest;
import '../shared/sentry_service.dart';
import '../widgets/kid_theme_selector.dart';
import '../widgets/kid_loading_indicator.dart';
import '../widgets/kid_friendly_error_widget.dart';
import '../widgets/kid_progress_indicator.dart';
import '../widgets/character_selector_widget.dart';
import 'simple_story_generation_screen.dart';

class KidCreateStoryScreen extends StatefulWidget {
  final String? childProfileId;
  final int? childAge;

  const KidCreateStoryScreen({
    super.key,
    this.childProfileId,
    this.childAge,
  });

  @override
  State<KidCreateStoryScreen> createState() => _KidCreateStoryScreenState();
}

class _KidCreateStoryScreenState extends State<KidCreateStoryScreen> {
  final TextEditingController _promptCtrl = TextEditingController();

  // Simplified themes for kids
  final List<ThemeOption> _themes = [
    // Calm Focus
    const ThemeOption(
      title: 'Study Grove',
      emoji: '🌿',
      category: 'Calm Focus',
      color: Color(0xFF4ECDC4),
    ),
    const ThemeOption(
      title: 'Focus Falls',
      emoji: '💧',
      category: 'Calm Focus',
      color: Color(0xFF06B6D4),
    ),
    const ThemeOption(
      title: 'Zen Garden',
      emoji: '🪨',
      category: 'Calm Focus',
      color: Color(0xFF8B5CF6),
    ),
    // Cozy Family
    const ThemeOption(
      title: 'Family Hearth',
      emoji: '🔥',
      category: 'Cozy Family',
      color: Color(0xFFFF6B6B),
    ),
    const ThemeOption(
      title: 'Campfire Chronicles',
      emoji: '🏕️',
      category: 'Cozy Family',
      color: Color(0xFFFFD93D),
    ),
    const ThemeOption(
      title: 'Storybook Nook',
      emoji: '📚',
      category: 'Cozy Family',
      color: Color(0xFFEC4899),
    ),
    // Solo Unwind
    const ThemeOption(
      title: 'Oceanic Serenity',
      emoji: '🌊',
      category: 'Solo Unwind',
      color: Color(0xFF0EA5E9),
    ),
    const ThemeOption(
      title: 'Starlit Sanctuary',
      emoji: '✨',
      category: 'Solo Unwind',
      color: Color(0xFF8B5CF6),
    ),
    const ThemeOption(
      title: 'Whispering Woods',
      emoji: '🌲',
      category: 'Solo Unwind',
      color: Color(0xFF16A34A),
    ),
    const ThemeOption(
      title: 'Aurora Dreams',
      emoji: '🌌',
      category: 'Solo Unwind',
      color: Color(0xFF06B6D4),
    ),
  ];

  // Voice options with emoji
  final List<Map<String, dynamic>> _voices = [
    {'name': 'alloy', 'emoji': '🎤', 'label': 'Alloy'},
    {'name': 'luna', 'emoji': '🌙', 'label': 'Luna'},
    {'name': 'verse', 'emoji': '🎵', 'label': 'Verse'},
  ];

  ThemeOption? _selectedTheme;
  String _selectedVoice = 'alloy';
  String? _selectedCharacterId;
  bool _isGenerating = false;
  String? _errorMessage;
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    _selectedTheme = _themes.first;
    _selectedVoice = _voices.first['name'] as String;
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    FocusScope.of(context).unfocus();

    if (_promptCtrl.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Tell us what kind of story you want!';
      });
      return;
    }

    if (_selectedTheme == null) {
      setState(() {
        _errorMessage = 'Please choose a story world!';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _currentStep = 2;
    });

    // Pre-filled defaults for kids (hidden from UI)
    final profile = StoryProfileInput(
      mood: 'Happy and excited',
      routine: 'Bedtime story',
      preferences: ['friendship', 'gentle animals'],
      favoriteCharacters: _selectedCharacterId != null ? [_selectedCharacterId!] : [],
      calmingElements: ['starlight', 'soft clouds'],
    );

    final request = StoryGenerationRequest(
      prompt: _promptCtrl.text.trim(),
      theme: _selectedTheme!.title,
      // Approx chars (~180 words) for a shorter kid-friendly story.
      targetLength: 954,
      numScenes: 4, // Fixed for kids
      voice: _selectedVoice,
      profile: profile,
      primaryLanguage: 'en', // Default to English for kids
      childProfileId: widget.childProfileId,
      childAge: widget.childAge,
    );

    try {
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SimpleStoryGenerationScreen(request: request),
        ),
      );
    } catch (error) {
      await SentryService.captureException(
        error,
        extra: {
          'theme': _selectedTheme!.title,
          'prompt': _promptCtrl.text.trim(),
          'child_age': widget.childAge,
        },
      );
      setState(() {
        _errorMessage = 'Oops! Something went wrong. Let\'s try again!';
        _isGenerating = false;
        _currentStep = 1;
      });
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
        title: const Text(
          'Create Your Story',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
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
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isGenerating) ...[
                    const SizedBox(height: 40),
                    const KidLoadingIndicator(
                      message: 'Creating your magical story...',
                      size: 100,
                    ),
                    const SizedBox(height: 40),
                  ] else ...[
                    // Progress indicator
                    KidProgressIndicator(
                      currentStep: _currentStep,
                      totalSteps: 4,
                      stepEmojis: const ['✨', '👤', '🌟', '⭐'],
                    ),
                    const SizedBox(height: 32),
                    // Step 1: Theme Selection
                    KidThemeSelector(
                      themes: _themes,
                      selectedTheme: _selectedTheme,
                      onThemeSelected: (theme) {
                        setState(() {
                          _selectedTheme = theme;
                          _currentStep = 2;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    // Step 2: Character Selection (optional)
                    if (_currentStep >= 2) ...[
                      const Text(
                        'Choose Your Character (Optional)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CharacterSelectorWidget(
                        selectedCharacterId: _selectedCharacterId,
                        childProfileId: widget.childProfileId,
                        onCharacterSelected: (characterId) {
                          setState(() {
                            _selectedCharacterId = characterId;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                    // Step 3: Prompt Input
                    const Text(
                      'What Story Do You Want?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _promptCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: InputDecoration(
                        hintText: 'Tell us about your story...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFF8B5CF6),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(20),
                      ),
                      onChanged: (value) {
                        if (value.trim().isNotEmpty && _currentStep < 4) {
                          setState(() {
                            _currentStep = 4;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    // Step 4: Voice Selection
                    const Text(
                      'Choose a Voice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _voices.map((voice) {
                        final isSelected = _selectedVoice == voice['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedVoice = voice['name'] as String;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.05),
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
                                  voice['emoji'] as String,
                                  style: const TextStyle(fontSize: 40),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  voice['label'] as String,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                    // Create Story Button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _handleGenerate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                          elevation: 8,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Create Story!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      KidFriendlyErrorWidget(
                        message: _errorMessage!,
                        type: KidFriendlyErrorType.error,
                        onRetry: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

