/*
Unit tests for StoryExperience model used by SessionScreen playback UI.
*/

import 'package:flutter_test/flutter_test.dart';

import 'package:dream_flow/core/story_service.dart';
import 'package:dream_flow/core/backend_url_helper.dart';

void main() {
  group('StoryExperience', () {
    test('fromJson parses assets correctly', () {
      final json = {
        'story_text': 'A calm bedtime story',
        'theme': 'Oceanic Serenity',
        'youtube_video_id': 'test-youtube-id',
        'assets': {
          'audio': 'https://example.com/audio.mp3',
          'frames': ['frame1.png', 'frame2.png'],
        },
      };

      final experience = StoryExperience.fromJson(json);

      expect(experience.storyText, 'A calm bedtime story');
      expect(experience.theme, 'Oceanic Serenity');
      expect(experience.audioUrl, 'https://example.com/audio.mp3');
      expect(experience.youtubeVideoId, 'test-youtube-id');
      expect(experience.youtubeUrl, 'https://www.youtube.com/watch?v=test-youtube-id');
      final backendUrl = BackendUrlHelper.getBackendUrl();
      expect(experience.frames, [
        '$backendUrl/frame1.png',
        '$backendUrl/frame2.png',
      ]);
    });

    test('fromJson handles missing frames gracefully', () {
      final json = {
        'story_text': 'Another story',
        'theme': 'Starlit Sanctuary',
        'youtube_video_id': 'test-youtube-id-2',
        'assets': {
          'audio': 'https://example.com/audio.mp3',
          'frames': [],
        },
      };

      final experience = StoryExperience.fromJson(json);

      expect(experience.frames, isEmpty);
    });
  });
}

