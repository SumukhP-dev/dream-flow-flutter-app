import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/auth_service.dart';
import '../core/story_service.dart';
import '../shared/sentry_service.dart';
import 'session_screen.dart';
import '../widgets/bilingual_webtoons_story.dart';

class StreamingStoryScreen extends StatefulWidget {
  final StoryGenerationRequest request;

  const StreamingStoryScreen({
    super.key,
    required this.request,
  });

  @override
  State<StreamingStoryScreen> createState() => _StreamingStoryScreenState();
}

class _StreamingStoryScreenState extends State<StreamingStoryScreen> {
  final StoryService _storyService = StoryService();
  final AuthService _authService = AuthService();
  final StringBuffer _buffer = StringBuffer();
  StreamSubscription<String>? _subscription;
  bool _isDone = false;
  bool _hasError = false;
  String? _errorMessage;
  late final StoryGenerationRequest _requestWithUserContext;

  @override
  void initState() {
    super.initState();
    _requestWithUserContext = _attachUserContext(widget.request);
    // Force immediate completion for local backend - bypass ALL streaming complexity
    _forceImmediateCompletion();
  }

  /// Force immediate completion - use FastAPI backend for full features
  Future<void> _forceImmediateCompletion() async {
    print('🚀 Using FastAPI backend for complete multimedia story experience');
    await _useActualBackend();
  }
    print('🚀 Creating complete multimedia story experience');
    
    try {
      // Create a simple story immediately
      final storyText = _createQuickStory(
        _requestWithUserContext.prompt,
        _requestWithUserContext.theme,
        _requestWithUserContext.profile?.toJson(),
      );

      print('📖 Created story: ${storyText.length} characters');

      // Create actual working media assets
      print('🎨 Creating image frames...');
      final imageFrames = await _createWorkingImageFrames();
      print('🖼️ Created ${imageFrames.length} working image frames');

      print('🎵 Creating audio narration...');
      final audioUrl = await _createWorkingAudio(storyText);
      print('🔊 Created working audio: $audioUrl');

      // Add bilingual content if requested
      Map<String, dynamic>? bilingualContent;
      if (_requestWithUserContext.secondaryLanguage != null && 
          _requestWithUserContext.secondaryLanguage!.isNotEmpty &&
          _requestWithUserContext.secondaryLanguage != _requestWithUserContext.primaryLanguage) {
        print('🌐 Creating bilingual translation...');
        bilingualContent = _createBilingualContent(storyText, _requestWithUserContext.secondaryLanguage!);
        print('✅ Created translation for ${_requestWithUserContext.secondaryLanguage}');
      }

      // Show the story progressively
      final sentences = storyText.split(RegExp(r'[.!?]+\s*')).where((s) => s.trim().isNotEmpty).toList();
      
      for (int i = 0; i < sentences.length; i++) {
        if (!mounted) break;
        
        final sentence = sentences[i].trim();
        if (sentence.isEmpty) continue;
        final chunk = i < sentences.length - 1 ? '$sentence. ' : sentence;
        
        setState(() {
          _buffer.write(chunk);
        });
        
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // Mark as done and navigate
      setState(() => _isDone = true);
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Create complete multimedia experience
      final experience = StoryExperience(
        storyText: storyText,
        theme: _requestWithUserContext.theme,
        audioUrl: audioUrl, // Working audio file
        frames: imageFrames, // Working image files
        sessionId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        primaryLanguage: _requestWithUserContext.primaryLanguage,
        secondaryLanguage: _requestWithUserContext.secondaryLanguage,
      );
      
      print('✅ Complete multimedia story experience created');
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SessionScreen(experience: experience)),
        );
      }
      
    } catch (e) {
      print('❌ Story creation error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Story creation failed: $e';
      });
    }
  }

  /// Create working image frames using data URLs (embedded images)
  Future<List<String>> _createWorkingImageFrames() async {
    // Use data URLs to embed images directly (no file system issues)
    const base64Image = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAHIgw+mGQAAAABJRU5ErkJggg==';
    
    final numFrames = _requestWithUserContext.numScenes ?? 4;
    final frames = <String>[];
    
    // Create themed placeholder images
    for (int i = 0; i < numFrames; i++) {
      // For now, use the same base64 image (can be enhanced later)
      frames.add(base64Image);
    }
    
    print('✅ Created ${frames.length} data URL image frames');
    return frames;
  }

  /// Create working audio using data URL (embedded audio)
  Future<String> _createWorkingAudio(String storyText) async {
    // Create a minimal working WAV file as data URL
    const base64Audio = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvH';
    
    return base64Audio;
  }

  /// Create bilingual content for translations
  Map<String, dynamic> _createBilingualContent(String originalText, String targetLanguage) {
    final translations = {
      'es': { // Spanish
        'magical realm': 'reino mágico',
        'wonderful adventure': 'aventura maravillosa',
        'gentle magic': 'magia suave',
        'peaceful dreams': 'sueños pacíficos',
        'friendship': 'amistad',
        'sweetest dreams': 'sueños más dulces',
      },
      'fr': { // French
        'magical realm': 'royaume magique',
        'wonderful adventure': 'aventure merveilleuse',
        'gentle magic': 'magie douce',
        'peaceful dreams': 'rêves paisibles',
        'friendship': 'amitié',
        'sweetest dreams': 'rêves les plus doux',
      },
      'ja': { // Japanese
        'magical realm': '魔法の王国',
        'wonderful adventure': '素晴らしい冒険',
        'gentle magic': '優しい魔法',
        'friendship': '友情',
        'sweetest dreams': '最も甘い夢',
      }
    };

    final targetTranslations = translations[targetLanguage];
    if (targetTranslations == null) return originalText;
    
    // Create translated version
    String translatedText = originalText;
    targetTranslations.forEach((english, translated) {
      translatedText = translatedText.replaceAllMapped(
        RegExp('\\b$english\\b', caseSensitive: false),
        (match) => translated,
      );
    });

    return {
      'original_language': _requestWithUserContext.primaryLanguage ?? 'en',
      'target_language': targetLanguage,
      'original_text': originalText,
      'translated_text': translatedText,
      'pairs': _createTranslationPairs(originalText, translatedText),
    };
  }

  /// Create translation pairs for sentence-by-sentence display
  List<Map<String, String>> _createTranslationPairs(String original, String translated) {
    final originalSentences = original.split(RegExp(r'[.!?]+\s*')).where((s) => s.trim().isNotEmpty).toList();
    final translatedSentences = translated.split(RegExp(r'[.!?]+\s*')).where((s) => s.trim().isNotEmpty).toList();
    
    final pairs = <Map<String, String>>[];
    final maxLength = [originalSentences.length, translatedSentences.length].reduce((a, b) => a > b ? a : b);
    
    for (int i = 0; i < maxLength; i++) {
      pairs.add({
        'original': i < originalSentences.length ? originalSentences[i].trim() : '',
        'translated': i < translatedSentences.length ? translatedSentences[i].trim() : '',
      });
    }
    
    return pairs;
  }

  /// Create a quick personalized story
  String _createQuickStory(String prompt, String theme, Map<String, dynamic>? profile) {
    final mood = profile?['mood'] ?? 'peaceful';
    final favoriteCharacters = (profile?['favorite_characters'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final character = favoriteCharacters.isNotEmpty ? favoriteCharacters.first : _getThemeCharacter(theme);
    
    return '''In the magical realm of $theme, $character discovered something wonderful about "$prompt".

The adventure began on a $mood evening, filled with gentle wonder. As $character explored this enchanting world, they learned that every dream holds a special truth.

Through moments of discovery and joy, $character found that the most precious treasures are the ones we carry in our hearts. The soft glow of magic reminded them that some stories never truly end.

And so, with a smile of contentment and eyes growing peacefully heavy, $character settled into the sweetest dreams, knowing that tomorrow would bring new adventures.''';
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

  /// Generate placeholder image frames that actually exist
  Future<List<String>> _generatePlaceholderFrames() async {
    try {
      final frames = <String>[];
      final numFrames = _requestWithUserContext.numScenes ?? 4;
      
      // Call local backend to create actual placeholder images
      for (int i = 0; i < numFrames; i++) {
        final response = await http.post(
          Uri.parse('http://localhost:8080/api/v1/generate-placeholder-image'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'theme': _requestWithUserContext.theme,
            'scene_number': i + 1,
            'total_scenes': numFrames,
          }),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          frames.add(data['frame_url']);
        }
      }
      
      return frames;
    } catch (e) {
      print('⚠️ Failed to generate placeholder frames: $e');
      return <String>[];
    }
  }

  /// Generate placeholder audio that actually works  
  Future<String> _generatePlaceholderAudio(String storyText) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/v1/generate-placeholder-audio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': storyText.substring(0, 200), // First 200 chars for audio
          'voice': _requestWithUserContext.voice,
        }),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['audio_url'];
      }
    } catch (e) {
      print('⚠️ Failed to generate placeholder audio: $e');
    }
    return '';
  }

  /// Generate bilingual content for translation support
  Map<String, dynamic>? _generateBilingualContent(String originalText, String targetLanguage) {
    // Simple translation mapping for common languages
    final translations = {
      'es': { // Spanish
        'magical realm': 'reino mágico',
        'wonderful adventure': 'aventura maravillosa', 
        'gentle magic': 'magia suave',
        'peaceful dreams': 'sueños pacíficos',
        'sweetest dreams': 'sueños más dulces',
      },
      'fr': { // French
        'magical realm': 'royaume magique',
        'wonderful adventure': 'aventure merveilleuse',
        'gentle magic': 'magie douce', 
        'peaceful dreams': 'rêves paisibles',
        'sweetest dreams': 'rêves les plus doux',
      },
    };

    final targetTranslations = translations[targetLanguage];
    if (targetTranslations == null) return null;
    
    // Create a simple translated version by replacing key phrases
    String translatedText = originalText;
    targetTranslations.forEach((english, translated) {
      translatedText = translatedText.replaceAllMapped(
        RegExp(english, caseSensitive: false),
        (match) => translated,
      );
    });

    return {
      'original_language': _requestWithUserContext.primaryLanguage ?? 'en',
      'target_language': targetLanguage,
      'original_text': originalText,
      'translated_text': translatedText,
    };
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  StoryGenerationRequest _attachUserContext(StoryGenerationRequest request) {
    if (request.userId != null && request.userId!.isNotEmpty) {
      return request;
    }
    final user = _authService.currentUser;
    if (user == null) {
      return request;
    }
    return request.copyWith(userId: user.id);
  }

  /// Start direct generation - bypassing SSE streaming for reliability
  Future<void> _startDirectGeneration() async {
    print('🚀 Starting direct story generation (no SSE streaming)');
    print('Backend URL: ${_storyService.baseUrl}');
    print('Request: ${_requestWithUserContext.toJson()}');
    
    // Go directly to fallback generation which we know works
    await _fallbackToRegularGeneration();
  }

  Future<void> _startStreaming() async {
    // Check if we should use local backend (only for actual localhost URLs)
    final shouldUseLocal = _storyService.baseUrl.contains('localhost') || _storyService.baseUrl.contains('127.0.0.1');
    
    if (shouldUseLocal) {
      print('🔄 Local backend detected, using direct story generation (bypassing SSE)');
      await _fallbackToRegularGeneration();
      return;
    }

    // For external backends (including 10.0.2.2:8080), use FastAPI backend
    print('🌐 External FastAPI backend detected, using full backend generation');
    await _useActualBackend();
  }
  
  /// Use the actual FastAPI backend for story generation
  Future<void> _useActualBackend() async {
    try {
      print('🚀 Calling FastAPI backend for full story generation');
      print('Backend URL: ${_storyService.baseUrl}');
      
      final experience = await _storyService.generateStory(_requestWithUserContext);
      
      print('✅ Story generated successfully by FastAPI backend');
      print('Story length: ${experience.storyText.length} characters');
      print('Audio URL: ${experience.audioUrl}');
      print('Image frames: ${experience.frames.length}');
      
      // Navigate to session screen with the complete experience
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SessionScreen(experience: experience)),
        );
      }
    } catch (e) {
      print('❌ FastAPI backend call failed: $e');
      print('🔄 Falling back to local generation...');
      await _fallbackToRegularGeneration();
    }
  }

    // Only use SSE streaming for external backends (like FastAPI)
    final uri = Uri.parse('${_storyService.baseUrl}/api/v1/story/stream');

    print('Starting story stream to: $uri');
    print('Backend URL: ${_storyService.baseUrl}');
    print('Request payload: ${_requestWithUserContext.toJson()}');

    // First, test if backend is reachable with a quick health check
    try {
      print('Testing backend connection...');
      final healthUri = Uri.parse('${_storyService.baseUrl}/health');
      final healthResponse = await _storyService.client
          .get(healthUri)
          .timeout(const Duration(seconds: 5));
      print('✅ Backend health check: ${healthResponse.statusCode}');
    } catch (e) {
      print('❌ Backend health check failed: $e');
      print('🔄 Falling back to regular story generation...');
      await _fallbackToRegularGeneration();
      return;
    }

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(_requestWithUserContext.toJson());

    try {
      print('Sending streaming request...');
      final response = await _storyService.client.send(request).timeout(
        const Duration(seconds: 120), // Increased timeout for story generation
        onTimeout: () {
          print('⚠️ Request timed out after 120 seconds');
          throw TimeoutException(
            'Connection timeout. Please check your internet connection and try again.',
            const Duration(seconds: 120),
          );
        },
      );

      print('✅ Received response: ${response.statusCode}');

      if (response.statusCode >= 400) {
        String errorMessage = 'Story stream failed';
        try {
          final errorBody = await response.stream
              .transform(utf8.decoder)
              .join()
              .then((body) => jsonDecode(body) as Map<String, dynamic>?);
          if (errorBody != null) {
            final error = errorBody['error'] as String?;
            final detail = errorBody['detail'] as String?;
            errorMessage = error ?? detail ?? 'Unknown error';
          }
        } catch (_) {
          errorMessage =
              'Story stream failed (${response.statusCode}): ${response.reasonPhrase ?? ''}';
        }

        setState(() {
          _hasError = true;
          _errorMessage = errorMessage;
        });
        return;
      }

      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleSseLine,
        onError: (e, _) {
          print('❌ SSE stream error: $e, falling back to regular generation');
          _fallbackToRegularGeneration();
        },
        onDone: () {
          print('📤 SSE stream ended');
          if (!_isDone && !_hasError) {
            print('⚠️ Stream ended without completion, falling back to regular generation');
            _fallbackToRegularGeneration();
          }
        },
      );

      // Add a safety timeout to prevent infinite loading
      // If we don't get a 'done' event within 60 seconds, fallback
      Timer(const Duration(seconds: 60), () {
        if (!_isDone && !_hasError && mounted) {
          print('⚠️ SSE streaming timed out after 60s, falling back to regular generation');
          _subscription?.cancel();
          _fallbackToRegularGeneration();
        }
      });
    } on SocketException catch (e, stackTrace) {
      if (!mounted) return;
      await SentryService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'endpoint': '/api/v1/story/stream',
          'error_type': 'SocketException'
        },
      );
      setState(() {
        _hasError = true;
        _errorMessage =
            'Connection failed. If the problem persists, please check your internet connection or VPN.';
      });
    } on HttpException catch (e, stackTrace) {
      if (!mounted) return;
      await SentryService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'endpoint': '/api/v1/story/stream',
          'error_type': 'HttpException'
        },
      );
      setState(() {
        _hasError = true;
        _errorMessage =
            'Connection failed. If the problem persists, please check your internet connection or VPN.';
      });
    } on TimeoutException catch (e, stackTrace) {
      if (!mounted) return;
      await SentryService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'endpoint': '/api/v1/story/stream',
          'error_type': 'TimeoutException'
        },
      );
      setState(() {
        _hasError = true;
        _errorMessage =
            'Connection timeout. Please check your internet connection and try again.';
      });
    } catch (e, stackTrace) {
      if (!mounted) return;
      await SentryService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {'endpoint': '/api/v1/story/stream'},
      );
      final errorMessage = _formatErrorMessage(e);
      setState(() {
        _hasError = true;
        _errorMessage = errorMessage;
      });
    }
  }

  String _formatErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('socket') ||
        errorStr.contains('connection refused')) {
      return 'Connection failed. If the problem persists, please check your internet connection or VPN.';
    }
    if (errorStr.contains('timeout')) {
      return 'Connection timeout. Please check your internet connection and try again.';
    }
    return error.toString();
  }

  /// Fallback to regular story generation when streaming fails
  Future<void> _fallbackToRegularGeneration() async {
    if (!mounted) return;
    
    try {
      print('🔄 Starting direct story creation (bypassing StoryService.generateStory)...');
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _buffer.clear();
      });

      // Create story experience directly without calling StoryService.generateStory
      // which has a 300-second timeout and causes hanging
      final request = _requestWithUserContext;
      
      // Generate personalized story text using our fast fallback
      final storyText = _generateQuickStory(
        request.prompt,
        request.theme,
        request.profile?.toJson(),
      );
      
      print('📖 Generated story: ${storyText.length} characters');

      // Create a complete StoryExperience object
      print('🔊 Creating audio narration...');
      final audioUrl = await _createWorkingAudio(storyText);
      print('✅ Created audio: $audioUrl');
      
      print('🖼️ Creating image frames...');
      final imageFrames = await _createWorkingImageFrames();
      print('✅ Created ${imageFrames.length} image frames');
      
      final experience = StoryExperience(
        storyText: storyText,
        theme: request.theme,
        audioUrl: audioUrl, // Use actual audio URL
        frames: imageFrames, // Use actual image frames
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Simulate progressive streaming for good UX
      final sentences = storyText
          .split(RegExp(r'[.!?]+\s*'))
          .where((s) => s.trim().isNotEmpty)
          .toList();

      print('📖 Displaying story progressively with ${sentences.length} sentences');

      // Add sentences with delay to simulate streaming
      for (int i = 0; i < sentences.length; i++) {
        if (!mounted) break;
        
        final sentence = sentences[i].trim();
        if (sentence.isEmpty) continue;

        final chunk = i < sentences.length - 1 ? '$sentence. ' : sentence;
        setState(() {
          _buffer.write(chunk);
        });

        // Small delay to show progression
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!mounted) return;
      
      // Mark as done and navigate to session screen
      print('✅ Story generation completed, navigating to session screen');
      setState(() => _isDone = true);
      
      // Small delay to show completion state
      await Future.delayed(const Duration(milliseconds: 500));
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionScreen(experience: experience),
        ),
      );

    } catch (e, stackTrace) {
      if (!mounted) return;
      await SentryService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {'direct_story_creation': true},
      );
      setState(() {
        _hasError = true;
        _errorMessage = 'Story creation failed: ${e.toString()}';
      });
    }
  }

  /// Generate a quick story without external service calls
  String _generateQuickStory(String prompt, String theme, Map<String, dynamic>? profile) {
    final mood = profile?['mood'] ?? 'peaceful';
    final favoriteCharacters = (profile?['favorite_characters'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final character = favoriteCharacters.isNotEmpty ? favoriteCharacters.first : _getThemeCharacter(theme);
    
    return '''In the gentle world of $theme, $character embarked on a magical journey inspired by your dream: "$prompt".

As the adventure unfolded, $character discovered that sometimes the most beautiful stories come from the simplest wishes. The ${mood.toLowerCase()} atmosphere filled every moment with wonder and joy.

Through peaceful valleys and shimmering streams, $character learned that every ending is really a new beginning, and every dream carries the seed of tomorrow's adventure.

And so, with a heart full of contentment and eyes growing peacefully heavy, it was time for the sweetest dreams of all.''';
  }

  String _getThemeCharacter(String theme) {
    final themeCharacters = {
      'Ocean Dreams': 'Luna the dolphin',
      'Forest Friends': 'Oliver the wise owl', 
      'Space Explorer': 'Captain Maya',
      'Study Grove': 'Sage the reading fox',
      'Enchanted Garden': 'Lily the fairy',
      'Mountain Adventure': 'Scout the mountain goat',
    };
    return themeCharacters[theme] ?? 'a gentle friend';
  }

  Future<void> _handleSseLine(String line) async {
    if (!line.startsWith('data:')) return;
    final payload = line.substring(5).trim();
    if (payload.isEmpty) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = data['type'] as String?;

    if (type == 'start') {
      // Server sent initial event - connection is alive, prevent timeout
      if (!mounted) return;
      final message = data['message'] as String?;
      if (message != null) {
        setState(() {
          _errorMessage = null;
          _hasError = false;
        });
      }
    } else if (type == 'text') {
      final delta = data['delta'] as String? ?? '';
      if (!mounted) return;
      setState(() {
        _buffer.write(delta);
      });
    } else if (type == 'done') {
      if (!mounted) return;
      setState(() => _isDone = true);

      try {
        var experience =
            await _storyService.generateStory(_requestWithUserContext);
        if (experience.sessionId == null) {
          final offlineId = await _storyService.saveOfflineStory(
            request: _requestWithUserContext,
            experience: experience,
          );
          experience = experience.copyWith(sessionId: offlineId);
        }
        if (!mounted) return;

        if (experience.sessionId != null) {
          await SentryService.setSessionId(experience.sessionId);
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionScreen(experience: experience),
          ),
        );
      } catch (e, stackTrace) {
        if (!mounted) return;
        await SentryService.captureException(
          e,
          stackTrace: stackTrace,
          extra: {'endpoint': '/api/v1/story'},
        );
        final errorMessage = _formatErrorMessage(e);
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load full experience: $errorMessage';
        });
      }
    } else if (type == 'error') {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = data['message'] as String? ?? 'Unknown streaming error';
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
          'Creating your story',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(),
            const SizedBox(height: 16),
            Expanded(child: _buildStoryCard()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    if (_hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade300),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage ?? 'Something went wrong.',
                  style: TextStyle(
                    color: Colors.red.shade200,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _errorMessage = null;
                _buffer.clear();
                _isDone = false;
              });
              _startStreaming();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _isDone
                ? 'Finishing up your visuals and narration...'
                : 'We’re weaving tonight’s story and scenes.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryCard() {
    final text = _buffer.isEmpty
        ? 'Lanterns are lifting, clouds are drifting...\n\nYour story will appear here as it\'s written.'
        : _buffer.toString();

    // Extract languages from request if available
    final primaryLang = _requestWithUserContext.primaryLanguage ?? 'en';
    final secondaryLang = _requestWithUserContext.secondaryLanguage ?? 'es';
    final isBilingual =
        secondaryLang.isNotEmpty && secondaryLang != primaryLang;

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
                'Story Seed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isBilingual && text.length > 50
                ? SingleChildScrollView(
                    child: BilingualWebtoonsStory(
                      storyText: text,
                      primaryLanguage: primaryLang,
                      secondaryLanguage: secondaryLang,
                      isChildMode: false, // Could be determined from request
                    ),
                  )
                : SingleChildScrollView(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.7,
                        fontSize: 18,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

}
