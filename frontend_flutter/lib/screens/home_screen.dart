import 'package:flutter/material.dart';

import '../services/story_service.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../services/sentry_service.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StoryService _storyService = StoryService();
  final AuthService _authService = AuthService();
  final PreferencesService _preferencesService = PreferencesService();
  List<SessionHistoryItem> _recentSessions = [];
  bool _isLoadingHistory = false;
  final TextEditingController _promptCtrl = TextEditingController(
    text:
        'Tell me a bedtime story about floating lanterns guiding a sleepy fox.',
  );
  final TextEditingController _moodCtrl = TextEditingController();
  final TextEditingController _routineCtrl = TextEditingController();
  final TextEditingController _favoritesCtrl = TextEditingController();
  final TextEditingController _calmingCtrl = TextEditingController();

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

  final List<String> _preferenceOptions = [
    'space travel',
    'friendship',
    'underwater',
    'gentle animals',
    'music',
    'floating islands',
    'glow blooms',
  ];

  final List<String> _voices = ['alloy', 'luna', 'verse'];

  late String _selectedTheme;
  late String _selectedVoice;
  final Set<String> _selectedPreferences = <String>{};
  double _targetLength = 420;
  int _sceneCount = 4;
  bool _isGenerating = false;
  String? _errorMessage;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _selectedTheme = _featuredWorlds.first['title']!;
    _selectedVoice = _voices.first;
    _loadRecentSessions();
    _loadProfile();
  }

  /// Load profile data from Supabase/SharedPreferences and hydrate inputs
  Future<void> _loadProfile() async {
    try {
      final profile = await _preferencesService.loadProfile();

      if (profile != null && mounted) {
        setState(() {
          // Hydrate mood
          if (profile['mood'] != null) {
            _moodCtrl.text = profile['mood'] as String;
          } else {
            _moodCtrl.text = 'Sleepy and hopeful';
          }

          // Hydrate ritual/routine
          if (profile['routine'] != null) {
            _routineCtrl.text = profile['routine'] as String;
          } else {
            _routineCtrl.text = 'Warm bath then story time';
          }

          // Hydrate favorite characters
          if (profile['favorite_characters'] != null) {
            final chars = profile['favorite_characters'] as List<dynamic>;
            _favoritesCtrl.text = chars.join(', ');
          } else {
            _favoritesCtrl.text = 'Nova the fox, Orion the owl';
          }

          // Hydrate calming elements
          if (profile['calming_elements'] != null) {
            final elements = profile['calming_elements'] as List<dynamic>;
            _calmingCtrl.text = elements.join(', ');
          } else {
            _calmingCtrl.text = 'starlight, lavender mist, soft clouds';
          }

          // Hydrate preferences
          if (profile['preferences'] != null) {
            final prefs = profile['preferences'] as List<dynamic>;
            _selectedPreferences.clear();
            _selectedPreferences.addAll(
                prefs.map((e) => e.toString()).where((p) => _preferenceOptions.contains(p)));
          } else {
            // Default preferences if none saved
            _selectedPreferences.addAll({'friendship', 'gentle animals'});
          }

          _isLoadingProfile = false;
        });
      } else {
        // No profile found, use defaults
        if (mounted) {
          setState(() {
            _moodCtrl.text = 'Sleepy and hopeful';
            _routineCtrl.text = 'Warm bath then story time';
            _favoritesCtrl.text = 'Nova the fox, Orion the owl';
            _calmingCtrl.text = 'starlight, lavender mist, soft clouds';
            _selectedPreferences.addAll({'friendship', 'gentle animals'});
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      // Error loading profile, use defaults
      if (mounted) {
        setState(() {
          _moodCtrl.text = 'Sleepy and hopeful';
          _routineCtrl.text = 'Warm bath then story time';
          _favoritesCtrl.text = 'Nova the fox, Orion the owl';
          _calmingCtrl.text = 'starlight, lavender mist, soft clouds';
          _selectedPreferences.addAll({'friendship', 'gentle animals'});
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadRecentSessions() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final sessions = await _storyService.getHistory(
        userId: user.id,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _recentSessions = sessions;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
      // Silently fail - history is not critical
      print('Failed to load recent sessions: $e');
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _moodCtrl.dispose();
    _routineCtrl.dispose();
    _favoritesCtrl.dispose();
    _calmingCtrl.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(
                          'Story Seed',
                          'Describe what you want to feel or explore tonight.',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _promptCtrl,
                          label: 'Prompt',
                          maxLines: 3,
                          icon: Icons.auto_stories,
                        ),
                        const SizedBox(height: 12),
                        _buildThemeSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(
                          'Evening Profile',
                          'Weaves your mood, rituals, and cozy anchors into the narrative.',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _moodCtrl,
                                label: 'Current mood',
                                icon: Icons.favorite_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _routineCtrl,
                                label: 'Nightly ritual',
                                icon: Icons.self_improvement,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _favoritesCtrl,
                          label: 'Favorite characters (comma separated)',
                          icon: Icons.people_alt_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _calmingCtrl,
                          label: 'Calming elements (comma separated)',
                          icon: Icons.blur_on_rounded,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sensory preferences',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _preferenceOptions.map((pref) {
                            final isSelected = _selectedPreferences.contains(
                              pref,
                            );
                            return ChoiceChip(
                              label: Text(pref),
                              selected: isSelected,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              selectedColor: const Color(0xFF8B5CF6),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                              onSelected: (_) => _togglePreference(pref),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(
                          'Story Controls',
                          'Tune pacing, length, and scenes for the experience.',
                        ),
                        const SizedBox(height: 16),
                        _buildSliderRow(
                          label: 'Story length',
                          valueLabel: '${_targetLength.round()} words',
                          child: Slider(
                            value: _targetLength,
                            min: 250,
                            max: 600,
                            divisions: 7,
                            label: _targetLength.round().toString(),
                            onChanged: (value) {
                              setState(() => _targetLength = value);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSliderRow(
                          label: 'Scenes',
                          valueLabel: '$_sceneCount visuals',
                          child: Slider(
                            value: _sceneCount.toDouble(),
                            min: 2,
                            max: 6,
                            divisions: 4,
                            label: _sceneCount.toString(),
                            onChanged: (value) {
                              setState(() => _sceneCount = value.round());
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.mic_rounded,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF1E1B2E),
                                initialValue: _selectedVoice,
                                decoration: InputDecoration(
                                  labelText: 'Narration voice',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ),
                                iconEnabledColor: Colors.white,
                                style: const TextStyle(color: Colors.white),
                                items: _voices
                                    .map(
                                      (voice) => DropdownMenuItem(
                                        value: voice,
                                        child: Text(voice),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedVoice = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Featured worlds',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'One from each experience: Calm Focus, Cozy Family, Solo Unwind',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 170,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _featuredWorlds.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final preset = _featuredWorlds[index];
                        return _buildPresetCard(preset);
                      },
                    ),
                  ),
                  if (_recentSessions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Recent sessions',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Continue your dream journey',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: _isLoadingHistory
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _recentSessions.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                final session = _recentSessions[index];
                                return _buildSessionCard(session);
                              },
                            ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'Generate Story',
                    button: true,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                    ),
                    onPressed: _isGenerating ? null : _handleGenerate,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isGenerating)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        else
                          const Icon(Icons.auto_awesome, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          _isGenerating
                              ? 'Summoning your dream...'
                              : 'Generate Nightly Story',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shield_moon, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Soothing-mode guardrails active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
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

  Widget _buildCardTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    final categories = [
      {'name': 'Calm Focus', 'key': 'focus', 'icon': Icons.psychology},
      {'name': 'Cozy Family', 'key': 'family', 'icon': Icons.family_restroom},
      {'name': 'Solo Unwind', 'key': 'unwind', 'icon': Icons.spa},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tonight\'s theme',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...categories.map((category) {
          final categoryThemes = _allThemes
              .where((theme) => theme['category'] == category['key'])
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: categoryThemes.map((preset) {
                  final isSelected = _selectedTheme == preset['title'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTheme = preset['title']!;
                        _promptCtrl.text = preset['description']!;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8B5CF6)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 1.6,
                        ),
                        color: isSelected
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.03),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            preset['emoji'] ?? '✨',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            preset['title']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueLabel,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildPresetCard(Map<String, String> preset) {
    return GestureDetector(
      onTap: () => _applyPreset(preset),
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

  void _togglePreference(String pref) {
    setState(() {
      if (_selectedPreferences.contains(pref)) {
        _selectedPreferences.remove(pref);
      } else {
        _selectedPreferences.add(pref);
      }
    });
  }

  void _applyPreset(Map<String, String> preset) {
    setState(() {
      _selectedTheme = preset['title']!;
      _promptCtrl.text = preset['description']!;
      _moodCtrl.text = preset['mood']!;
      _routineCtrl.text = preset['routine']!;
    });
  }

  Widget _buildSessionCard(SessionHistoryItem session) {
    // Find theme emoji from all themes
    final themeData = _allThemes.firstWhere(
      (theme) => theme['title'] == session.theme,
      orElse: () => {'emoji': '✨', 'title': session.theme},
    );

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to session detail screen when implemented
        // For now, we can show a snackbar or navigate to a session view
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening session: ${session.theme}'),
            duration: const Duration(seconds: 1),
          ),
        );
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
            // Thumbnail or placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 90,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.05),
                child: session.thumbnailUrl != null
                    ? Image.network(
                        session.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildThumbnailPlaceholder(themeData['emoji']!);
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
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }

  Future<void> _handleGenerate() async {
    FocusScope.of(context).unfocus();

    if (_promptCtrl.text.trim().isEmpty) {
      setState(
        () => _errorMessage = 'Please describe what kind of story you want.',
      );
      return;
    }
    if (_moodCtrl.text.trim().isEmpty || _routineCtrl.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            'Share both your mood and nightly ritual for better personalization.',
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final profile = StoryProfileInput(
      mood: _moodCtrl.text.trim(),
      routine: _routineCtrl.text.trim(),
      preferences: _selectedPreferences.toList(),
      favoriteCharacters: _favoritesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .toList(),
      calmingElements: _calmingCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .toList(),
    );

    // Save profile data to Supabase/SharedPreferences
    try {
      await _preferencesService.saveProfile(
        mood: _moodCtrl.text.trim(),
        ritual: _routineCtrl.text.trim(),
        preferences: _selectedPreferences.toList(),
        favoriteCharacters: profile.favoriteCharacters,
        calmingElements: profile.calmingElements,
      );
    } catch (e) {
      // Log error but don't block story generation
      debugPrint('Error saving profile: $e');
    }

    final request = StoryGenerationRequest(
      prompt: _promptCtrl.text.trim(),
      theme: _selectedTheme,
      targetLength: _targetLength.round(),
      numScenes: _sceneCount,
      voice: _selectedVoice,
      profile: profile,
    );

    try {
      final experience = await _storyService.generateStory(request);
      if (!mounted) return;
      
      // Set session ID in Sentry context if available
      if (experience.sessionId != null) {
        await SentryService.setSessionId(experience.sessionId);
      }
      
      // Refresh history after generating a new story
      _loadRecentSessions();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(experience: experience),
        ),
      );
    } catch (error) {
      // Capture error in Sentry with context
      await SentryService.captureException(
        error,
        extra: {
          'theme': _selectedTheme,
          'prompt': _promptCtrl.text.trim(),
        },
      );
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
