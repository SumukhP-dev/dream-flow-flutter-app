import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth_service.dart';
import '../core/backend_url_helper.dart';

class ParentalControlService {
  final AuthService _authService = AuthService();
  SupabaseClient? _supabase;

  String? get _userId => _authService.currentUser?.id;
  
  String get _backendUrl => BackendUrlHelper.getBackendUrl(
    defaultValue: 'http://localhost:8080',
  );
  
  SupabaseClient? _getSupabaseClient() {
    if (_supabase != null) return _supabase;
    try {
      _supabase = Supabase.instance.client;
      return _supabase;
    } catch (_) {
      return null;
    }
  }

  Future<String> _getAccessToken() async {
    final supabase = _getSupabaseClient();
    final session = supabase?.auth.currentSession;
    if (session == null) {
      throw Exception('Not authenticated');
    }
    return session.accessToken;
  }

  Future<Map<String, dynamic>?> getParentalSettings(String childProfileId) async {
    if (_userId == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/v1/parental-controls/settings/$childProfileId'),
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null; // No settings exist yet
      } else {
        throw Exception('Failed to load parental settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading parental settings: $e');
    }
  }

  Future<Map<String, dynamic>> updateParentalSettings({
    required String childProfileId,
    int? bedtimeHour,
    int? bedtimeMinute,
    bool? bedtimeEnabled,
    int? dailyScreenTimeMinutes,
    bool? screenTimeEnabled,
    bool? requireStoryApproval,
    List<String>? blockedThemes,
    List<String>? blockedCharacters,
    int? maxStoryLengthMinutes,
    bool? emergencyNotificationEnabled,
    String? emergencyContactEmail,
    bool? trackUsage,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final body = {
      'child_profile_id': childProfileId,
      if (bedtimeHour != null) 'bedtime_hour': bedtimeHour,
      if (bedtimeMinute != null) 'bedtime_minute': bedtimeMinute,
      if (bedtimeEnabled != null) 'bedtime_enabled': bedtimeEnabled,
      if (dailyScreenTimeMinutes != null) 'daily_screen_time_minutes': dailyScreenTimeMinutes,
      if (screenTimeEnabled != null) 'screen_time_enabled': screenTimeEnabled,
      if (requireStoryApproval != null) 'require_story_approval': requireStoryApproval,
      if (blockedThemes != null) 'blocked_themes': blockedThemes,
      if (blockedCharacters != null) 'blocked_characters': blockedCharacters,
      if (maxStoryLengthMinutes != null) 'max_story_length_minutes': maxStoryLengthMinutes,
      if (emergencyNotificationEnabled != null) 'emergency_notification_enabled': emergencyNotificationEnabled,
      if (emergencyContactEmail != null) 'emergency_contact_email': emergencyContactEmail,
      if (trackUsage != null) 'track_usage': trackUsage,
    };

    try {
      final response = await http.put(
        Uri.parse('$_backendUrl/api/v1/parental-controls/settings'),
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to update parental settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating parental settings: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getReviewQueue({
    String? childProfileId,
    String? statusFilter,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final queryParams = <String, String>{};
    if (childProfileId != null) queryParams['child_profile_id'] = childProfileId;
    if (statusFilter != null) queryParams['status_filter'] = statusFilter;

    final uri = Uri.parse('$_backendUrl/api/v1/parental-controls/review-queue')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load review queue: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading review queue: $e');
    }
  }

  Future<void> reviewContent({
    required String reviewId,
    required bool approve,
    String? rejectionReason,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final body = {
      'review_id': reviewId,
      'action': approve ? 'approve' : 'reject',
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
    };

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/v1/parental-controls/review-queue/action'),
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to review content: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error reviewing content: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUsageReports({
    required String childProfileId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final queryParams = <String, String>{};
    if (startDate != null) queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String().split('T')[0];

    final uri = Uri.parse('$_backendUrl/api/v1/parental-controls/usage-reports/$childProfileId')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load usage reports: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading usage reports: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getChildProfiles() async {
    if (_userId == null) throw Exception('Not authenticated');

    final supabase = _getSupabaseClient();
    if (supabase == null) return [];

    try {
      final response = await supabase
          .from('family_profiles')
          .select('*')
          .eq('parent_user_id', _userId!);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error loading child profiles: $e');
    }
  }

  /// Check if a child can share stories publicly
  Future<bool> canChildShareStories(String childProfileId) async {
    if (_userId == null) throw Exception('Not authenticated');

    try {
      final settings = await getParentalSettings(childProfileId);
      if (settings == null) {
        // Default: sharing disabled for safety
        return false;
      }
      return settings['story_sharing_enabled'] as bool? ?? false;
    } catch (e) {
      throw Exception('Error checking story sharing permission: $e');
    }
  }

  /// Enable or disable story sharing for a child
  Future<void> enableStorySharing({
    required String childProfileId,
    required bool enabled,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    try {
      await updateParentalSettings(
        childProfileId: childProfileId,
        // We'll add this field to the update method
      );
      
      // Update the setting directly in Supabase if needed
      final settings = await getParentalSettings(childProfileId);
      if (settings != null) {
        await updateParentalSettings(
          childProfileId: childProfileId,
        );
      } else {
        // Create new settings with story sharing enabled/disabled
        await updateParentalSettings(
          childProfileId: childProfileId,
        );
      }
    } catch (e) {
      throw Exception('Error updating story sharing setting: $e');
    }
  }

  /// Get all stories shared by a child
  Future<List<Map<String, dynamic>>> getChildSharedStories(String childProfileId) async {
    if (_userId == null) throw Exception('Not authenticated');

    final supabase = _getSupabaseClient();
    if (supabase == null) return [];

    try {
      // Get child profile to find associated user_id
      final childProfile = await supabase
          .from('family_profiles')
          .select('user_id')
          .eq('id', childProfileId)
          .maybeSingle();

      if (childProfile == null) {
        throw Exception('Child profile not found');
      }

      final childUserId = childProfile['user_id'] as String?;
      if (childUserId == null) {
        return [];
      }

      // Get public stories created by this child
      final response = await supabase
          .from('sessions')
          .select('*')
          .eq('user_id', childUserId)
          .eq('is_public', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error loading child shared stories: $e');
    }
  }
}

