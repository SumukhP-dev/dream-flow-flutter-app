import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class FeedbackSubmission {
  final String sessionId;
  final int rating;
  final int moodDelta;
  final DateTime timestamp;

  FeedbackSubmission({
    required this.sessionId,
    required this.rating,
    required this.moodDelta,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'rating': rating,
        'mood_delta': moodDelta,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FeedbackSubmission.fromJson(Map<String, dynamic> json) {
    return FeedbackSubmission(
      sessionId: json['session_id'] as String,
      rating: json['rating'] as int,
      moodDelta: json['mood_delta'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class FeedbackServiceException implements Exception {
  final String message;
  FeedbackServiceException(this.message);

  @override
  String toString() => 'FeedbackServiceException: $message';
}

class FeedbackService {
  FeedbackService({String? baseUrl, AuthService? authService})
      : _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8080',
            ),
        _authService = authService ?? AuthService();

  final String _baseUrl;
  final AuthService _authService;
  static const String _queueKey = 'feedback_queue';
  static const String _processingKey = 'feedback_processing';

  /// Submit feedback for a session.
  /// If offline or submission fails, queues it for later retry.
  Future<void> submitFeedback({
    required String sessionId,
    required int rating,
    required int moodDelta,
  }) async {
    final submission = FeedbackSubmission(
      sessionId: sessionId,
      rating: rating,
      moodDelta: moodDelta,
    );

    try {
      await _submitToApi(submission);
      // Remove from queue if it was queued
      await _removeFromQueue(submission);
    } catch (e) {
      // Queue for retry
      await _addToQueue(submission);
      rethrow;
    }
  }

  Future<void> _submitToApi(FeedbackSubmission submission) async {
    final uri = Uri.parse('$_baseUrl/api/v1/feedback');
    
    // Get auth token if user is logged in
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'session_id': submission.sessionId,
        'rating': submission.rating,
        'mood_delta': submission.moodDelta,
      }),
    );

    if (response.statusCode >= 400) {
      final detail = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw FeedbackServiceException(
        'Submission failed (${response.statusCode}): $detail',
      );
    }
  }

  /// Process queued feedback submissions.
  /// Should be called when app comes online or on app startup.
  Future<void> processQueue() async {
    // Prevent concurrent processing
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_processingKey) == true) {
      return;
    }

    await prefs.setBool(_processingKey, true);
    try {
      final queue = await _getQueue();
      final failed = <FeedbackSubmission>[];

      for (final submission in queue) {
        try {
          await _submitToApi(submission);
        } catch (e) {
          // Keep failed submissions for retry
          failed.add(submission);
        }
      }

      // Update queue with only failed submissions
      await _saveQueue(failed);
    } finally {
      await prefs.setBool(_processingKey, false);
    }
  }

  Future<void> _addToQueue(FeedbackSubmission submission) async {
    final queue = await _getQueue();
    // Remove any existing submission for this session
    queue.removeWhere((s) => s.sessionId == submission.sessionId);
    queue.add(submission);
    await _saveQueue(queue);
  }

  Future<void> _removeFromQueue(FeedbackSubmission submission) async {
    final queue = await _getQueue();
    queue.removeWhere((s) => s.sessionId == submission.sessionId);
    await _saveQueue(queue);
  }

  Future<List<FeedbackSubmission>> _getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson == null) return [];

      final decoded = jsonDecode(queueJson) as List<dynamic>;
      return decoded
          .map((json) =>
              FeedbackSubmission.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If queue is corrupted, return empty list
      return [];
    }
  }

  Future<void> _saveQueue(List<FeedbackSubmission> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(queue.map((s) => s.toJson()).toList());
      await prefs.setString(_queueKey, json);
    } catch (e) {
      // Silently fail - queueing is not critical
      print('Warning: Failed to save feedback queue: $e');
    }
  }

  /// Get the number of queued submissions.
  Future<int> getQueueLength() async {
    final queue = await _getQueue();
    return queue.length;
  }

  /// Clear the feedback queue (useful for testing or reset).
  Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
    } catch (e) {
      // Silently fail
      print('Warning: Failed to clear feedback queue: $e');
    }
  }
}

