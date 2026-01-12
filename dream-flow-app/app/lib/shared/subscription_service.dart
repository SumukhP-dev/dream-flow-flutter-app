import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/backend_url_helper.dart';

class SubscriptionService {
  SubscriptionService({String? baseUrl})
      : _baseUrl = BackendUrlHelper.getBackendUrl(
          baseUrl: baseUrl,
          defaultValue: 'http://localhost:8080',
        );

  final String _baseUrl;

  /// Get current user's subscription
  Future<Subscription> getSubscription() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No access token available');
    }

    final uri = Uri.parse('$_baseUrl/api/v1/subscription');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 400) {
      final error = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw SubscriptionException(
          'Failed to fetch subscription (${response.statusCode}): $error');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Subscription.fromJson(decoded);
  }

  /// Get user's usage quota
  Future<UsageQuota> getUsageQuota() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No access token available');
    }

    final uri = Uri.parse('$_baseUrl/api/v1/subscription/quota');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 400) {
      final error = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw SubscriptionException(
          'Failed to fetch usage quota (${response.statusCode}): $error');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return UsageQuota.fromJson(decoded);
  }

  /// Create or update subscription
  Future<Subscription> createSubscription({
    required String tier,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No access token available');
    }

    final uri = Uri.parse('$_baseUrl/api/v1/subscription');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tier': tier,
        if (stripeSubscriptionId != null)
          'stripe_subscription_id': stripeSubscriptionId,
        if (stripeCustomerId != null) 'stripe_customer_id': stripeCustomerId,
      }),
    );

    if (response.statusCode >= 400) {
      final error = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw SubscriptionException(
          'Failed to create subscription (${response.statusCode}): $error');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Subscription.fromJson(decoded);
  }

  /// Cancel subscription
  Future<Subscription> cancelSubscription({
    bool cancelAtPeriodEnd = true,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No access token available');
    }

    final uri = Uri.parse('$_baseUrl/api/v1/subscription/cancel');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'cancel_at_period_end': cancelAtPeriodEnd,
      }),
    );

    if (response.statusCode >= 400) {
      final error = response.body.isNotEmpty ? response.body : 'Unknown error';
      throw SubscriptionException(
          'Failed to cancel subscription (${response.statusCode}): $error');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Subscription.fromJson(decoded);
  }
}

class SubscriptionException implements Exception {
  final String message;
  SubscriptionException(this.message);

  @override
  String toString() => 'SubscriptionException: $message';
}

class Subscription {
  final String id;
  final String userId;
  final String tier;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.tier,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tier: json['tier'] as String,
      status: json['status'] as String,
      currentPeriodStart:
          DateTime.parse(json['current_period_start'] as String),
      currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPremium => tier == 'premium' || tier == 'family';
  bool get isActive => status == 'active';
}

class UsageQuota {
  final String tier;
  final int quota;
  final int currentCount;
  final String periodType;
  final bool canGenerate;
  final String? errorMessage;

  UsageQuota({
    required this.tier,
    required this.quota,
    required this.currentCount,
    required this.periodType,
    required this.canGenerate,
    this.errorMessage,
  });

  factory UsageQuota.fromJson(Map<String, dynamic> json) {
    return UsageQuota(
      tier: json['tier'] as String,
      quota: json['quota'] as int,
      currentCount: json['current_count'] as int,
      periodType: json['period_type'] as String,
      canGenerate: json['can_generate'] as bool,
      errorMessage: json['error_message'] as String?,
    );
  }

  bool get isUnlimited => quota >= 999999;
  int get remaining => isUnlimited ? 999999 : (quota - currentCount);
  double get usagePercentage =>
      isUnlimited ? 0.0 : (currentCount / quota).clamp(0.0, 1.0);
}
