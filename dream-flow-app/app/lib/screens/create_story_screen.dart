import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'simple_story_generation_screen.dart';
import 'session_screen.dart';
import '../core/story_service.dart';
import '../core/backend_url_helper.dart';
import '../services/story_template_service.dart';
import '../services/ad_service.dart';
import '../shared/preferences_service.dart';
import '../shared/sentry_service.dart';
import 'subscription_screen.dart';

class CreateStoryScreen extends StatefulWidget {
  final String? presetTheme;
  final String? presetMood;
  final String? presetRoutine;

  const CreateStoryScreen({
    super.key,
    this.presetTheme,
    this.presetMood,
    this.presetRoutine,
  });

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final PreferencesService _preferencesService = PreferencesService();
  final StoryTemplateService _templateService = StoryTemplateService();
  final AdService _adService = AdService();

  // Backend detection state
  String _backendType = 'Local';
  String _backendUrl = 'http://localhost:8080';
  bool _isBackendDetected = false;

  final TextEditingController _promptCtrl = TextEditingController(
    text:
        'Tell me a bedtime story about floating lanterns guiding a sleepy fox.',
  );
  final TextEditingController _moodCtrl = TextEditingController();
  final TextEditingController _routineCtrl = TextEditingController();
  final TextEditingController _favoritesCtrl = TextEditingController();
  final TextEditingController _calmingCtrl = TextEditingController();

  // Templates loaded from backend
  List<StoryTemplate> _allTemplates = [];
  List<StoryTemplate> _featuredTemplates = [];
  Map<String, List<StoryTemplate>> _categorizedTemplates = {};
  bool _isLoadingTemplates = true;

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
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'ja', 'name': 'Japanese', 'flag': '🇯🇵'},
  ];

  late String _selectedTheme;
  late String _selectedVoice;
  String? _selectedPrimaryLanguage;
  String? _selectedSecondaryLanguage;
  final Set<String> _selectedPreferences = <String>{};

  // User-facing length control in words; converted to an approximate character
  // budget when sending the request to the story generator.
  //
  // Why: generator code paths (backend + on-device) treat `target_length` as
  // ~characters (and then map to tokens). Previously the UI labeled this as
  // "words" but sent raw values, resulting in much shorter stories than users
  // expected.
  static const int _minTargetWords = 150;
  static const int _maxTargetWords = 300;
  static const double _charsPerWordEstimate =
      5.3; // ~1.33 tokens/word * 4 chars/token
  double _targetWords = 220;
  int _sceneCount = 4;
  bool _isGenerating = false;
  String? _errorMessage;

  int _estimatedTargetCharsFromWords(int words) {
    final clampedWords = words.clamp(_minTargetWords, _maxTargetWords);
    return (clampedWords * _charsPerWordEstimate).round();
  }

  @override
  void initState() {
    super.initState();
    _selectedVoice = _voices.first;
    _selectedPrimaryLanguage = 'en'; // Default to English
    _selectedSecondaryLanguage = 'es'; // Default to Spanish

    // Detect backend type first
    _detectBackendType();

    // Load templates from backend first, then set defaults
    _loadStoryTemplates();

    // Pre-fill mood and routine from preset if provided
    if (widget.presetMood != null) {
      _moodCtrl.text = widget.presetMood!;
    }
    if (widget.presetRoutine != null) {
      _routineCtrl.text = widget.presetRoutine!;
    }

    _loadProfile();
  }

  /// Detect backend type based on environment configuration
  /// Uses the same logic as main.dart for consistency
  Future<void> _detectBackendType() async {
    // Use the same logic as main.dart for backend URL resolution
    final dartDefineBackendUrl = const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: '',
    );
    final envBackendUrl = dotenv.env['BACKEND_URL'] ?? '';
    
    final rawBackendUrl = dartDefineBackendUrl.isNotEmpty
        ? dartDefineBackendUrl
        : envBackendUrl;

    // Process backend URL using the same helper as the app
    final externalBackendUrl = BackendUrlHelper.processUrl(rawBackendUrl);
    
    // Use the same logic as BackendUrlHelper to determine if local or external backend
    // A backend is considered LOCAL if:
    // 1. No backend URL is configured (empty), OR
    // 2. Raw URL (before Android conversion) matches local backend patterns
    final defaultValue = 'http://localhost:8080';
    final isLocalBackend = rawBackendUrl.isEmpty || 
        rawBackendUrl == defaultValue ||
        rawBackendUrl == 'http://localhost:8080' ||
        rawBackendUrl == 'http://127.0.0.1:8080';
    
    // Debug the condition checks
    print('  Debug conditions:');
    print('    rawBackendUrl.isEmpty: ${rawBackendUrl.isEmpty}');
    print('    rawBackendUrl == defaultValue: ${rawBackendUrl == defaultValue}');
    print('    rawBackendUrl == "http://localhost:8080": ${rawBackendUrl == 'http://localhost:8080'}');
    print('    defaultValue: "$defaultValue"');
    print('    rawBackendUrl: "$rawBackendUrl"');
    
    setState(() {
      _backendUrl = isLocalBackend 
          ? 'http://localhost:8080' 
          : externalBackendUrl;
      _backendType = isLocalBackend ? 'Local' : 'Cloud';
      _isBackendDetected = true;
    });
    
    // Debug logging (matches main.dart style)
    print('🔍 Backend detection in CreateStoryScreen:');
    print('  --dart-define BACKEND_URL: "$dartDefineBackendUrl"');
    print('  .env BACKEND_URL: "$envBackendUrl"');
    print('  Raw backend URL: "$rawBackendUrl"');
    print('  Processed backend URL: "$externalBackendUrl"');
    print('  Using local backend: $isLocalBackend');
    print('  Backend type: $_backendType');
  }

  Future<void> _loadStoryTemplates() async {
    try {
      print('🔍 Fetching story templates from backend: $_backendUrl');
      final templatesResponse = await _templateService.getStoryTemplates();

      if (!mounted) return; // Check mounted before setState
      
      setState(() {
        _allTemplates = templatesResponse.templates;
        _featuredTemplates = templatesResponse.featured;
        _categorizedTemplates = templatesResponse.categories;
        _isLoadingTemplates = false;

        // Set default theme from preset or first featured template
        _selectedTheme = widget.presetTheme ??
            (_featuredTemplates.isNotEmpty
                ? _featuredTemplates.first.title
                : (_allTemplates.isNotEmpty
                    ? _allTemplates.first.title
                    : 'Study Grove'));
      });

      print('✅ Successfully fetched ${_allTemplates.length} story templates');
    } catch (e) {
      print('! Error fetching story templates: $e');
      print('🔄 Using fallback story templates');
      
      if (!mounted) return; // Check mounted before setState
      
      // Use fallback templates instead of empty state
      setState(() {
        _allTemplates = _getFallbackTemplates();
        _featuredTemplates = _allTemplates.take(3).toList();
        _categorizedTemplates = {'focus': _allTemplates};
        _isLoadingTemplates = false;
        _selectedTheme = widget.presetTheme ?? 'Study Grove'; // Fallback
      });
    }
  }

  List<StoryTemplate> _getFallbackTemplates() {
    final now = DateTime.now();
    return [
      StoryTemplate(
        id: 'study_grove',
        title: 'Study Grove',
        emoji: '🌳',
        description: 'A peaceful forest clearing perfect for learning',
        mood: 'calm',
        routine: 'study',
        category: 'focus',
        isFeatured: true,
        sampleStoryText: 'A serene forest grove with dappled sunlight, perfect for studying and reflection',
        createdAt: now,
        updatedAt: now,
      ),
      StoryTemplate(
        id: 'cosmic_serenity',
        title: 'Cosmic Serenity', 
        emoji: '✨',
        description: 'Drift among the stars in peaceful contemplation',
        mood: 'calm',
        routine: 'bedtime',
        category: 'wonder',
        isFeatured: true,
        sampleStoryText: 'A gentle journey through a star-filled cosmos, with soft nebulae and twinkling lights',
        createdAt: now,
        updatedAt: now,
      ),
      StoryTemplate(
        id: 'ocean_depths',
        title: 'Ocean Depths',
        emoji: '🌊',
        description: 'Explore the calm depths of a magical underwater world',
        mood: 'calm',
        routine: 'meditation',
        category: 'adventure',
        isFeatured: true,
        sampleStoryText: 'A peaceful underwater realm with gentle sea creatures and soft coral gardens',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  /// Load profile data from Supabase/SharedPreferences and hydrate inputs
  Future<void> _loadProfile() async {
    try {
      final profile = await _preferencesService.loadProfile();

      if (profile != null && mounted) {
        setState(() {
          // Hydrate mood - only if not already set by preset
          if (_moodCtrl.text.isEmpty) {
            if (profile['mood'] != null) {
              _moodCtrl.text = profile['mood'] as String;
            } else {
              _moodCtrl.text = 'Sleepy and hopeful';
            }
          }

          // Hydrate ritual/routine - only if not already set by preset
          if (_routineCtrl.text.isEmpty) {
            if (profile['routine'] != null) {
              _routineCtrl.text = profile['routine'] as String;
            } else {
              _routineCtrl.text = 'Warm bath then story time';
            }
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
              prefs
                  .map((e) => e.toString())
                  .where((p) => _preferenceOptions.contains(p)),
            );
          } else {
            // Default preferences if none saved
            _selectedPreferences.addAll({'friendship', 'gentle animals'});
          }
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
        });
      }
    }
  }

  /// Build dynamic backend indicator widget
  Widget _buildBackendIndicator() {
    if (!_isBackendDetected) {
      return const SizedBox.shrink(); // Hide until detection is complete
    }

    final isLocal = _backendType == 'Local';
    
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocal ? Icons.smartphone : Icons.cloud,
            color: isLocal 
                ? Colors.green.withValues(alpha: 0.8)
                : Colors.blue.withValues(alpha: 0.8),
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isLocal ? 'Local' : 'Cloud',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Create Story',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Dynamic backend indicator
          _buildBackendIndicator(),
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
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              selectedColor: const Color(0xFF8B5CF6),
                              labelStyle: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.white70,
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
                          valueLabel: '${_targetWords.round()} words',
                          child: Slider(
                            value: _targetWords,
                            min: _minTargetWords.toDouble(),
                            max: _maxTargetWords.toDouble(),
                            divisions:
                                (_maxTargetWords - _minTargetWords) ~/ 10,
                            label: _targetWords.round().toString(),
                            onChanged: (value) {
                              setState(() => _targetWords = value);
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
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF1E1B2E),
                                initialValue: _selectedPrimaryLanguage,
                                decoration: InputDecoration(
                                  labelText: 'Primary Language',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
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
                                items: _languages
                                    .map(
                                      (lang) => DropdownMenuItem(
                                        value: lang['code'],
                                        child: Row(
                                          children: [
                                            Text(lang['flag'] ?? ''),
                                            const SizedBox(width: 8),
                                            Text(lang['name'] ?? ''),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedPrimaryLanguage = value;
                                      // If secondary is same, change it
                                      if (_selectedSecondaryLanguage == value) {
                                        _selectedSecondaryLanguage =
                                            _languages.firstWhere(
                                          (l) => l['code'] != value,
                                          orElse: () => _languages.first,
                                        )['code'];
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.translate_rounded,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF1E1B2E),
                                initialValue: _selectedSecondaryLanguage,
                                decoration: InputDecoration(
                                  labelText:
                                      'Secondary Language (for bilingual)',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
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
                                items: _languages
                                    .where((lang) =>
                                        lang['code'] !=
                                        _selectedPrimaryLanguage)
                                    .map(
                                      (lang) => DropdownMenuItem(
                                        value: lang['code'],
                                        child: Row(
                                          children: [
                                            Text(lang['flag'] ?? ''),
                                            const SizedBox(width: 8),
                                            Text(lang['name'] ?? ''),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() =>
                                        _selectedSecondaryLanguage = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                        shadowColor: const Color(
                          0xFF8B5CF6,
                        ).withValues(alpha: 0.5),
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
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
          ),
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
    if (_isLoadingTemplates) {
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
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
        ],
      );
    }

    if (_allTemplates.isEmpty) {
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
          Text(
            'No story templates available. Please check your connection.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      );
    }

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
          final categoryTemplates =
              _categorizedTemplates[category['key']] ?? [];

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
                children: categoryTemplates.map((template) {
                  final isSelected = _selectedTheme == template.title;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTheme = template.title;
                        _promptCtrl.text = template.description;
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
                            template.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            template.title,
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
        }),
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

  void _togglePreference(String pref) {
    setState(() {
      if (_selectedPreferences.contains(pref)) {
        _selectedPreferences.remove(pref);
      } else {
        _selectedPreferences.add(pref);
      }
    });
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

    // Check daily limit for free users
    final reachedLimit = await _adService.hasReachedDailyFreeLimit();
    if (reachedLimit) {
      final shouldContinue = await _showRewardedAdDialog();
      if (!shouldContinue) {
        return; // User declined
      }
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
      targetLength: _estimatedTargetCharsFromWords(_targetWords.round()),
      numScenes: _sceneCount,
      voice: _selectedVoice,
      profile: profile,
      primaryLanguage: _selectedPrimaryLanguage,
      secondaryLanguage: _selectedSecondaryLanguage,
    );

    try {
      if (!mounted) return;

      print('🚀 Story generation started - testing multimedia features');
      
      // Simple success demonstration
      await Future.delayed(const Duration(seconds: 2)); // Simulate quick generation
      
      print('🚀 Creating actual story - no popup, direct navigation');
      
      // Direct FastAPI backend call with debug logging
      try {
        print('🚀 Direct FastAPI backend call for story generation');
        final storyService = StoryService();
        print('Backend URL: ${storyService.baseUrl}');
        
        // Test backend connectivity first
        print('🔍 Testing backend connectivity...');
        final healthResponse = await storyService.client
          .get(Uri.parse('${storyService.baseUrl}/health'))
          .timeout(const Duration(seconds: 10));
        print('✅ Backend health check: ${healthResponse.statusCode}');
        print('📊 Backend response: ${healthResponse.body}');
        
        // Show loading state
        setState(() => _isGenerating = true);
        
        print('📤 Calling generateStory...');
        final experience = await storyService.generateStory(request).timeout(
          const Duration(minutes: 8), // Increased from 60 seconds to 8 minutes
          onTimeout: () {
            throw Exception('Story generation timed out after 8 minutes');
          },
        );
        
        print('✅ FastAPI backend returned story successfully');
        print('Story: ${experience.storyText.length} characters');
        print('Audio: ${experience.audioUrl}');
        print('Images: ${experience.frames.length} frames');
        
        // Increment story counter for ads
        await _adService.incrementStoryCounter();
        
        // Navigate directly to session with backend-generated content
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SessionScreen(experience: experience),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        print('❌ FastAPI backend call failed: $e');
        print('🔄 Falling back to simple generation...');
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Backend connection failed: $e';
        });
        // Fallback to simple generation
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SimpleStoryGenerationScreen(request: request),
          ),
        );
      }
    } catch (error) {
      // Capture error in Sentry with context
      await SentryService.captureException(
        error,
        extra: {'theme': _selectedTheme, 'prompt': _promptCtrl.text.trim()},
      );
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<bool> _showRewardedAdDialog() async {
    // Preload rewarded ad
    _adService.loadRewardedAd();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Daily Limit Reached',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve created 2 stories today on the Free plan.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose an option to continue:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'upgrade'),
            icon: const Icon(Icons.diamond, color: Color(0xFF8B5CF6)),
            label: const Text(
              'Upgrade to Premium',
              style: TextStyle(color: Color(0xFF8B5CF6)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'watch'),
            icon: const Icon(Icons.play_circle_outline, color: Colors.white),
            label: const Text(
              'Watch Ad to Continue',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );

    if (result == 'upgrade') {
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }
      return false;
    } else if (result == 'watch') {
      // Show rewarded ad
      final watched = await _adService.showRewardedAd();
      if (!watched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ad not ready. Please try again in a moment.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }
      // Increment counter after successful ad watch
      await _adService.incrementStoryCounter();
      return true;
    }
    return false;
  }
}
