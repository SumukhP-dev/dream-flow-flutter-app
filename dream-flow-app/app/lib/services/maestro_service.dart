import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaestroService {
  MaestroService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8080',
            );

  final http.Client _client;
  final String _baseUrl;

  static const _cacheKey = 'maestro_insights_cache';

  Future<MaestroInsights> getInsights({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _loadCachedInsights();
      if (cached != null) {
        return cached;
      }
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final uri = Uri.parse('$_baseUrl/api/v1/maestro/insights')
          .replace(queryParameters: userId != null ? {'user_id': userId} : null);
      final response = await _client.get(uri, headers: _buildHeaders());

      if (response.statusCode >= 400) {
        throw MaestroServiceException(
          'Failed to load insights (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final insights = MaestroInsights.fromJson(decoded);
      await _cacheInsights(insights);
      return insights;
    } catch (error) {
      final cached = await _loadCachedInsights();
      if (cached != null) {
        return cached;
      }
      return MaestroInsights.demo();
    }
  }

  Future<void> triggerQuickAction(
    String actionId, {
    double? sliderValue,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/maestro/quick-actions');
      final payload = <String, dynamic>{
        'action_id': actionId,
        if (sliderValue != null) 'value': sliderValue,
      };
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        payload['user_id'] = userId;
      }
      final response = await _client.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 400) {
        throw MaestroServiceException(
          'Unable to trigger quick action (${response.statusCode})',
        );
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _cacheInsights(MaestroInsights insights) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(insights.toJson()));
  }

  Future<MaestroInsights?> _loadCachedInsights() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MaestroInsights.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = {'Content-Type': 'application/json'};
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    return headers;
  }
}

class MaestroServiceException implements Exception {
  MaestroServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MaestroInsights {
  MaestroInsights({
    required this.nightlyTip,
    required this.trends,
    required this.environment,
    required this.quickActions,
    required this.streakDays,
    required this.hasTravelShift,
  });

  final MaestroTip nightlyTip;
  final List<MaestroTrend> trends;
  final EnvironmentInsights environment;
  final List<MaestroQuickAction> quickActions;
  final int streakDays;
  final bool hasTravelShift;

  factory MaestroInsights.fromJson(Map<String, dynamic> json) {
    return MaestroInsights(
      nightlyTip: MaestroTip.fromJson(
        json['nightly_tip'] as Map<String, dynamic>? ??
            MaestroTip.demo().toJson(),
      ),
      trends: (json['streaks'] as List<dynamic>? ?? [])
          .map((item) => MaestroTrend.fromJson(item as Map<String, dynamic>))
          .toList(),
      environment: EnvironmentInsights.fromJson(
        json['environment'] as Map<String, dynamic>? ??
            EnvironmentInsights.demo().toJson(),
      ),
      quickActions: (json['quick_actions'] as List<dynamic>? ?? [])
          .map(
            (item) => MaestroQuickAction.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      streakDays: json['streak_days'] as int? ?? 0,
      hasTravelShift: json['has_travel_shift'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'nightly_tip': nightlyTip.toJson(),
        'streaks': trends.map((trend) => trend.toJson()).toList(),
        'environment': environment.toJson(),
        'quick_actions': quickActions.map((action) => action.toJson()).toList(),
        'streak_days': streakDays,
        'has_travel_shift': hasTravelShift,
      };

  factory MaestroInsights.demo() {
    return MaestroInsights(
      nightlyTip: MaestroTip.demo(),
      trends: MaestroTrend.demoList(),
      environment: EnvironmentInsights.demo(),
      quickActions: MaestroQuickAction.demoList(),
      streakDays: 6,
      hasTravelShift: true,
    );
  }
}

class MaestroTip {
  final String title;
  final String description;
  final String microAdjustment;
  final double confidence;

  MaestroTip({
    required this.title,
    required this.description,
    required this.microAdjustment,
    required this.confidence,
  });

  factory MaestroTip.fromJson(Map<String, dynamic> json) {
    return MaestroTip(
      title: json['title'] as String? ?? 'Tonight’s Micro-Adjustment',
      description: json['description'] as String? ??
          'Lean into the lantern breathing ritual — it already shortens the wind-down by 6 minutes.',
      microAdjustment: json['micro_adjustment'] as String? ??
          'Dim lights 20 minutes earlier and layer lavender diffuser on low.',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.82,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'micro_adjustment': microAdjustment,
        'confidence': confidence,
      };

  factory MaestroTip.demo() => MaestroTip(
        title: 'Tonight’s Micro-Adjustment',
        description:
            'Nova falls asleep 12 minutes faster when wind-down starts by 8:15 pm.',
        microAdjustment:
            'Shift baths 10 minutes earlier and cue “Silver Lantern” story arc.',
        confidence: 0.87,
      );
}

class MaestroTrend {
  final String label;
  final double deltaMinutes;
  final TrendDirection direction;

  MaestroTrend({
    required this.label,
    required this.deltaMinutes,
    required this.direction,
  });

  factory MaestroTrend.fromJson(Map<String, dynamic> json) {
    final directionRaw = (json['direction'] as String?)?.toLowerCase();
    return MaestroTrend(
      label: json['label'] as String? ?? 'Bedtime drift',
      deltaMinutes: (json['delta_minutes'] as num?)?.toDouble() ?? 0,
      direction: directionRaw == 'up'
          ? TrendDirection.up
          : directionRaw == 'steady'
              ? TrendDirection.steady
              : TrendDirection.down,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'delta_minutes': deltaMinutes,
        'direction': direction.name,
      };

  static List<MaestroTrend> demoList() => [
        MaestroTrend(
          label: 'Bedtime drift',
          deltaMinutes: -8,
          direction: TrendDirection.down,
        ),
        MaestroTrend(
          label: 'Energy settling',
          deltaMinutes: 5,
          direction: TrendDirection.up,
        ),
        MaestroTrend(
          label: 'Travel recovery',
          deltaMinutes: 2,
          direction: TrendDirection.steady,
        ),
      ];
}

enum TrendDirection { up, down, steady }

class EnvironmentInsights {
  final double lightingScore;
  final double scentScore;
  final List<String> quickNotes;

  EnvironmentInsights({
    required this.lightingScore,
    required this.scentScore,
    required this.quickNotes,
  });

  factory EnvironmentInsights.fromJson(Map<String, dynamic> json) {
    return EnvironmentInsights(
      lightingScore: (json['lighting_score'] as num?)?.toDouble() ?? 0.7,
      scentScore: (json['scent_score'] as num?)?.toDouble() ?? 0.6,
      quickNotes: (json['notes'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lighting_score': lightingScore,
        'scent_score': scentScore,
        'notes': quickNotes,
      };

  factory EnvironmentInsights.demo() => EnvironmentInsights(
        lightingScore: 0.82,
        scentScore: 0.66,
        quickNotes: const [
          'Nova yawns within 3 minutes when diffuser is on amber mode.',
          'Noise floor spikes on Tuesdays — consider white-noise pad.',
        ],
      );
}

class MaestroQuickAction {
  final String id;
  final String label;
  final String icon;
  final double? value;
  final double? min;
  final double? max;

  MaestroQuickAction({
    required this.id,
    required this.label,
    required this.icon,
    this.value,
    this.min,
    this.max,
  });

  factory MaestroQuickAction.fromJson(Map<String, dynamic> json) {
    return MaestroQuickAction(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Action',
      icon: json['icon'] as String? ?? '🕯️',
      value: (json['value'] as num?)?.toDouble(),
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'icon': icon,
        if (value != null) 'value': value,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };

  static List<MaestroQuickAction> demoList() => [
        MaestroQuickAction(
          id: 'lights_dim',
          label: 'Dim nursery lights',
          icon: '💡',
          value: 40,
          min: 10,
          max: 80,
        ),
        MaestroQuickAction(
          id: 'diffuser',
          label: 'Lavender diffuser',
          icon: '🌫️',
        ),
        MaestroQuickAction(
          id: 'soundscape',
          label: 'Travel comfort scene',
          icon: '🎧',
        ),
      ];
}

