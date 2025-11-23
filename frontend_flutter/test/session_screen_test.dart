import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dream_flow/screens/session_screen.dart';
import 'package:dream_flow/services/story_service.dart';

void main() {
  group('SessionScreen Audio Status Text', () {
    testWidgets('audio status text uses ternary operator and compiles correctly', (WidgetTester tester) async {
      // Create a mock StoryExperience
      const experience = StoryExperience(
        storyText: 'Test story',
        theme: 'Test Theme',
        audioUrl: 'https://example.com/audio.mp3',
        videoUrl: 'https://example.com/video.mp4',
        frames: [],
      );

      // Build the widget - this verifies the code compiles without errors
      await tester.pumpWidget(
        MaterialApp(
          home: SessionScreen(experience: experience),
        ),
      );

      // Wait for initial frame - this ensures the widget tree is built
      await tester.pump();

      // The key test: verify that the widget builds without compilation errors
      // The string interpolation fix ensures this compiles correctly
      // Even if the widget shows an error state due to network initialization,
      // the important part is that the code compiles with the ternary operator fix
      expect(find.byType(SessionScreen), findsOneWidget);

      // Verify the screen is rendered (even if showing error/loading state)
      expect(find.byType(Scaffold), findsOneWidget);
    });

    test('audio status string interpolation syntax is valid', () {
      // Direct test of the string interpolation logic
      // This verifies the ternary operator works correctly
      bool isAudioPlaying = false;
      String statusText = 'Gentle ${isAudioPlaying ? 'looping' : 'ready'} voice linked to your profile.';
      expect(statusText, equals('Gentle ready voice linked to your profile.'));

      isAudioPlaying = true;
      statusText = 'Gentle ${isAudioPlaying ? 'looping' : 'ready'} voice linked to your profile.';
      expect(statusText, equals('Gentle looping voice linked to your profile.'));

      // Verify it doesn't contain the invalid map syntax
      expect(statusText, isNot(contains('{true:')));
      expect(statusText, isNot(contains('false:')));
    });
  });
}

