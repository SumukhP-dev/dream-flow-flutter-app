import 'dart:convert';

import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/backend_url_helper.dart';
import 'subscription_service.dart';

/// Service for handling payments via Stripe
class PaymentService {
  PaymentService({
    String? stripePublishableKey,
    String? baseUrl,
  })  : _stripePublishableKey = stripePublishableKey,
        _baseUrl = BackendUrlHelper.getBackendUrl(
          baseUrl: baseUrl,
          defaultValue: 'http://localhost:8080',
        );

  final String? _stripePublishableKey;
  final String _baseUrl;
  bool _isInitialized = false;

  /// Initialize payment service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Stripe
    if (_stripePublishableKey != null && _stripePublishableKey.isNotEmpty) {
      Stripe.publishableKey = _stripePublishableKey;
      await Stripe.instance.applySettings();
    }

    _isInitialized = true;
  }

  /// Purchase subscription for a tier
  /// Launches Stripe checkout and returns current subscription
  /// Note: After checkout completes, subscription will be updated via webhook
  Future<Subscription> purchaseSubscription(String tier, {String billingPeriod = 'monthly'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    return await _purchaseWithStripe(tier, billingPeriod);
  }

  /// Purchase subscription using Stripe checkout
  Future<Subscription> _purchaseWithStripe(String tier, String billingPeriod) async {
    // Get authentication token
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw PaymentException('User not authenticated');
    }

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw PaymentException('No access token available');
    }

    try {
      // Create checkout session on backend
      final uri = Uri.parse('$_baseUrl/api/v1/payments/create-checkout-session')
          .replace(queryParameters: {
        'tier': tier.toLowerCase(),
        'billing_period': billingPeriod.toLowerCase(),
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 400) {
        final errorData = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};
        final errorMessage = errorData['detail'] as String? ??
            'Failed to create checkout session';
        throw PaymentException(
          'Failed to create checkout session (${response.statusCode}): $errorMessage',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final checkoutUrl = responseData['url'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw PaymentException('No checkout URL returned from backend');
      }

      // Launch Stripe checkout URL
      final url = Uri.parse(checkoutUrl);
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw PaymentException('Failed to launch Stripe checkout');
      }

      // Return current subscription (will be updated via webhook after payment completes)
      // The UI should reload subscription data after user returns from checkout
      final subscriptionService = SubscriptionService(baseUrl: _baseUrl);
      try {
        // Try to get current subscription - if it exists, return it
        // If it doesn't exist yet, that's fine - webhook will create it after payment
        return await subscriptionService.getSubscription();
      } catch (e) {
        // If no subscription exists yet, return a free tier subscription
        // The webhook will update it to the purchased tier after payment
        // This allows the UI to continue without errors
        return Subscription(
          id: '',
          userId: user.id,
          tier: 'free',
          status: 'active',
          currentPeriodStart: DateTime.now(),
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
          cancelAtPeriodEnd: false,
          cancelledAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException(
        'Failed to process Stripe payment: ${e.toString()}',
      );
    }
  }
}

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);

  @override
  String toString() => 'PaymentException: $message';
}
