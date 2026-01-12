import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../core/story_service.dart' show StoryExperience;

/// Service for generating shareable story cards
class StoryCardService {
  /// Generate a shareable image card for a story
  /// 
  /// This creates an offscreen widget, renders it, and captures it as an image.
  Future<File> generateStoryCard({
    required StoryExperience experience,
    String? customMessage,
    required BuildContext context,
  }) async {
    final controller = ScreenshotController();
    
    // Create the card widget wrapped in Screenshot
    final cardWidget = Screenshot(
      controller: controller,
      child: _StoryCardWidget(
        experience: experience,
        customMessage: customMessage,
      ),
    );

    // Render the widget offscreen using an overlay
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000, // Position offscreen
        top: -10000,
        child: Material(
          type: MaterialType.transparency,
          child: cardWidget,
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Wait for the widget to render
    await Future.delayed(const Duration(milliseconds: 100));

    // Capture the screenshot
    final imageBytes = await controller.capture();

    // Remove the overlay entry
    overlayEntry.remove();

    if (imageBytes == null) {
      throw Exception('Failed to capture story card image');
    }

    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(
      tempDir.path,
      'story_card_${DateTime.now().millisecondsSinceEpoch}.png',
    ));
    await file.writeAsBytes(imageBytes);

    return file;
  }

  /// Generate a streak achievement card
  Future<File> generateStreakCard({
    required int streakDays,
    required BuildContext context,
    String? customMessage,
  }) async {
    final controller = ScreenshotController();
    
    final cardWidget = Screenshot(
      controller: controller,
      child: _StreakCardWidget(
        streakDays: streakDays,
        customMessage: customMessage,
      ),
    );

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: -10000,
        child: Material(
          type: MaterialType.transparency,
          child: cardWidget,
        ),
      ),
    );

    overlay.insert(overlayEntry);
    await Future.delayed(const Duration(milliseconds: 100));

    final imageBytes = await controller.capture();
    overlayEntry.remove();

    if (imageBytes == null) {
      throw Exception('Failed to capture streak card image');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(
      tempDir.path,
      'streak_card_${DateTime.now().millisecondsSinceEpoch}.png',
    ));
    await file.writeAsBytes(imageBytes);

    return file;
  }
}

class _StreakCardWidget extends StatelessWidget {
  final int streakDays;
  final String? customMessage;

  const _StreakCardWidget({
    required this.streakDays,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    String message = customMessage ?? 'Amazing streak!';
    if (streakDays == 7) {
      message = '🔥 7-Day Streak! You\'re on fire!';
    } else if (streakDays == 30) {
      message = '🌟 30-Day Streak! You\'re a champion!';
    } else if (streakDays == 100) {
      message = '🏆 100-Day Streak! Legendary!';
    }

    return Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B6B),
            const Color(0xFFFF8E53),
            const Color(0xFFFFA500),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 120,
              color: Colors.white,
            ),
            const SizedBox(height: 40),
            Text(
              '$streakDays',
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Days in a Row',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            const Text(
              'Created with Dream Flow',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
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
                // YouTube link if available
                if (experience.isFeatured == true && experience.youtubeUrl != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF0000).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_filled,
                          color: Color(0xFFFF0000),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Watch on YouTube',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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

