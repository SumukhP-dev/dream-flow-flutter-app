import 'package:flutter/material.dart';
import 'webtoons_text_panel.dart';
import '../core/backend_url_helper.dart';

/// Represents a scene with its image and corresponding text
class StoryScene {
  final String imageUrl;
  final String text;
  final int sceneIndex;

  StoryScene({
    required this.imageUrl,
    required this.text,
    required this.sceneIndex,
  });
}

/// Integrated webtoons-style story viewer that combines images and text
class WebtoonsStoryViewer extends StatefulWidget {
  final List<String> frames;
  final String storyText;
  final String primaryLanguage;
  final String secondaryLanguage;
  final bool isChildMode;
  final double? panelSpacing;
  final double? panelWidth;
  /// When false, suppresses visual placeholders during image loading/errors.
  final bool placeholdersEnabled;

  const WebtoonsStoryViewer({
    super.key,
    required this.frames,
    required this.storyText,
    this.primaryLanguage = 'en',
    this.secondaryLanguage = 'es',
    this.isChildMode = false,
    this.panelSpacing,
    this.panelWidth,
    this.placeholdersEnabled = true,
  });

  @override
  State<WebtoonsStoryViewer> createState() => _WebtoonsStoryViewerState();
}

class _WebtoonsStoryViewerState extends State<WebtoonsStoryViewer> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _imageKeys = {};
  String _globalLanguage = 'primary';

  @override
  void initState() {
    super.initState();
    // Initialize image keys
    for (int i = 0; i < widget.frames.length; i++) {
      _imageKeys[i] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Parse story text and map to scenes
  List<StoryScene> _parseScenes() {
    final scenes = <StoryScene>[];
    final frames = widget.frames;

    if (frames.isEmpty) {
      return scenes;
    }

    // Split story text into paragraphs
    final paragraphs =
        widget.storyText.split('\n').where((p) => p.trim().isNotEmpty).toList();

    // Map paragraphs to frames
    // If we have more frames than paragraphs, distribute text evenly
    // If we have more paragraphs than frames, combine paragraphs
    if (paragraphs.isEmpty) {
      // No text, just create scenes with empty text
      for (int i = 0; i < frames.length; i++) {
        scenes.add(StoryScene(
          imageUrl: frames[i],
          text: '',
          sceneIndex: i,
        ));
      }
      return scenes;
    }

    final framesPerParagraph = frames.length / paragraphs.length;

    for (int i = 0; i < frames.length; i++) {
      String sceneText = '';

      // Calculate which paragraph(s) belong to this frame
      final startParaIndex = (i / framesPerParagraph).floor();
      final endParaIndex = ((i + 1) / framesPerParagraph).ceil();

      // Get text for this scene
      final sceneParagraphs = <String>[];
      for (int j = startParaIndex;
          j < endParaIndex && j < paragraphs.length;
          j++) {
        sceneParagraphs.add(paragraphs[j]);
      }

      sceneText = sceneParagraphs.join('\n\n').trim();

      scenes.add(StoryScene(
        imageUrl: frames[i],
        text: sceneText,
        sceneIndex: i,
      ));
    }

    return scenes;
  }

  /// Get language flag emoji
  String _getLanguageFlag(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'en':
        return '🇺🇸';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      case 'ja':
        return '🇯🇵';
      default:
        return '🌐';
    }
  }

  /// Toggle global language display
  void _toggleGlobalLanguage() {
    setState(() {
      if (_globalLanguage == 'primary') {
        _globalLanguage = 'secondary';
      } else if (_globalLanguage == 'secondary') {
        _globalLanguage = 'both';
      } else {
        _globalLanguage = 'primary';
      }
    });
  }

  /// Get display text based on language setting
  String _getDisplayText(String text) {
    // Check if text has language markers
    final hasLanguageMarkers = text.contains(RegExp(r'\[(EN|ES|FR|JA):')) ||
        text.contains(
            RegExp(r'<lang code="(en|es|fr|ja)">', caseSensitive: false));

    if (!hasLanguageMarkers) {
      return text;
    }

    // Extract text based on current language setting
    if (_globalLanguage == 'primary') {
      // Extract primary language text - construct regex pattern properly
      final primaryLangCode = widget.primaryLanguage.toUpperCase();
      final primaryPattern = RegExp(
        '\\[$primaryLangCode:\\s*(.+?)\\]',
        caseSensitive: false,
      );
      final match = primaryPattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim() ?? text;
      }
    } else if (_globalLanguage == 'secondary') {
      // Extract secondary language text - construct regex pattern properly
      final secondaryLangCode = widget.secondaryLanguage.toUpperCase();
      final secondaryPattern = RegExp(
        '\\[$secondaryLangCode:\\s*(.+?)\\]',
        caseSensitive: false,
      );
      final match = secondaryPattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim() ?? text;
      }
    } else if (_globalLanguage == 'both') {
      // Extract both languages and format them nicely
      final primaryLangCode = widget.primaryLanguage.toUpperCase();
      final secondaryLangCode = widget.secondaryLanguage.toUpperCase();
      
      final primaryPattern = RegExp(
        '\\[$primaryLangCode:\\s*(.+?)\\]',
        caseSensitive: false,
      );
      final secondaryPattern = RegExp(
        '\\[$secondaryLangCode:\\s*(.+?)\\]',
        caseSensitive: false,
      );
      
      final primaryMatch = primaryPattern.firstMatch(text);
      final secondaryMatch = secondaryPattern.firstMatch(text);
      
      final primaryText = primaryMatch?.group(1)?.trim() ?? '';
      final secondaryText = secondaryMatch?.group(1)?.trim() ?? '';
      
      if (primaryText.isNotEmpty && secondaryText.isNotEmpty) {
        // Show both languages separated by a line break
        return '$primaryText\n\n$secondaryText';
      } else if (primaryText.isNotEmpty) {
        return primaryText;
      } else if (secondaryText.isNotEmpty) {
        return secondaryText;
      }
    }
    // Fallback - return original text
    return text;
  }

  /// Build image widget (handles both network and local file paths)
  Widget _buildImage(String imageUrl, double panelWidth) {
    String processedUrl = imageUrl;
    
    // If already a full URL (http/https), process it for Android emulator compatibility
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      processedUrl = BackendUrlHelper.processUrl(imageUrl);
      return _buildNetworkImage(processedUrl, panelWidth);
    }

    // Check if it's a local file path that needs to be converted to a network URL
    final isLocalPath = imageUrl.startsWith('/assets/') ||
        imageUrl.startsWith('file://') ||
        imageUrl.startsWith('/');

    if (isLocalPath) {
      // For local paths, we need to construct the proper URL using the backend URL
      // Get the backend URL from StoryService or use default
      final backendUrl = BackendUrlHelper.getBackendUrl();
      // Remove leading slash if present and add it back to ensure proper URL construction
      final cleanPath = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
      final networkUrl = '$backendUrl$cleanPath';
      processedUrl = BackendUrlHelper.processUrl(networkUrl);
      return _buildNetworkImage(processedUrl, panelWidth);
    }

    // Fallback: treat as network URL and process it
    processedUrl = BackendUrlHelper.processUrl(imageUrl);
    return _buildNetworkImage(processedUrl, panelWidth);
  }

  /// Build network image widget with loading and error handling
  Widget _buildNetworkImage(String imageUrl, double panelWidth) {
    // Debug: log image URL
    print('🖼️ Loading image from URL: $imageUrl');
    
    return Image.network(
      imageUrl,
      width: panelWidth,
      fit: BoxFit.fitWidth,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        if (!widget.placeholdersEnabled) {
          return SizedBox(width: panelWidth, height: panelWidth * 0.75);
        }
        return Container(
          width: panelWidth,
          height: panelWidth * 0.75, // 4:3 aspect ratio
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                const Color(0xFF06B6D4).withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 3,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Log the error for debugging
        print('❌ Image load error for URL: $imageUrl');
        print('   Error: $error');
        
        if (!widget.placeholdersEnabled) {
          return SizedBox(width: panelWidth, height: panelWidth * 0.75);
        }
        return Container(
          width: panelWidth,
          height: panelWidth * 0.75, // 4:3 aspect ratio
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                const Color(0xFF06B6D4).withValues(alpha: 0.2),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  'Image Placeholder',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build image panel
  Widget _buildImagePanel(StoryScene scene, double panelWidth) {
    return Container(
      key: _imageKeys[scene.sceneIndex],
      width: panelWidth,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildImage(scene.imageUrl, panelWidth),
      ),
    );
  }

  /// Build text panel for a scene
  Widget _buildTextPanel(StoryScene scene) {
    if (scene.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayText = _getDisplayText(scene.text);
    final textType = detectTextType(displayText);
    final isBilingual = widget.secondaryLanguage.isNotEmpty &&
        widget.secondaryLanguage != widget.primaryLanguage;

    // For bilingual support, we'll use a simplified approach
    // Full bilingual parsing would be handled by BilingualWebtoonsStory
    String? languageFlag;
    VoidCallback? onToggle;

    if (isBilingual) {
      languageFlag = _globalLanguage == 'primary'
          ? _getLanguageFlag(widget.primaryLanguage)
          : _globalLanguage == 'secondary'
              ? _getLanguageFlag(widget.secondaryLanguage)
              : '${_getLanguageFlag(widget.primaryLanguage)}${_getLanguageFlag(widget.secondaryLanguage)}';
      onToggle = _toggleGlobalLanguage;
    }

    return WebtoonsTextPanel(
      text: displayText,
      type: textType,
      isChildMode: widget.isChildMode,
      primaryLanguage: widget.primaryLanguage,
      secondaryLanguage: widget.secondaryLanguage,
      displayLanguage: _globalLanguage,
      onLanguageToggle: onToggle,
      languageFlag: languageFlag,
    );
  }

  /// Build a single scene (image + text) with fade-in animation
  Widget _buildScene(StoryScene scene, double panelWidth) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeIn,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImagePanel(scene, panelWidth),
          _buildTextPanel(scene),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth =
        widget.panelWidth ?? (screenWidth > 840 ? 800.0 : screenWidth - 40);
    final panelSpacing = widget.panelSpacing ?? 75.0;
    final scenes = _parseScenes();

    if (scenes.isEmpty) {
      return const SizedBox.shrink();
    }

    // Global language toggle button (if bilingual)
    final isBilingual = widget.secondaryLanguage.isNotEmpty &&
        widget.secondaryLanguage != widget.primaryLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Global language toggle
        if (isBilingual) ...[
          Center(
            child: GestureDetector(
              onTap: _toggleGlobalLanguage,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _globalLanguage == 'primary'
                          ? _getLanguageFlag(widget.primaryLanguage)
                          : _globalLanguage == 'secondary'
                              ? _getLanguageFlag(widget.secondaryLanguage)
                              : '${_getLanguageFlag(widget.primaryLanguage)}${_getLanguageFlag(widget.secondaryLanguage)}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _globalLanguage == 'primary'
                          ? widget.primaryLanguage.toUpperCase()
                          : _globalLanguage == 'secondary'
                              ? widget.secondaryLanguage.toUpperCase()
                              : 'BOTH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        // Scene list with lazy loading
        ListView.separated(
          controller: _scrollController,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(), // Parent handles scrolling
          itemCount: scenes.length,
          separatorBuilder: (context, index) => SizedBox(height: panelSpacing),
          itemBuilder: (context, index) {
            // Preload next 2-3 images for smooth scrolling
            if (index < scenes.length - 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Preload next images - process URLs for Android emulator compatibility
                for (int i = index + 1;
                    i <= (index + 3).clamp(0, scenes.length - 1);
                    i++) {
                  final imageUrl = scenes[i].imageUrl;
                  String processedUrl = imageUrl;
                  
                  // Process URL if it's a network URL
                  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                    processedUrl = BackendUrlHelper.processUrl(imageUrl);
                  } else if (imageUrl.startsWith('/')) {
                    // Convert local path to network URL
                    final backendUrl = BackendUrlHelper.getBackendUrl();
                    final cleanPath = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
                    processedUrl = BackendUrlHelper.processUrl('$backendUrl$cleanPath');
                  }
                  
                  try {
                    precacheImage(NetworkImage(processedUrl), context);
                  } catch (e) {
                    // Silently fail preloading - images will still load when displayed
                    print('Failed to precache image: $e');
                  }
                }
              });
            }
            return _buildScene(scenes[index], panelWidth);
          },
        ),
      ],
    );
  }
}
