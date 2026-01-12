import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QuestService {
  static const _storageKey = 'calm_quests';

  Future<List<CalmQuest>> getQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      final defaults = CalmQuest.defaults;
      await prefs.setString(
        _storageKey,
        jsonEncode(defaults.map((quest) => quest.toJson()).toList()),
      );
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => CalmQuest.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return CalmQuest.defaults;
    }
  }

  Future<void> updateQuestProgress({
    required String questId,
    required int completedSteps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final quests = await getQuests();
    final quest = quests.firstWhere((q) => q.id == questId);
    final updatedQuest = quest.copyWith(
      completedSteps: completedSteps.clamp(0, quest.steps.length),
    );
    final index = quests.indexOf(quest);
    quests[index] = updatedQuest;
    await prefs.setString(
      _storageKey,
      jsonEncode(quests.map((quest) => quest.toJson()).toList()),
    );
  }

  Future<void> claimReward(String questId) async {
    final prefs = await SharedPreferences.getInstance();
    final quests = await getQuests();
    final quest = quests.firstWhere((q) => q.id == questId);
    quests[quests.indexOf(quest)] = quest.copyWith(claimed: true);
    await prefs.setString(
      _storageKey,
      jsonEncode(quests.map((quest) => quest.toJson()).toList()),
    );
  }
}

class CalmQuest {
  CalmQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    required this.reward,
    this.completedSteps = 0,
    this.claimed = false,
  });

  final String id;
  final String title;
  final String description;
  final List<QuestStep> steps;
  final QuestReward reward;
  final int completedSteps;
  final bool claimed;

  double get progress => completedSteps / steps.length;
  bool get isComplete => completedSteps >= steps.length;

  CalmQuest copyWith({
    int? completedSteps,
    bool? claimed,
  }) =>
      CalmQuest(
        id: id,
        title: title,
        description: description,
        steps: steps,
        reward: reward,
        completedSteps: completedSteps ?? this.completedSteps,
        claimed: claimed ?? this.claimed,
      );

  factory CalmQuest.fromJson(Map<String, dynamic> json) {
    return CalmQuest(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Quest',
      description: json['description'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((item) => QuestStep.fromJson(item as Map<String, dynamic>))
          .toList(),
      reward: QuestReward.fromJson(
        json['reward'] as Map<String, dynamic>? ?? const {},
      ),
      completedSteps: json['completed_steps'] as int? ?? 0,
      claimed: json['claimed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'steps': steps.map((step) => step.toJson()).toList(),
        'reward': reward.toJson(),
        'completed_steps': completedSteps,
        'claimed': claimed,
      };

  static List<CalmQuest> get defaults => [
        CalmQuest(
          id: 'quest_cozy_cabin',
          title: 'Cozy Cabin Voyager',
          description: 'Complete the Cozy Cabin world three nights this week.',
          steps: const [
            QuestStep(label: 'Night 1 complete'),
            QuestStep(label: 'Night 2 complete'),
            QuestStep(label: 'Night 3 complete'),
          ],
          reward: QuestReward(
            title: 'Printable cabin badge',
            type: 'printable',
          ),
        ),
        CalmQuest(
          id: 'quest_travel_ready',
          title: 'Travel Kit Ready',
          description: 'Download 3 offline packs before your trip.',
          steps: const [
            QuestStep(label: 'Pack 1 prepped'),
            QuestStep(label: 'Pack 2 prepped'),
            QuestStep(label: 'Pack 3 prepped'),
          ],
          reward: QuestReward(
            title: 'Glow fox AR badge',
            type: 'ar',
          ),
        ),
      ];
}

class QuestStep {
  const QuestStep({
    required this.label,
  });
  final String label;

  factory QuestStep.fromJson(Map<String, dynamic> json) {
    return QuestStep(
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'label': label};
}

class QuestReward {
  const QuestReward({
    required this.title,
    required this.type,
  });

  final String title;
  final String type;

  factory QuestReward.fromJson(Map<String, dynamic> json) {
    return QuestReward(
      title: json['title'] as String? ?? 'Reward',
      type: json['type'] as String? ?? 'printable',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'type': type,
      };
}

