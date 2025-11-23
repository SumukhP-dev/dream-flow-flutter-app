/*
Unit tests for StoryExperience model used by SessionScreen playback UI.
*/

import 'package:flutter_test/flutter_test.dart';

import 'package:dream_flow/services/story_service.dart';

void main() {
  group('StoryExperience', () {
    test('fromJson parses assets correctly', () {
      final json = {
        'story_text': 'A calm bedtime story',
        'theme': 'Oceanic Serenity',
        'assets': {
          'audio': 'https://example.com/audio.mp3',
          'video': 'https://example.com/video.mp4',
          'frames': ['frame1.png', 'frame2.png'],
        },
      };

      final experience = StoryExperience.fromJson(json);

      expect(experience.storyText, 'A calm bedtime story');
      expect(experience.theme, 'Oceanic Serenity');
      expect(experience.audioUrl, 'https://example.com/audio.mp3');
      expect(experience.videoUrl, 'https://example.com/video.mp4');
      expect(experience.frames, ['frame1.png', 'frame2.png']);
    });

    test('fromJson handles missing frames gracefully', () {
      final json = {
        'story_text': 'Another story',
        'theme': 'Starlit Sanctuary',
        'assets': {
          'audio': 'https://example.com/audio.mp3',
          'video': 'https://example.com/video.mp4',
          'frames': [],
        },
      };

      final experience = StoryExperience.fromJson(json);

      expect(experience.frames, isEmpty);
    });
  });
}

