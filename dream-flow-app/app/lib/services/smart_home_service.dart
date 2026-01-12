import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SmartHomeService {
  SmartHomeService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8080',
            );

  final http.Client _client;
  final String _baseUrl;

  static const _scenesKey = 'smart_scenes';
  static const _devicesKey = 'smart_devices';

  Future<List<SmartScene>> getScenes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scenesKey);
    if (raw == null) {
      final defaults = SmartScene.defaults;
      await saveScenes(defaults);
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => SmartScene.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return SmartScene.defaults;
    }
  }

  Future<void> saveScenes(List<SmartScene> scenes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scenesKey,
      jsonEncode(scenes.map((scene) => scene.toJson()).toList()),
    );
  }

  Future<void> upsertScene(SmartScene scene) async {
    final scenes = await getScenes();
    scenes.removeWhere((item) => item.id == scene.id);
    scenes.add(scene);
    await saveScenes(scenes);
  }

  Future<void> triggerScene(String sceneId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/smart-scenes/run');
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'scene_id': sceneId}),
      );
    } catch (_) {
      // Allow offline fallback
    }
  }

  Future<List<SmartDevice>> getDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_devicesKey);
    if (raw == null) {
      final defaults = SmartDevice.defaults;
      await prefs.setString(
        _devicesKey,
        jsonEncode(defaults.map((e) => e.toJson()).toList()),
      );
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => SmartDevice.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return SmartDevice.defaults;
    }
  }

  Future<void> linkDevice(SmartDevice device) async {
    final devices = await getDevices();
    devices.removeWhere((item) => item.id == device.id);
    devices.add(device);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _devicesKey,
      jsonEncode(devices.map((e) => e.toJson()).toList()),
    );
  }
}

class SmartScene {
  SmartScene({
    required this.id,
    required this.name,
    required this.description,
    required this.actions,
    this.ritualTag = 'family',
  });

  final String id;
  final String name;
  final String description;
  final String ritualTag;
  final List<SceneAction> actions;

  factory SmartScene.fromJson(Map<String, dynamic> json) {
    return SmartScene(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Scene',
      description: json['description'] as String? ?? '',
      ritualTag: json['ritual_tag'] as String? ?? 'family',
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((item) => SceneAction.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'ritual_tag': ritualTag,
        'actions': actions.map((action) => action.toJson()).toList(),
      };

  static List<SmartScene> get defaults => [
        SmartScene(
          id: 'scene_family',
          name: 'Family Hearth',
          description: 'Dim lights 40%, lavender diffuser, gentle chimes.',
          ritualTag: 'family',
          actions: [
            SceneAction(deviceType: 'lights', value: '40%'),
            SceneAction(deviceType: 'diffuser', value: 'lavender_low'),
            SceneAction(deviceType: 'sound', value: 'gentle_chimes'),
          ],
        ),
        SmartScene(
          id: 'scene_travel',
          name: 'Travel Comfort',
          description: 'Hotel lamp to warm glow + lullaby soundscape.',
          ritualTag: 'travel',
          actions: [
            SceneAction(deviceType: 'lights', value: 'warm_glow'),
            SceneAction(deviceType: 'sound', value: 'voyager_lullaby'),
          ],
        ),
      ];
}

class SceneAction {
  SceneAction({
    required this.deviceType,
    required this.value,
    this.delaySeconds = 0,
  });

  final String deviceType;
  final String value;
  final int delaySeconds;

  factory SceneAction.fromJson(Map<String, dynamic> json) {
    return SceneAction(
      deviceType: json['device_type'] as String? ?? 'lights',
      value: json['value'] as String? ?? '',
      delaySeconds: json['delay'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'device_type': deviceType,
        'value': value,
        'delay': delaySeconds,
      };
}

class SmartDevice {
  SmartDevice({
    required this.id,
    required this.platform,
    required this.displayName,
    required this.capabilities,
    this.linked = true,
  });

  final String id;
  final String platform;
  final String displayName;
  final List<String> capabilities;
  final bool linked;

  factory SmartDevice.fromJson(Map<String, dynamic> json) {
    return SmartDevice(
      id: json['id'] as String,
      platform: json['platform'] as String? ?? 'alexa',
      displayName: json['display_name'] as String? ?? 'Device',
      capabilities: (json['capabilities'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      linked: json['linked'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'display_name': displayName,
        'capabilities': capabilities,
        'linked': linked,
      };

  static List<SmartDevice> get defaults => [
        SmartDevice(
          id: 'alexa_living',
          platform: 'alexa',
          displayName: 'Alexa Living Room',
          capabilities: const ['lights', 'diffuser', 'sound'],
        ),
        SmartDevice(
          id: 'homekit_nursery',
          platform: 'homekit',
          displayName: 'Nursery HomeKit',
          capabilities: const ['lights', 'blinds'],
        ),
      ];
}

