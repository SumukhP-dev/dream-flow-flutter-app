import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ReflectionService {
  ReflectionService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'BACKEND_URL',
            defaultValue: 'http://10.0.2.2:8080',
          );

  static const _storageKey = 'reflection_entries';
  static const Map<String, List<String>> _keywords = {
    'Ocean': ['wave', 'tide', 'sea', 'ocean'],
    'Forest': ['forest', 'tree', 'owl', 'fox'],
    'Travel': ['plane', 'train', 'hotel', 'travel'],
    'Music': ['song', 'music', 'melody', 'piano'],
  };

  final http.Client _client;
  final String _baseUrl;
  final Uuid _uuid = const Uuid();

  Future<ReflectionEntry> submitReflection({
    String? sessionId,
    required ReflectionMood mood,
    String? note,
    String? audioPath,
    String? transcript,
  }) async {
    final entry = ReflectionEntry(
      id: _uuid.v4(),
      sessionId: sessionId,
      mood: mood,
      note: note,
      audioPath: audioPath,
      transcript: transcript,
      createdAt: DateTime.now(),
    );

    await _persist(entry);

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/reflections');
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(entry.toApiJson()),
      );
    } catch (_) {
      // Offline-safe: keep local copy
    }

    return entry;
  }

  Future<List<ReflectionEntry>> getReflections() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => ReflectionEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ReflectionInsights> getInsights() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/reflections/insights');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return ReflectionInsights.fromJson(payload);
      }
    } catch (_) {
      // Fall back to local analytics when offline or request fails.
    }

    final entries = await getReflections();
    if (entries.isEmpty) {
      return ReflectionInsights.empty();
    }
    return _buildLocalInsights(entries);
  }

  ReflectionInsights _buildLocalInsights(List<ReflectionEntry> entries) {
    if (entries.isEmpty) {
      return ReflectionInsights.empty();
    }

    final moodCounts = <ReflectionMood, int>{};
    for (final entry in entries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }
    final dominantMood = moodCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final streak = _calculateReflectionStreak(entries);
    final topics = _calculateTopics(entries);
    final weeklyClusters = _buildWeeklyClusters(entries);
    final recommendations = _buildRecommendations(entries, weeklyClusters);
    final celebrations = _buildCelebrations(entries, streak, weeklyClusters);

    return ReflectionInsights(
      dominantMood: dominantMood,
      streak: streak,
      topics: topics.take(3).toList(),
      entries: entries.take(15).toList(),
      weeklyClusters: weeklyClusters,
      recommendations: recommendations,
      celebrations: celebrations,
    );
  }

  List<ReflectionTopic> _calculateTopics(List<ReflectionEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final content = (entry.note ?? entry.transcript ?? '').toLowerCase();
      for (final topic in _keywords.entries) {
        if (topic.value.any((needle) => content.contains(needle))) {
          counts[topic.key] = (counts[topic.key] ?? 0) + 1;
        }
      }
    }
    final topics = counts.entries
        .map(
          (entry) => ReflectionTopic(label: entry.key, mentions: entry.value),
        )
        .toList();
    topics.sort((a, b) => b.mentions.compareTo(a.mentions));
    return topics;
  }

  List<ReflectionWeekCluster> _buildWeeklyClusters(
    List<ReflectionEntry> entries,
  ) {
    final buckets = <DateTime, List<ReflectionEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      final weekStart = day.subtract(Duration(days: day.weekday - 1));
      buckets.putIfAbsent(weekStart, () => []).add(entry);
    }

    final clusters = <ReflectionWeekCluster>[];
    final sortedKeys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final date in sortedKeys.take(4)) {
      final bucketEntries = buckets[date]!;
      final moodCounts = <ReflectionMood, int>{};
      final topicCounts = <String, int>{};

      for (final entry in bucketEntries) {
        moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
        for (final topic in _topicsForEntry(entry)) {
          topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
        }
      }

      final dominantMood = moodCounts.entries.isEmpty
          ? ReflectionMood.calm
          : moodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final topTopics = topicCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      clusters.add(
        ReflectionWeekCluster(
          weekStart: date,
          entryCount: bucketEntries.length,
          dominantMood: dominantMood,
          topTopics: topTopics.map((entry) => entry.key).take(3).toList(),
          headline: _clusterHeadline(
            dominantMood,
            topTopics.isEmpty ? null : topTopics.first.key,
          ),
          recommendation: _clusterRecommendation(
            dominantMood,
            topTopics.isEmpty ? null : topTopics.first.key,
            bucketEntries.length,
          ),
        ),
      );
    }

    return clusters;
  }

  List<String> _topicsForEntry(ReflectionEntry entry) {
    final content = (entry.note ?? entry.transcript ?? '').toLowerCase();
    final matches = <String>[];
    for (final topic in _keywords.entries) {
      if (topic.value.any((needle) => content.contains(needle))) {
        matches.add(topic.key);
      }
    }
    return matches;
  }

  String _clusterHeadline(ReflectionMood mood, String? topic) {
    if (topic != null) {
      return '$topic week • ${mood.label} energy';
    }
    return '${mood.label} reflections';
  }

  String _clusterRecommendation(
    ReflectionMood mood,
    String? topic,
    int entryCount,
  ) {
    if (mood == ReflectionMood.restless) {
      return 'Layer an earlier body scan before pressing play to help the body settle.';
    }
    if (mood == ReflectionMood.wiggly) {
      return 'Try a tactile fidget or gentle squeeze game during narration.';
    }
    if (topic != null) {
      return 'Weave tonight\'s prompt back to $topic for narrative continuity.';
    }
    if (entryCount >= 4) {
      return 'You logged a full week—recap the highlights aloud tonight.';
    }
    return 'Log another note to unlock a personalized prompt.';
  }

  List<ReflectionRecommendation> _buildRecommendations(
    List<ReflectionEntry> entries,
    List<ReflectionWeekCluster> clusters,
  ) {
    if (entries.isEmpty) return [];

    final recommendations = <ReflectionRecommendation>[];
    final restlessRatio =
        entries.where((entry) => entry.mood == ReflectionMood.restless).length /
        entries.length;
    if (restlessRatio >= 0.3) {
      recommendations.add(
        ReflectionRecommendation(
          title: 'Cool-down ritual',
          detail:
              'Experiment with box breathing or shoulder squeezes before story time.',
          type: 'ritual',
        ),
      );
    }

    final audioNotes = entries.where((entry) => entry.audioPath != null).length;
    if (audioNotes == 0) {
      recommendations.add(
        ReflectionRecommendation(
          title: 'Attach a whisper note',
          detail:
              'A 30-second voice memo gives DreamFlow richer signals for motifs.',
          type: 'journaling',
        ),
      );
    }

    if (clusters.isNotEmpty && clusters.first.topTopics.isNotEmpty) {
      recommendations.add(
        ReflectionRecommendation(
          title: 'Keep the thread',
          detail:
              'Tonight, invite another detail about ${clusters.first.topTopics.first.toLowerCase()}.',
          type: 'story_seed',
        ),
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        ReflectionRecommendation(
          title: 'Celebrate the practice',
          detail:
              'Share last night\'s note with your child to reinforce the habit loop.',
          type: 'celebration',
        ),
      );
    }

    return recommendations.take(3).toList();
  }

  ReflectionCelebrations _buildCelebrations(
    List<ReflectionEntry> entries,
    int streak,
    List<ReflectionWeekCluster> clusters,
  ) {
    return ReflectionCelebrations(
      badges: _buildBadges(entries, streak, clusters),
      weeklyRecap: _buildWeeklyRecap(entries),
    );
  }

  List<ReflectionBadge> _buildBadges(
    List<ReflectionEntry> entries,
    int streak,
    List<ReflectionWeekCluster> clusters,
  ) {
    final badges = <ReflectionBadge>[];
    if (entries.length >= 5) {
      badges.add(
        ReflectionBadge(
          code: 'mindful_scribe',
          label: 'Mindful Scribe',
          description: 'Logged 5 reflections.',
          unlockedAt: entries[math.min(entries.length - 1, 4)].createdAt,
        ),
      );
    }

    final voiceEntries = entries
        .where((entry) => entry.audioPath != null)
        .toList();
    if (voiceEntries.length >= 3) {
      badges.add(
        ReflectionBadge(
          code: 'voice_archivist',
          label: 'Voice Archivist',
          description: 'Captured 3 calming voice notes.',
          unlockedAt:
              voiceEntries[math.min(voiceEntries.length - 1, 2)].createdAt,
        ),
      );
    }

    if (streak >= 3) {
      badges.add(
        ReflectionBadge(
          code: 'streak_keeper',
          label: 'Streak Keeper',
          description: 'Held a 3-night reflection streak.',
          unlockedAt: entries.first.createdAt,
        ),
      );
    }

    if (clusters.length >= 2) {
      badges.add(
        ReflectionBadge(
          code: 'pattern_spotter',
          label: 'Pattern Spotter',
          description: 'Unlocked multi-week motifs.',
          unlockedAt: entries.first.createdAt,
        ),
      );
    }

    return badges;
  }

  ReflectionWeeklyRecap _buildWeeklyRecap(List<ReflectionEntry> entries) {
    if (entries.isEmpty) {
      return ReflectionWeeklyRecap.empty();
    }
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final recent = entries
        .where(
          (entry) =>
              entry.createdAt.isAfter(cutoff) ||
              entry.createdAt.isAtSameMomentAs(cutoff),
        )
        .toList();
    final topics = <String>{};
    for (final entry in recent) {
      topics.addAll(_topicsForEntry(entry));
    }
    return ReflectionWeeklyRecap(
      entriesLogged: recent.length,
      audioNotes: recent.where((entry) => entry.audioPath != null).length,
      newTopics: (topics.toList()..sort()),
    );
  }

  Future<void> _persist(ReflectionEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getReflections();
    final updated = [entry, ...existing]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trimmed = updated.take(60).toList();
    await prefs.setString(
      _storageKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  int _calculateReflectionStreak(List<ReflectionEntry> entries) {
    if (entries.isEmpty) return 0;

    final sorted = List<ReflectionEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int streak = 0;
    DateTime? lastDate;

    for (final entry in sorted) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      if (lastDate == null) {
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        final yesterday = todayOnly.subtract(const Duration(days: 1));
        if (day == todayOnly || day == yesterday) {
          streak = 1;
          lastDate = day;
        } else {
          break;
        }
      } else {
        final expected = lastDate.subtract(const Duration(days: 1));
        if (day == expected || day == lastDate) {
          if (day == expected) {
            streak++;
          }
          lastDate = day;
        } else {
          break;
        }
      }
    }

    return streak;
  }
}

class ReflectionEntry {
  ReflectionEntry({
    required this.id,
    required this.mood,
    this.sessionId,
    this.note,
    this.audioPath,
    this.transcript,
    required this.createdAt,
  });

  final String id;
  final String? sessionId;
  final ReflectionMood mood;
  final String? note;
  final String? audioPath;
  final String? transcript;
  final DateTime createdAt;

  factory ReflectionEntry.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] as String?;
    return ReflectionEntry(
      id: json['id'] as String,
      sessionId: json['session_id'] as String?,
      mood: ReflectionMood.fromName(json['mood'] as String?),
      note: json['note'] as String?,
      audioPath: (json['audio_path'] ?? json['audio_url']) as String?,
      transcript: json['transcript'] as String?,
      createdAt: createdAtRaw != null
          ? DateTime.parse(createdAtRaw)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'mood': mood.name,
    'note': note,
    'audio_path': audioPath,
    'transcript': transcript,
    'created_at': createdAt.toIso8601String(),
  };

  Map<String, dynamic> toApiJson() => {
    'id': id,
    'session_id': sessionId,
    'mood': mood.name,
    'note': note,
    'transcript': transcript,
    'audio_url': audioPath,
    'created_at': createdAt.toIso8601String(),
  };
}

enum ReflectionMood {
  veryCalm('😴'),
  calm('😊'),
  neutral('😐'),
  wiggly('😅'),
  restless('😣');

  const ReflectionMood(this.emoji);
  final String emoji;

  String get label {
    switch (this) {
      case ReflectionMood.veryCalm:
        return 'Very calm';
      case ReflectionMood.calm:
        return 'Calm';
      case ReflectionMood.neutral:
        return 'Curious';
      case ReflectionMood.wiggly:
        return 'Wiggly';
      case ReflectionMood.restless:
        return 'Restless';
    }
  }

  static ReflectionMood fromName(String? value) {
    if (value == null) return ReflectionMood.calm;
    return ReflectionMood.values.firstWhere(
      (mood) => mood.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ReflectionMood.calm,
    );
  }
}

class ReflectionInsights {
  ReflectionInsights({
    required this.dominantMood,
    required this.streak,
    required this.topics,
    required this.entries,
    required this.weeklyClusters,
    required this.recommendations,
    required this.celebrations,
  });

  final ReflectionMood dominantMood;
  final int streak;
  final List<ReflectionTopic> topics;
  final List<ReflectionEntry> entries;
  final List<ReflectionWeekCluster> weeklyClusters;
  final List<ReflectionRecommendation> recommendations;
  final ReflectionCelebrations celebrations;

  factory ReflectionInsights.empty() => ReflectionInsights(
    dominantMood: ReflectionMood.calm,
    streak: 0,
    topics: const [],
    entries: const [],
    weeklyClusters: const [],
    recommendations: const [],
    celebrations: ReflectionCelebrations.empty(),
  );

  factory ReflectionInsights.fromJson(Map<String, dynamic> json) {
    final topics = (json['topics'] as List<dynamic>? ?? [])
        .map((item) => ReflectionTopic.fromJson(_asJsonMap(item)))
        .toList();
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .map((item) => ReflectionEntry.fromJson(_asJsonMap(item)))
        .toList();
    final weeklyClusters = (json['weekly_clusters'] as List<dynamic>? ?? [])
        .map((item) => ReflectionWeekCluster.fromJson(_asJsonMap(item)))
        .toList();
    final recommendations = (json['recommendations'] as List<dynamic>? ?? [])
        .map((item) => ReflectionRecommendation.fromJson(_asJsonMap(item)))
        .toList();

    return ReflectionInsights(
      dominantMood: ReflectionMood.fromName(json['dominant_mood'] as String?),
      streak: json['streak'] as int? ?? 0,
      topics: topics,
      entries: entries,
      weeklyClusters: weeklyClusters,
      recommendations: recommendations,
      celebrations: json['celebrations'] is Map
          ? ReflectionCelebrations.fromJson(_asJsonMap(json['celebrations']))
          : ReflectionCelebrations.empty(),
    );
  }
}

class ReflectionTopic {
  ReflectionTopic({required this.label, this.mentions = 0});

  final String label;
  int mentions;

  factory ReflectionTopic.fromJson(Map<String, dynamic> json) {
    return ReflectionTopic(
      label: json['label'] as String? ?? '',
      mentions: json['mentions'] as int? ?? 0,
    );
  }
}

class ReflectionWeekCluster {
  ReflectionWeekCluster({
    required this.weekStart,
    required this.entryCount,
    required this.dominantMood,
    required this.topTopics,
    required this.headline,
    required this.recommendation,
  });

  final DateTime weekStart;
  final int entryCount;
  final ReflectionMood dominantMood;
  final List<String> topTopics;
  final String headline;
  final String recommendation;

  factory ReflectionWeekCluster.fromJson(Map<String, dynamic> json) {
    final weekRaw = json['week_start'] as String?;
    return ReflectionWeekCluster(
      weekStart: weekRaw != null ? DateTime.parse(weekRaw) : DateTime.now(),
      entryCount: json['entry_count'] as int? ?? 0,
      dominantMood: ReflectionMood.fromName(json['dominant_mood'] as String?),
      topTopics: (json['top_topics'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      headline: json['headline'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }
}

class ReflectionRecommendation {
  ReflectionRecommendation({
    required this.title,
    required this.detail,
    required this.type,
  });

  final String title;
  final String detail;
  final String type;

  factory ReflectionRecommendation.fromJson(Map<String, dynamic> json) {
    return ReflectionRecommendation(
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      type: json['type'] as String? ?? 'habit',
    );
  }
}

class ReflectionBadge {
  ReflectionBadge({
    required this.code,
    required this.label,
    required this.description,
    this.unlockedAt,
  });

  final String code;
  final String label;
  final String description;
  final DateTime? unlockedAt;

  factory ReflectionBadge.fromJson(Map<String, dynamic> json) {
    final unlockedRaw = json['unlocked_at'] as String?;
    return ReflectionBadge(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      unlockedAt: unlockedRaw != null ? DateTime.parse(unlockedRaw) : null,
    );
  }
}

class ReflectionWeeklyRecap {
  ReflectionWeeklyRecap({
    required this.entriesLogged,
    required this.audioNotes,
    required this.newTopics,
  });

  final int entriesLogged;
  final int audioNotes;
  final List<String> newTopics;

  factory ReflectionWeeklyRecap.empty() => ReflectionWeeklyRecap(
    entriesLogged: 0,
    audioNotes: 0,
    newTopics: const [],
  );

  factory ReflectionWeeklyRecap.fromJson(Map<String, dynamic> json) {
    return ReflectionWeeklyRecap(
      entriesLogged: json['entries_logged'] as int? ?? 0,
      audioNotes: json['audio_notes'] as int? ?? 0,
      newTopics: (json['new_topics'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class ReflectionCelebrations {
  ReflectionCelebrations({required this.badges, required this.weeklyRecap});

  final List<ReflectionBadge> badges;
  final ReflectionWeeklyRecap weeklyRecap;

  factory ReflectionCelebrations.empty() => ReflectionCelebrations(
    badges: const [],
    weeklyRecap: ReflectionWeeklyRecap.empty(),
  );

  factory ReflectionCelebrations.fromJson(Map<String, dynamic> json) {
    return ReflectionCelebrations(
      badges: (json['badges'] as List<dynamic>? ?? [])
          .map((item) => ReflectionBadge.fromJson(_asJsonMap(item)))
          .toList(),
      weeklyRecap: json['weekly_recap'] != null
          ? ReflectionWeeklyRecap.fromJson(_asJsonMap(json['weekly_recap']))
          : ReflectionWeeklyRecap.empty(),
    );
  }
}

Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return {};
}
