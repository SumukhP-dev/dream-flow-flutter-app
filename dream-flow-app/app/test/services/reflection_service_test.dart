import 'dart:convert';

import 'package:dream_flow/services/reflection_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ReflectionService service;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = ReflectionService(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response('{}', 200);
        }
        return http.Response('unavailable', 500);
      }),
    );
  });

  group('ReflectionService', () {
    test('submitReflection persists entry locally when API fails', () async {
      await service.submitReflection(
        mood: ReflectionMood.restless,
        note: 'Heard the wave crash tonight',
      );

      final stored = prefs.getString('reflection_entries');
      expect(stored, isNotNull);
      final decoded = jsonDecode(stored!) as List<dynamic>;
      expect(decoded, isNotEmpty);
    });

    test('getInsights falls back to local analytics', () async {
      await service.submitReflection(
        mood: ReflectionMood.restless,
        note: 'Wave after wave helped calm us',
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await service.submitReflection(
        mood: ReflectionMood.calm,
        note: 'Owl stories kept things peaceful',
      );

      final insights = await service.getInsights();

      expect(insights.entries, isNotEmpty);
      final topicLabels = insights.topics.map((t) => t.label).toList();
      expect(
        topicLabels.any((label) => label == 'Ocean' || label == 'Forest'),
        isTrue,
      );
      expect(insights.recommendations, isNotEmpty);
    });
  });
}


