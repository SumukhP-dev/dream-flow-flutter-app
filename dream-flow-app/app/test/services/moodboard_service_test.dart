import 'dart:convert';
import 'dart:typed_data';

import 'package:dream_flow/services/moodboard_service.dart';
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

  group('MoodboardService', () {
    test('uploadInspiration caches normalized frames on success', () async {
      var frameDownloads = 0;
      final service = MoodboardService(
        baseUrl: 'http://localhost:8080',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final response = {
              'preview_url': 'https://cdn/preview.png',
              'frames': [
                'https://cdn/frame1.png',
                'https://cdn/frame2.png',
              ],
              'requires_moderation': false,
            };
            return http.Response(jsonEncode(response), 200);
          }
          frameDownloads++;
          return http.Response.bytes(List<int>.filled(4, 1), 200);
        }),
      );

      final result = await service.uploadInspiration(
        MoodboardInspiration.photo(
          bytes: Uint8List.fromList([1, 2, 3]),
          caption: 'calm',
        ),
        sessionId: 'session-1',
      );

      expect(result.previewUrl, 'https://cdn/preview.png');
      expect(frameDownloads, 2);

      final cached = await service.loadCachedLoop('session-1');
      expect(cached, hasLength(2));
      expect(cached.first, startsWith('data:image/png;base64,'));
    });

    test('uploadInspiration falls back to local frames on failure', () async {
      final service = MoodboardService(
        baseUrl: 'http://localhost:8080',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response('error', 500);
          }
          return http.Response.bytes(List<int>.filled(8, 2), 200);
        }),
      );

      final result = await service.uploadInspiration(
        MoodboardInspiration.canvas(
          strokes: [
            MoodboardStroke(
              points: const [
                {'x': 0.1, 'y': 0.1},
                {'x': 0.2, 'y': 0.3},
              ],
              width: 2,
              colorHex: 'ff00ff',
            ),
          ],
          caption: 'sketch',
        ),
        sessionId: 'session-2',
      );

      expect(result.frames, isNotEmpty);

      final cached = await service.loadCachedLoop('session-2');
      expect(cached, isNotEmpty);
    });

    test('ensureOfflineLoop stores fallback frames when cache empty', () async {
      final service = MoodboardService(
        baseUrl: 'http://localhost:8080',
        client: MockClient((_) async => http.Response('offline', 500)),
      );

      final frames = await service.ensureOfflineLoop(
        'session-3',
        ['https://cdn/frameA.png'],
      );

      expect(frames, isNotEmpty);
      final persisted = prefs.getString('moodboard_loops');
      expect(persisted, isNotNull);
    });
  });
}


