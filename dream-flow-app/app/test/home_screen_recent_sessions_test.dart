/*
Unit tests for SessionHistoryItem used by the HomeScreen recent sessions UI.
*/

import 'package:flutter_test/flutter_test.dart';

import 'package:dream_flow/core/story_service.dart';

void main() {
  group('SessionHistoryItem', () {
    test('SessionHistoryItem can be created from JSON', () {
      final json = {
        'session_id': 'test-session-id',
        'theme': 'Oceanic Serenity',
        'prompt': 'A peaceful ocean journey',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'created_at': '2024-01-01T10:00:00Z',
      };

      final item = SessionHistoryItem.fromJson(json);

      expect(item.sessionId, 'test-session-id');
      expect(item.theme, 'Oceanic Serenity');
      expect(item.prompt, 'A peaceful ocean journey');
      expect(item.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(item.createdAt, '2024-01-01T10:00:00Z');
    });

    test('SessionHistoryItem handles null thumbnail_url', () {
      final json = {
        'session_id': 'test-session-id',
        'theme': 'Oceanic Serenity',
        'prompt': 'A peaceful ocean journey',
        'created_at': '2024-01-01T10:00:00Z',
      };

      final item = SessionHistoryItem.fromJson(json);

      expect(item.thumbnailUrl, isNull);
    });

    test('SessionHistoryItem can be converted to JSON', () {
      final item = SessionHistoryItem(
        sessionId: 'test-session-id',
        theme: 'Oceanic Serenity',
        prompt: 'A peaceful ocean journey',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        createdAt: '2024-01-01T10:00:00Z',
      );

      final json = item.toJson();

      expect(json['session_id'], 'test-session-id');
      expect(json['theme'], 'Oceanic Serenity');
      expect(json['prompt'], 'A peaceful ocean journey');
      expect(json['thumbnail_url'], 'https://example.com/thumb.jpg');
      expect(json['created_at'], '2024-01-01T10:00:00Z');
    });
  });
}

