import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService({String? baseUrl})
      : _baseUrl = baseUrl ??
            const String.fromEnvironment('BACKEND_URL',
                defaultValue: 'http://localhost:8080');

  final String _baseUrl;

  /// Register notification token with backend
  Future<void> registerToken({
    required String token,
    String? deviceId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final session = await Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No access token available');
    }

    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'web';

    final uri = Uri.parse('$_baseUrl/api/v1/notifications/register');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        'token': token,
        'platform': platform,
        if (deviceId != null) 'device_id': deviceId,
      }),
    );

    if (response.statusCode >= 400) {
      final error = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw NotificationException(
          'Failed to register token (${response.statusCode}): $error');
    }
  }

  /// Get notification preferences
  Future<NotificationPreferences> getPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final session = await Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No access token available');
    }

    final uri = Uri.parse('$_baseUrl/api/v1/notifications/preferences');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );

    if (response.statusCode >= 400) {
      final error = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw NotificationException(
          'Failed to fetch preferences (${response.statusCode}): $error');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return NotificationPreferences.fromJson(decoded);
  }

  /// Update notification preferences
  Future<NotificationPreferences> updatePreferences({
    bool? bedtimeRemindersEnabled,
    String? bedtimeReminderTime,
    bool? streakNotificationsEnabled,
    bool? storyRecommendationsEnabled,
    bool? weeklySummaryEnabled,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final session = await Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No access token available');
    }

    final uri = Uri.parse('$_baseUrl/api/v1/notifications/preferences');
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        if (bedtimeRemindersEnabled != null)
          'bedtime_reminders_enabled': bedtimeRemindersEnabled,
        if (bedtimeReminderTime != null)
          'bedtime_reminder_time': bedtimeReminderTime,
        if (streakNotificationsEnabled != null)
          'streak_notifications_enabled': streakNotificationsEnabled,
        if (storyRecommendationsEnabled != null)
          'story_recommendations_enabled': storyRecommendationsEnabled,
        if (weeklySummaryEnabled != null)
          'weekly_summary_enabled': weeklySummaryEnabled,
      }),
    );

    if (response.statusCode >= 400) {
      final error = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw NotificationException(
          'Failed to update preferences (${response.statusCode}): $error');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return NotificationPreferences.fromJson(decoded);
  }
}

class NotificationException implements Exception {
  final String message;
  NotificationException(this.message);

  @override
  String toString() => 'NotificationException: $message';
}

class NotificationPreferences {
  final String id;
  final String userId;
  final bool bedtimeRemindersEnabled;
  final String? bedtimeReminderTime;
  final bool streakNotificationsEnabled;
  final bool storyRecommendationsEnabled;
  final bool weeklySummaryEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationPreferences({
    required this.id,
    required this.userId,
    required this.bedtimeRemindersEnabled,
    this.bedtimeReminderTime,
    required this.streakNotificationsEnabled,
    required this.storyRecommendationsEnabled,
    required this.weeklySummaryEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bedtimeRemindersEnabled: json['bedtime_reminders_enabled'] as bool,
      bedtimeReminderTime: json['bedtime_reminder_time'] as String?,
      streakNotificationsEnabled: json['streak_notifications_enabled'] as bool,
      storyRecommendationsEnabled:
          json['story_recommendations_enabled'] as bool,
      weeklySummaryEnabled: json['weekly_summary_enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

