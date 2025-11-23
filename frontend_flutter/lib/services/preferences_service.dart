import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class PreferencesService {
  final AuthService _authService = AuthService();

  // SharedPreferences keys
  static const String _keyMood = 'mood';
  static const String _keyRitual = 'ritual';
  static const String _keyPreferences = 'preferences';
  static const String _keyFavoriteCharacters = 'favoriteCharacters';
  static const String _keyCalmingElements = 'calmingElements';

  // Get current user ID
  String? get _userId => _authService.currentUser?.id;

  // Check if user is logged in
  bool get _isLoggedIn => _authService.isLoggedIn;

  /// Save mood to Supabase (with SharedPreferences fallback)
  Future<void> saveMood(String mood) async {
    try {
      if (_isLoggedIn && _userId != null) {
        // Try to save to Supabase first
        await _upsertProfileField('mood', mood);
        // Also save to SharedPreferences as backup
        await _saveToLocalStorage(_keyMood, mood);
      } else {
        // Fallback to SharedPreferences only
        await _saveToLocalStorage(_keyMood, mood);
      }
    } catch (e) {
      // If Supabase fails, fallback to SharedPreferences
      await _saveToLocalStorage(_keyMood, mood);
    }
  }

  /// Load mood from Supabase (with SharedPreferences fallback)
  Future<String?> loadMood() async {
    try {
      if (_isLoggedIn && _userId != null) {
        // Try to load from Supabase first
        final profile = await _getProfile();
        if (profile != null && profile['mood'] != null) {
          final mood = profile['mood'] as String;
          // Sync to SharedPreferences for offline access
          await _saveToLocalStorage(_keyMood, mood);
          return mood;
        }
      }
    } catch (e) {
      // Supabase failed, fallback to SharedPreferences
    }
    // Fallback to SharedPreferences
    return await _loadFromLocalStorage(_keyMood);
  }

  /// Save ritual/routine to Supabase (with SharedPreferences fallback)
  Future<void> saveRitual(String ritual) async {
    try {
      if (_isLoggedIn && _userId != null) {
        await _upsertProfileField('routine', ritual);
        await _saveToLocalStorage(_keyRitual, ritual);
      } else {
        await _saveToLocalStorage(_keyRitual, ritual);
      }
    } catch (e) {
      await _saveToLocalStorage(_keyRitual, ritual);
    }
  }

  /// Load ritual/routine from Supabase (with SharedPreferences fallback)
  Future<String?> loadRitual() async {
    try {
      if (_isLoggedIn && _userId != null) {
        final profile = await _getProfile();
        if (profile != null && profile['routine'] != null) {
          final routine = profile['routine'] as String;
          await _saveToLocalStorage(_keyRitual, routine);
          return routine;
        }
      }
    } catch (e) {
      // Fallback to SharedPreferences
    }
    return await _loadFromLocalStorage(_keyRitual);
  }

  /// Save preferences list to Supabase (with SharedPreferences fallback)
  Future<void> savePreferences(List<String> preferences) async {
    try {
      if (_isLoggedIn && _userId != null) {
        await _upsertProfileField('preferences', preferences);
        await _saveStringListToLocalStorage(_keyPreferences, preferences);
      } else {
        await _saveStringListToLocalStorage(_keyPreferences, preferences);
      }
    } catch (e) {
      await _saveStringListToLocalStorage(_keyPreferences, preferences);
    }
  }

  /// Load preferences list from Supabase (with SharedPreferences fallback)
  Future<List<String>> loadPreferences() async {
    try {
      if (_isLoggedIn && _userId != null) {
        final profile = await _getProfile();
        if (profile != null && profile['preferences'] != null) {
          final prefs = (profile['preferences'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
          await _saveStringListToLocalStorage(_keyPreferences, prefs);
          return prefs;
        }
      }
    } catch (e) {
      // Fallback to SharedPreferences
    }
    return await _loadStringListFromLocalStorage(_keyPreferences);
  }

  /// Save favorite characters list to Supabase (with SharedPreferences fallback)
  Future<void> saveFavoriteCharacters(List<String> characters) async {
    try {
      if (_isLoggedIn && _userId != null) {
        await _upsertProfileField('favorite_characters', characters);
        await _saveStringListToLocalStorage(_keyFavoriteCharacters, characters);
      } else {
        await _saveStringListToLocalStorage(_keyFavoriteCharacters, characters);
      }
    } catch (e) {
      await _saveStringListToLocalStorage(_keyFavoriteCharacters, characters);
    }
  }

  /// Load favorite characters list from Supabase (with SharedPreferences fallback)
  Future<List<String>> loadFavoriteCharacters() async {
    try {
      if (_isLoggedIn && _userId != null) {
        final profile = await _getProfile();
        if (profile != null && profile['favorite_characters'] != null) {
          final chars = (profile['favorite_characters'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
          await _saveStringListToLocalStorage(_keyFavoriteCharacters, chars);
          return chars;
        }
      }
    } catch (e) {
      // Fallback to SharedPreferences
    }
    return await _loadStringListFromLocalStorage(_keyFavoriteCharacters);
  }

  /// Save calming elements list to Supabase (with SharedPreferences fallback)
  Future<void> saveCalmingElements(List<String> elements) async {
    try {
      if (_isLoggedIn && _userId != null) {
        await _upsertProfileField('calming_elements', elements);
        await _saveStringListToLocalStorage(_keyCalmingElements, elements);
      } else {
        await _saveStringListToLocalStorage(_keyCalmingElements, elements);
      }
    } catch (e) {
      await _saveStringListToLocalStorage(_keyCalmingElements, elements);
    }
  }

  /// Load calming elements list from Supabase (with SharedPreferences fallback)
  Future<List<String>> loadCalmingElements() async {
    try {
      if (_isLoggedIn && _userId != null) {
        final profile = await _getProfile();
        if (profile != null && profile['calming_elements'] != null) {
          final elements = (profile['calming_elements'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
          await _saveStringListToLocalStorage(_keyCalmingElements, elements);
          return elements;
        }
      }
    } catch (e) {
      // Fallback to SharedPreferences
    }
    return await _loadStringListFromLocalStorage(_keyCalmingElements);
  }

  /// Load entire profile from Supabase (with SharedPreferences fallback)
  Future<Map<String, dynamic>?> loadProfile() async {
    try {
      if (_isLoggedIn && _userId != null) {
        final profile = await _getProfile();
        if (profile != null) {
          // Sync all fields to SharedPreferences
          if (profile['mood'] != null) {
            await _saveToLocalStorage(_keyMood, profile['mood'] as String);
          }
          if (profile['routine'] != null) {
            await _saveToLocalStorage(_keyRitual, profile['routine'] as String);
          }
          if (profile['preferences'] != null) {
            final prefs = (profile['preferences'] as List<dynamic>)
                .map((e) => e.toString())
                .toList();
            await _saveStringListToLocalStorage(_keyPreferences, prefs);
          }
          if (profile['favorite_characters'] != null) {
            final chars = (profile['favorite_characters'] as List<dynamic>)
                .map((e) => e.toString())
                .toList();
            await _saveStringListToLocalStorage(_keyFavoriteCharacters, chars);
          }
          if (profile['calming_elements'] != null) {
            final elements = (profile['calming_elements'] as List<dynamic>)
                .map((e) => e.toString())
                .toList();
            await _saveStringListToLocalStorage(_keyCalmingElements, elements);
          }
          return profile;
        }
      }
    } catch (e) {
      // Fallback to SharedPreferences
    }
    // Return profile from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final mood = prefs.getString(_keyMood);
    final ritual = prefs.getString(_keyRitual);
    final preferences = prefs.getStringList(_keyPreferences) ?? [];
    final favoriteCharacters =
        prefs.getStringList(_keyFavoriteCharacters) ?? [];
    final calmingElements = prefs.getStringList(_keyCalmingElements) ?? [];

    if (mood == null &&
        ritual == null &&
        preferences.isEmpty &&
        favoriteCharacters.isEmpty &&
        calmingElements.isEmpty) {
      return null;
    }

    return {
      'mood': mood,
      'routine': ritual,
      'preferences': preferences,
      'favorite_characters': favoriteCharacters,
      'calming_elements': calmingElements,
    };
  }

  /// Save entire profile to Supabase (with SharedPreferences fallback)
  Future<void> saveProfile({
    String? mood,
    String? ritual,
    List<String>? preferences,
    List<String>? favoriteCharacters,
    List<String>? calmingElements,
  }) async {
    try {
      if (_isLoggedIn && _userId != null) {
        // Build update data
        final updateData = <String, dynamic>{};
        if (mood != null) updateData['mood'] = mood;
        if (ritual != null) updateData['routine'] = ritual;
        if (preferences != null) updateData['preferences'] = preferences;
        if (favoriteCharacters != null) {
          updateData['favorite_characters'] = favoriteCharacters;
        }
        if (calmingElements != null) {
          updateData['calming_elements'] = calmingElements;
        }

        if (updateData.isNotEmpty) {
          await _upsertProfile(updateData);
        }
      }
    } catch (e) {
      // Fallback to SharedPreferences
    }

    // Always save to SharedPreferences as backup
    if (mood != null) await _saveToLocalStorage(_keyMood, mood);
    if (ritual != null) await _saveToLocalStorage(_keyRitual, ritual);
    if (preferences != null) {
      await _saveStringListToLocalStorage(_keyPreferences, preferences);
    }
    if (favoriteCharacters != null) {
      await _saveStringListToLocalStorage(
        _keyFavoriteCharacters,
        favoriteCharacters,
      );
    }
    if (calmingElements != null) {
      await _saveStringListToLocalStorage(_keyCalmingElements, calmingElements);
    }
  }

  // Legacy method for backward compatibility
  Future<void> saveLastMood(String mood) async {
    await saveMood(mood);
  }

  Future<String?> loadLastMood() async {
    return await loadMood();
  }

  // Private helper methods

  /// Get profile from Supabase
  Future<Map<String, dynamic>?> _getProfile() async {
    if (_userId == null) return null;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _userId!)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return response;

      try {
        final data = (response as dynamic).data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      } catch (_) {
        // Ignore conversion errors and fall through to return null
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upsert a single field in the profile
  Future<void> _upsertProfileField(String field, dynamic value) async {
    if (_userId == null) return;

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': _userId!,
        field: value,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Upsert entire profile
  Future<void> _upsertProfile(Map<String, dynamic> data) async {
    if (_userId == null) return;

    try {
      data['id'] = _userId!;
      await Supabase.instance.client.from('profiles').upsert(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Save string to SharedPreferences
  Future<void> _saveToLocalStorage(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Load string from SharedPreferences
  Future<String?> _loadFromLocalStorage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Save string list to SharedPreferences
  Future<void> _saveStringListToLocalStorage(
    String key,
    List<String> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  /// Load string list from SharedPreferences
  Future<List<String>> _loadStringListFromLocalStorage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }
}
