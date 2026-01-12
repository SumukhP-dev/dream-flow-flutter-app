import 'dart:typed_data';

import 'package:dream_flow/services/moodboard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Moodboard offline loop caching', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('loops survive network failures', (tester) async {
      final service = MoodboardService(
        baseUrl: 'http://localhost:8080',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response('network down', 500);
          }
          return http.Response('test response', 200);
        }),
      );

      final inspiration = MoodboardInspiration.photo(
        bytes: Uint8List.fromList(List<int>.generate(16, (i) => i)),
        caption: 'Test loop',
      );

      final result = await service.uploadInspiration(
        inspiration,
        sessionId: 'integration_session',
      );

      expect(result.frames, isNotEmpty);

      final offlineFrames = await service.ensureOfflineLoop(
        'integration_session',
        result.frames,
      );

      expect(offlineFrames, isNotEmpty);
      expect(offlineFrames.every((frame) => frame.startsWith('data:image')), isTrue);
    });
  });
}


