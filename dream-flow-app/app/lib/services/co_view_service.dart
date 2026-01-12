import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth_service.dart';
import '../core/backend_url_helper.dart';

class CoViewService {
  final AuthService _authService = AuthService();

  String? get _userId => _authService.currentUser?.id;
  
  String get _backendUrl => BackendUrlHelper.getBackendUrl(
    defaultValue: 'http://localhost:8080',
  );
  
  Future<String> _getAccessToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('Not authenticated');
    }
    return session.accessToken;
  }

  /// Join a child's story session for co-viewing
  Future<Map<String, dynamic>> joinCoViewSession({
    required String sessionId,
    required String childProfileId,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final body = {
      'session_id': sessionId,
      'child_profile_id': childProfileId,
    };

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/v1/co-viewing/join'),
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to join co-view session: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error joining co-view session: $e');
    }
  }

  /// Get co-view session details
  Future<Map<String, dynamic>?> getCoViewSession(String sessionId) async {
    if (_userId == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/v1/co-viewing/sessions/$sessionId'),
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get co-view session: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting co-view session: $e');
    }
  }

  /// Add story to family library
  Future<void> addToFamilyLibrary({
    required String sessionId,
    bool sharedWithSiblings = true,
    bool isFamilyFavorite = false,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final body = {
      'session_id': sessionId,
      'shared_with_siblings': sharedWithSiblings,
      'is_family_favorite': isFamilyFavorite,
    };

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/v1/co-viewing/family-library'),
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add to family library: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding to family library: $e');
    }
  }

  /// Get family story library for a child
  Future<List<Map<String, dynamic>>> getFamilyLibrary(String childProfileId) async {
    if (_userId == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/v1/co-viewing/family-library/$childProfileId'),
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load family library: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading family library: $e');
    }
  }
}

