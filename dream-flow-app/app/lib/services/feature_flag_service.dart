import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeatureFlag {
  maestro('maestro_enabled'),
  moodboard('moodboard_beta'),
  reflections('reflections_enabled'),
  travel('travel_companion_enabled'),
  smartScenes('smart_scene_enabled'),
  neuroTracks('neuro_tracks_enabled'),
  calmQuests('calm_quests_enabled');

  const FeatureFlag(this.key);
  final String key;
}

class FeatureFlagService {
  FeatureFlagService._();

  static final FeatureFlagService _instance = FeatureFlagService._();
  factory FeatureFlagService() => _instance;

  static const _overridePrefsKey = 'feature_flag_overrides';
  Map<String, bool>? _overridesCache;
  Map<String, bool>? _envFlagsCache;
  Map<String, bool>? _debugEnvOverrides;

  final Map<String, bool> _defaults = const {
    'maestro_enabled': true,
    'moodboard_beta': true,
    'reflections_enabled': true,
    'travel_companion_enabled': true,
    'smart_scene_enabled': true,
    'neuro_tracks_enabled': true,
    'calm_quests_enabled': true,
  };

  Future<bool> isEnabled(FeatureFlag flag) async {
    final overrides = await _loadOverrides();
    if (overrides.containsKey(flag.key)) {
      return overrides[flag.key]!;
    }
    final envValue = _loadEnvFlags()[flag.key];
    if (envValue != null) {
      return envValue;
    }
    return _defaults[flag.key] ?? true;
  }

  Future<Map<String, bool>> getOverrides() async {
    return Map<String, bool>.from(await _loadOverrides());
  }

  Future<void> setOverride(FeatureFlag flag, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = await _loadOverrides();
    overrides[flag.key] = enabled;
    _overridesCache = overrides;
    await prefs.setString(_overridePrefsKey, jsonEncode(overrides));
  }

  Future<void> clearOverride(FeatureFlag flag) async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = await _loadOverrides();
    overrides.remove(flag.key);
    _overridesCache = overrides;
    if (overrides.isEmpty) {
      await prefs.remove(_overridePrefsKey);
    } else {
      await prefs.setString(_overridePrefsKey, jsonEncode(overrides));
    }
  }

  Future<Map<String, bool>> _loadOverrides() async {
    if (_overridesCache != null) {
      return _overridesCache!;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_overridePrefsKey);
    if (raw == null || raw.isEmpty) {
      _overridesCache = {};
      return _overridesCache!;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = decoded.map(
        (key, value) => MapEntry(key, value == true),
      );
      _overridesCache = parsed;
      return parsed;
    } catch (_) {
      _overridesCache = {};
      return _overridesCache!;
    }
  }

  Map<String, bool> _loadEnvFlags() {
    if (_debugEnvOverrides != null) {
      return _debugEnvOverrides!;
    }
    if (_envFlagsCache != null) {
      return _envFlagsCache!;
    }
    final raw = const String.fromEnvironment('FEATURE_FLAGS', defaultValue: '');
    if (raw.isEmpty) {
      _envFlagsCache = {};
      return _envFlagsCache!;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _envFlagsCache = decoded.map(
        (key, value) => MapEntry(key, value == true),
      );
      return _envFlagsCache!;
    } catch (_) {
      _envFlagsCache = {};
      return _envFlagsCache!;
    }
  }

  @visibleForTesting
  void debugReset() {
    _overridesCache = null;
    _envFlagsCache = null;
    _debugEnvOverrides = null;
  }

  @visibleForTesting
  void debugOverrideEnvFlags(Map<String, bool>? flags) {
    _debugEnvOverrides = flags;
    _envFlagsCache = flags != null ? Map<String, bool>.from(flags) : null;
  }
}

