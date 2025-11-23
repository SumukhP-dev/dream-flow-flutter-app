import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'story_service.dart';

/// Service for generating shareable story cards
class StoryCardService {
  /// Generate a shareable image card for a story
  Future<File> generateStoryCard({
    required StoryExperience experience,
    String? customMessage,
  }) async {
    // Create a widget for the card
    final cardWidget = _StoryCardWidget(
      experience: experience,
      customMessage: customMessage,
    );

    // Render widget to image
    final imageBytes = await _widgetToImage(cardWidget);

    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(
      tempDir.path,
      'story_card_${DateTime.now().millisecondsSinceEpoch}.png',
    ));
    await file.writeAsBytes(imageBytes);

    return file;
  }

  Future<Uint8List> _widgetToImage(Widget widget) async {
    // Note: Widget-to-image conversion requires a BuildContext
    // This is a simplified placeholder - in production, use a proper
    // widget-to-image library or render in a hidden overlay
    // For now, return a placeholder image
    throw UnimplementedError(
      'Widget-to-image conversion requires BuildContext. '
      'Use GlobalKey<RepaintBoundaryState> in the widget tree instead.',
    );
  }
}

class _StoryCardWidget extends StatelessWidget {
  final StoryExperience experience;
  final String? customMessage;

  const _StoryCardWidget({
    required this.experience,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
            const Color(0xFF0F3460),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/pattern.png'), // Placeholder
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App logo/name
                Text(
                  'Dream Flow',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                // Theme
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    experience.theme,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                // Story preview
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customMessage ?? 'A bedtime story just for you',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        experience.storyText.length > 200
                            ? '${experience.storyText.substring(0, 200)}...'
                            : experience.storyText,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Created with Dream Flow',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

