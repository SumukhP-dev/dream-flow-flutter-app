import 'dart:convert';

import 'package:dream_flow/services/quest_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late QuestService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = QuestService();
  });

  group('QuestService', () {
    test('getQuests seeds defaults when storage empty', () async {
      final quests = await service.getQuests();

      expect(quests, hasLength(CalmQuest.defaults.length));
      expect(quests.first.steps, isNotEmpty);
    });

    test('updateQuestProgress clamps progress and saves state', () async {
      var quests = await service.getQuests();
      final quest = quests.first;

      await service.updateQuestProgress(
        questId: quest.id,
        completedSteps: quest.steps.length + 5,
      );

      quests = await service.getQuests();
      final updated = quests.firstWhere((q) => q.id == quest.id);
      expect(updated.completedSteps, quest.steps.length);
      expect(updated.isComplete, isTrue);
    });

    test('claimReward marks quest as claimed', () async {
      var quests = await service.getQuests();
      final quest = quests.first;

      await service.updateQuestProgress(
        questId: quest.id,
        completedSteps: quest.steps.length,
      );
      await service.claimReward(quest.id);

      quests = await service.getQuests();
      final updated = quests.firstWhere((q) => q.id == quest.id);
      expect(updated.claimed, isTrue);
    });

    test('stored JSON is compatible with CalmQuest.fromJson', () async {
      final quests = await service.getQuests();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('calm_quests');
      expect(raw, isNotEmpty);

      final decoded = jsonDecode(raw!) as List<dynamic>;
      final roundTripped = decoded
          .map((item) => CalmQuest.fromJson(item as Map<String, dynamic>))
          .toList();

      expect(roundTripped.map((e) => e.id), quests.map((e) => e.id));
    });
  });
}


