import 'package:supabase_flutter/supabase_flutter.dart';

/// Collaboration session status
enum CollaborationStatus {
  pending,
  inProgress,
  completed,
}

/// Collaboration session model
class CollaborationSession {
  final String id;
  final String sessionId;
  final String parentId;
  final String childId;
  final CollaborationStatus status;
  final String? parentContribution;
  final String? childContribution;
  final DateTime createdAt;

  CollaborationSession({
    required this.id,
    required this.sessionId,
    required this.parentId,
    required this.childId,
    required this.status,
    this.parentContribution,
    this.childContribution,
    required this.createdAt,
  });

  factory CollaborationSession.fromJson(Map<String, dynamic> json) {
    return CollaborationSession(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      parentId: json['parent_id'] as String,
      childId: json['child_id'] as String,
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      parentContribution: json['parent_contribution'] as String?,
      childContribution: json['child_contribution'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static CollaborationStatus _parseStatus(String status) {
    switch (status) {
      case 'in_progress':
        return CollaborationStatus.inProgress;
      case 'completed':
        return CollaborationStatus.completed;
      default:
        return CollaborationStatus.pending;
    }
  }
}

/// Service for parent-child story collaboration
class CollaborationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new collaboration session
  Future<CollaborationSession> createCollaboration({
    required String parentId,
    required String childId,
    required String sessionId,
    String? parentContribution,
  }) async {
    try {
      final response = await _supabase.from('collaboration_sessions').insert({
        'session_id': sessionId,
        'parent_id': parentId,
        'child_id': childId,
        'status': 'pending',
        if (parentContribution != null) 'parent_contribution': parentContribution,
      }).select().single();

      return CollaborationSession.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create collaboration: $e');
    }
  }

  /// Get collaboration sessions for a child
  Future<List<CollaborationSession>> getCollaborationsForChild(
    String childId,
  ) async {
    try {
      final response = await _supabase
          .from('collaboration_sessions')
          .select('*')
          .eq('child_id', childId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) =>
              CollaborationSession.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Update collaboration with child's contribution
  Future<CollaborationSession> addChildContribution({
    required String collaborationId,
    required String childContribution,
  }) async {
    try {
      final response = await _supabase
          .from('collaboration_sessions')
          .update({
            'child_contribution': childContribution,
            'status': 'in_progress',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', collaborationId)
          .select()
          .single();

      return CollaborationSession.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update collaboration: $e');
    }
  }

  /// Complete collaboration
  Future<void> completeCollaboration(String collaborationId) async {
    try {
      await _supabase.from('collaboration_sessions').update({
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', collaborationId);
    } catch (e) {
      throw Exception('Failed to complete collaboration: $e');
    }
  }
}

