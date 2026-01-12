import 'dart:convert';

import 'package:dream_flow/core/story_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  StoryService buildService(
      http.Response Function(http.Request request) handler) {
    final client = MockClient((request) async => handler(request));
    return StoryService(
      baseUrl: 'http://localhost:8080',
      client: client,
      preferences: () async => prefs,
    );
  }

  group('StoryService', () {
    test('generateStory returns StoryExperience with computed YouTube URL',
        () async {
      final service = buildService((request) {
        expect(request.url.path, '/api/v1/story');
        final payload = {
          'story_text': 'demo',
          'theme': 'Aurora Dreams',
          'assets': {
            'audio': 'https://cdn/audio.m4a',
            'video': 'https://cdn/video.mp4',
            'frames': ['f1', 'f2'],
          },
          'youtube_video_id': 'abc123',
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final experience = await service.generateStory(
        StoryGenerationRequest(prompt: 'test', theme: 'Aurora Dreams'),
      );

      expect(experience.theme, 'Aurora Dreams');
      expect(experience.audioUrl, 'https://cdn/audio.m4a');
      expect(experience.youtubeUrl, 'https://www.youtube.com/watch?v=abc123');
      expect(experience.frames, hasLength(2));
    });

    test('generateStory throws StoryServiceException on error response',
        () async {
      final service = buildService(
        (_) => http.Response('nope', 500),
      );

      expect(
        () => service.generateStory(
          StoryGenerationRequest(prompt: 'bad', theme: 'Error'),
        ),
        throwsA(isA<StoryServiceException>()),
      );
    });

    test('getHistory caches API result and serves from cache on failure',
        () async {
      final sessionsPayload = {
        'sessions': [
          {
            'session_id': 's1',
            'theme': 'Oceanic Serenity',
            'prompt': 'waves',
            'thumbnail_url': 'thumb',
            'created_at': DateTime.now().toIso8601String(),
          }
        ],
      };

      final service = buildService((request) {
        if (request.url.path == '/api/v1/history') {
          return http.Response(jsonEncode(sessionsPayload), 200);
        }
        fail('Unexpected endpoint ${request.url}');
      });

      final firstFetch = await service.getHistory(
          userId: 'user-123', limit: 5, forceRefresh: true);
      expect(firstFetch, hasLength(1));

      // Simulate offline by using a failing client but shared cache.
      final offlineService = StoryService(
        baseUrl: 'http://localhost:8080',
        client: MockClient((_) async => http.Response('offline', 500)),
        preferences: () async => prefs,
      );

      final cached =
          await offlineService.getHistory(userId: 'user-123', limit: 5);
      expect(cached, hasLength(1));
      expect(cached.first.theme, 'Oceanic Serenity');
    });

    test('clearHistoryCache removes cached state', () async {
      final service = buildService((request) {
        if (request.url.path == '/api/v1/history') {
          return http.Response(
            jsonEncode({
              'sessions': [
                {
                  'session_id': 's1',
                  'theme': 'Zen',
                  'prompt': 'calm',
                  'created_at': DateTime.now().toIso8601String(),
                }
              ],
            }),
            200,
          );
        }
        throw UnimplementedError();
      });

      await service.getHistory(userId: 'abc', limit: 1);
      expect(prefs.getString('session_history_cache'), isNotNull);

      await service.clearHistoryCache();

      expect(prefs.getString('session_history_cache'), isNull);
      expect(prefs.getInt('session_history_cache_timestamp'), isNull);
    });
  });
}
