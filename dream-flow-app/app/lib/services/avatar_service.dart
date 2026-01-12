import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Avatar customization options
class AvatarOptions {
  final String faceType;
  final String hairType;
  final String hairColor;
  final String skinColor;
  final String clothingType;
  final String clothingColor;
  final String? accessory;

  AvatarOptions({
    required this.faceType,
    required this.hairType,
    required this.hairColor,
    required this.skinColor,
    required this.clothingType,
    required this.clothingColor,
    this.accessory,
  });

  Map<String, dynamic> toJson() => {
        'face_type': faceType,
        'hair_type': hairType,
        'hair_color': hairColor,
        'skin_color': skinColor,
        'clothing_type': clothingType,
        'clothing_color': clothingColor,
        if (accessory != null) 'accessory': accessory,
      };

  factory AvatarOptions.fromJson(Map<String, dynamic> json) {
    return AvatarOptions(
      faceType: json['face_type'] as String? ?? 'default',
      hairType: json['hair_type'] as String? ?? 'default',
      hairColor: json['hair_color'] as String? ?? '#000000',
      skinColor: json['skin_color'] as String? ?? '#FFDBAC',
      clothingType: json['clothing_type'] as String? ?? 'default',
      clothingColor: json['clothing_color'] as String? ?? '#4A90E2',
      accessory: json['accessory'] as String?,
    );
  }

  AvatarOptions copyWith({
    String? faceType,
    String? hairType,
    String? hairColor,
    String? skinColor,
    String? clothingType,
    String? clothingColor,
    String? accessory,
  }) {
    return AvatarOptions(
      faceType: faceType ?? this.faceType,
      hairType: hairType ?? this.hairType,
      hairColor: hairColor ?? this.hairColor,
      skinColor: skinColor ?? this.skinColor,
      clothingType: clothingType ?? this.clothingType,
      clothingColor: clothingColor ?? this.clothingColor,
      accessory: accessory ?? this.accessory,
    );
  }
}

/// Avatar model
class Avatar {
  final String id;
  final String userId;
  final String? childProfileId;
  final AvatarOptions options;
  final String name;
  final bool isDefault;
  final DateTime createdAt;

  Avatar({
    required this.id,
    required this.userId,
    this.childProfileId,
    required this.options,
    required this.name,
    this.isDefault = false,
    required this.createdAt,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      childProfileId: json['child_profile_id'] as String?,
      options: AvatarOptions.fromJson(
        json['avatar_data'] as Map<String, dynamic>? ?? {},
      ),
      name: json['name'] as String? ?? 'My Avatar',
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        if (childProfileId != null) 'child_profile_id': childProfileId,
        'avatar_data': options.toJson(),
        'name': name,
        'is_default': isDefault,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Service for managing avatars
class AvatarService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _localStorageKey = 'local_avatars';

  /// Get all avatars for a user or child
  Future<List<Avatar>> getAvatars({
    String? userId,
    String? childProfileId,
  }) async {
    try {
      if (childProfileId != null) {
        final response = await _supabase
            .from('user_avatars')
            .select('*')
            .eq('child_profile_id', childProfileId)
            .order('created_at', ascending: false);

        return (response as List)
            .map((json) => Avatar.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (userId != null) {
        final response = await _supabase
            .from('user_avatars')
            .select('*')
            .eq('user_id', userId)
            .isFilter('child_profile_id', null)
            .order('created_at', ascending: false);

        return (response as List)
            .map((json) => Avatar.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      // Fall back to local storage
      return _getLocalAvatars(childProfileId: childProfileId);
    }
  }

  /// Get default avatar for a child
  Future<Avatar?> getDefaultAvatar(String childProfileId) async {
    try {
      final avatars = await getAvatars(childProfileId: childProfileId);
      return avatars.firstWhere(
        (a) => a.isDefault,
        orElse: () => avatars.isNotEmpty ? avatars.first : _createDefaultAvatar(),
      );
    } catch (e) {
      return _createDefaultAvatar();
    }
  }

  /// Create a new avatar
  Future<Avatar> createAvatar({
    required String userId,
    String? childProfileId,
    required AvatarOptions options,
    required String name,
    bool isDefault = false,
  }) async {
    try {
      // If setting as default, unset other defaults
      if (isDefault) {
        await _unsetOtherDefaults(userId: userId, childProfileId: childProfileId);
      }

      final avatarData = {
        'user_id': userId,
        if (childProfileId != null) 'child_profile_id': childProfileId,
        'avatar_data': options.toJson(),
        'name': name,
        'is_default': isDefault,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('user_avatars')
          .insert(avatarData)
          .select()
          .single();

      return Avatar.fromJson(response);
    } catch (e) {
      // Fall back to local storage
      return _saveLocalAvatar(
        userId: userId,
        childProfileId: childProfileId,
        options: options,
        name: name,
        isDefault: isDefault,
      );
    }
  }

  /// Update an existing avatar
  Future<Avatar> updateAvatar({
    required String avatarId,
    AvatarOptions? options,
    String? name,
    bool? isDefault,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (options != null) updates['avatar_data'] = options.toJson();
      if (name != null) updates['name'] = name;
      if (isDefault != null) {
        updates['is_default'] = isDefault;
        if (isDefault) {
          // Get avatar to find user/child
          final avatar = await _supabase
              .from('user_avatars')
              .select('user_id, child_profile_id')
              .eq('id', avatarId)
              .single();

          await _unsetOtherDefaults(
            userId: avatar['user_id'] as String,
            childProfileId: avatar['child_profile_id'] as String?,
            excludeId: avatarId,
          );
        }
      }

      final response = await _supabase
          .from('user_avatars')
          .update(updates)
          .eq('id', avatarId)
          .select()
          .single();

      return Avatar.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update avatar: $e');
    }
  }

  /// Delete an avatar
  Future<void> deleteAvatar(String avatarId) async {
    try {
      await _supabase.from('user_avatars').delete().eq('id', avatarId);
    } catch (e) {
      // Silently fail
    }
  }

  /// Get available customization options
  Map<String, List<String>> getAvailableOptions() {
    return {
      'face_types': ['default', 'happy', 'wink', 'smile', 'excited'],
      'hair_types': ['short', 'medium', 'long', 'curly', 'spiky', 'braids'],
      'hair_colors': [
        '#000000', // Black
        '#8B4513', // Brown
        '#FFD700', // Blonde
        '#FF6347', // Red
        '#9370DB', // Purple
        '#00CED1', // Blue
      ],
      'skin_colors': [
        '#FFDBAC', // Light
        '#F4C2A1', // Medium Light
        '#D2B48C', // Medium
        '#8B7355', // Medium Dark
        '#654321', // Dark
      ],
      'clothing_types': ['tshirt', 'dress', 'hoodie', 'jacket', 'costume'],
      'clothing_colors': [
        '#4A90E2', // Blue
        '#E74C3C', // Red
        '#2ECC71', // Green
        '#F39C12', // Orange
        '#9B59B6', // Purple
        '#1ABC9C', // Teal
        '#E91E63', // Pink
      ],
      'accessories': ['glasses', 'hat', 'crown', 'wings', 'none'],
    };
  }

  /// Create a default avatar
  Avatar _createDefaultAvatar() {
    return Avatar(
      id: 'default',
      userId: 'default',
      options: AvatarOptions(
        faceType: 'happy',
        hairType: 'short',
        hairColor: '#000000',
        skinColor: '#FFDBAC',
        clothingType: 'tshirt',
        clothingColor: '#4A90E2',
      ),
      name: 'Default Avatar',
      isDefault: true,
      createdAt: DateTime.now(),
    );
  }

  /// Unset other default avatars
  Future<void> _unsetOtherDefaults({
    required String userId,
    String? childProfileId,
    String? excludeId,
  }) async {
    try {
      var query = _supabase
          .from('user_avatars')
          .update({'is_default': false})
          .eq('user_id', userId)
          .eq('is_default', true);

      if (childProfileId != null) {
        query = query.eq('child_profile_id', childProfileId);
      } else {
        query = query.isFilter('child_profile_id', null);
      }

      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }

      await query;
    } catch (e) {
      // Silently fail
    }
  }

  /// Get avatars from local storage (fallback)
  Future<List<Avatar>> _getLocalAvatars({String? childProfileId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_localStorageKey);
      if (json == null) return [];

      final data = jsonDecode(json) as Map<String, dynamic>;
      final avatarsJson = data['avatars'] as List<dynamic>? ?? [];

      return avatarsJson
          .map((a) => Avatar.fromJson(a as Map<String, dynamic>))
          .where((a) => childProfileId == null || a.childProfileId == childProfileId)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save avatar to local storage (fallback)
  Future<Avatar> _saveLocalAvatar({
    required String userId,
    String? childProfileId,
    required AvatarOptions options,
    required String name,
    bool isDefault = false,
  }) async {
    final avatar = Avatar(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      childProfileId: childProfileId,
      options: options,
      name: name,
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getLocalAvatars(childProfileId: childProfileId);
      existing.add(avatar);

      await prefs.setString(
        _localStorageKey,
        jsonEncode({
          'avatars': existing.map((a) => a.toJson()).toList(),
        }),
      );
    } catch (e) {
      // Silently fail
    }

    return avatar;
  }
}

