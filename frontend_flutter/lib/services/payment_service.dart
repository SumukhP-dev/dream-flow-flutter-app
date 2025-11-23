import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'subscription_service.dart';

/// Service for handling payments via RevenueCat (mobile) and Stripe (web)
class PaymentService {
  PaymentService({
    String? revenuecatApiKey,
    String? stripePublishableKey,
    SubscriptionService? subscriptionService,
  }) : _revenuecatApiKey = revenuecatApiKey,
       _stripePublishableKey = stripePublishableKey,
       _subscriptionService = subscriptionService ?? SubscriptionService();

  final String? _revenuecatApiKey;
  final String? _stripePublishableKey;
  final SubscriptionService _subscriptionService;
  bool _isInitialized = false;

  /// Initialize payment service based on platform
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      // Web: Initialize Stripe
      if (_stripePublishableKey != null && _stripePublishableKey.isNotEmpty) {
        Stripe.publishableKey = _stripePublishableKey;
        await Stripe.instance.applySettings();
      }
    } else {
      // Mobile: Initialize RevenueCat
      if (_revenuecatApiKey != null && _revenuecatApiKey.isNotEmpty) {
        await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.info,
        );

        PurchasesConfiguration configuration;
        if (Platform.isIOS) {
          configuration = PurchasesConfiguration(_revenuecatApiKey);
        } else if (Platform.isAndroid) {
          configuration = PurchasesConfiguration(_revenuecatApiKey);
        } else {
          throw UnsupportedError('Platform not supported for payments');
        }

        await Purchases.configure(configuration);
      }
    }

    _isInitialized = true;
  }

  /// Purchase subscription for a tier
  /// Returns the subscription after successful purchase
  Future<Subscription> purchaseSubscription(String tier) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb) {
      return await _purchaseWithStripe(tier);
    } else {
      return await _purchaseWithRevenueCat(tier);
    }
  }

  /// Purchase subscription using Stripe (web)
  Future<Subscription> _purchaseWithStripe(String tier) async {
    if (_stripePublishableKey == null || _stripePublishableKey.isEmpty) {
      throw PaymentException(
        'Stripe is not configured. Please set STRIPE_PUBLISHABLE_KEY.',
      );
    }

    // Map tier to Stripe price ID
    // These should be configured in your Stripe dashboard
    final priceIdMap = {
      'premium': const String.fromEnvironment(
        'STRIPE_PREMIUM_PRICE_ID',
        defaultValue: '',
      ),
      'family': const String.fromEnvironment(
        'STRIPE_FAMILY_PRICE_ID',
        defaultValue: '',
      ),
    };

    final priceId = priceIdMap[tier.toLowerCase()];
    if (priceId == null || priceId.isEmpty) {
      throw PaymentException('Price ID not configured for tier: $tier');
    }

    try {
      // Create checkout session on backend
      // For now, redirect to Stripe Checkout
      // In production, you'd create a checkout session via your backend
      // Note: This requires backend implementation
      throw PaymentException(
        'Stripe web checkout requires backend implementation. Please implement /api/v1/payments/create-checkout endpoint.',
      );

      if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
        await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw PaymentException('Could not launch checkout URL');
      }

      // After successful payment, Stripe will redirect back
      // The webhook will update the subscription in the backend
      // For now, we'll need to poll or use a callback
      throw PaymentException(
        'Stripe web checkout not fully implemented. Use mobile app for in-app purchases.',
      );
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException(
        'Failed to process Stripe payment: ${e.toString()}',
      );
    }
  }

  /// Purchase subscription using RevenueCat (mobile)
  Future<Subscription> _purchaseWithRevenueCat(String tier) async {
    if (_revenuecatApiKey == null || _revenuecatApiKey.isEmpty) {
      throw PaymentException(
        'RevenueCat is not configured. Please set REVENUECAT_API_KEY.',
      );
    }

    try {
      // Map tier to RevenueCat offering/package
      final packageIdentifier = tier.toLowerCase(); // e.g., 'premium', 'family'

      // Get available offerings
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        throw PaymentException(
          'No offerings available. Please configure in RevenueCat dashboard.',
        );
      }

      // Find the package for the requested tier
      Package? package;
      for (final pkg in offerings.current!.availablePackages) {
        if (pkg.identifier == packageIdentifier ||
            pkg.storeProduct.identifier.contains(packageIdentifier)) {
          package = pkg;
          break;
        }
      }

      if (package == null) {
        // Try to find by tier name in package identifier
        package = offerings.current!.availablePackages.firstWhere(
          (p) => p.identifier.toLowerCase().contains(tier.toLowerCase()),
          orElse: () =>
              throw PaymentException('Package not found for tier: $tier'),
        );
      }

      // Purchase the package
      final purchaserInfo = await Purchases.purchasePackage(package);

      // Check if user has active entitlement
      final entitlementId = _getEntitlementIdForTier(tier);
      final hasEntitlement = purchaserInfo.entitlements.active.containsKey(
        entitlementId,
      );

      if (!hasEntitlement) {
        throw PaymentException('Purchase completed but entitlement not active');
      }

      // Get RevenueCat user ID and entitlement ID
      final revenuecatUserId = purchaserInfo.originalAppUserId;
      final revenuecatEntitlement =
          purchaserInfo.entitlements.active[entitlementId]!;
      final revenuecatEntitlementId = revenuecatEntitlement.identifier;

      // Sync subscription with backend
      final subscription = await _subscriptionService.createSubscription(
        tier: tier,
        revenuecatUserId: revenuecatUserId,
        revenuecatEntitlementId: revenuecatEntitlementId,
      );

      return subscription;
    } on PlatformException catch (e) {
      if (e.code == PurchasesErrorHelper.purchaseCancelledErrorCode) {
        throw PaymentException('Purchase was cancelled');
      } else if (e.code == PurchasesErrorHelper.purchaseNotAllowedErrorCode) {
        throw PaymentException('Purchase not allowed');
      } else if (e.code == PurchasesErrorHelper.purchaseInvalidErrorCode) {
        throw PaymentException('Purchase invalid');
      } else {
        throw PaymentException('Purchase failed: ${e.message}');
      }
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException(
        'Failed to process RevenueCat payment: ${e.toString()}',
      );
    }
  }

  /// Restore purchases (mobile only)
  Future<Subscription?> restorePurchases() async {
    if (kIsWeb) {
      throw UnsupportedError('Restore purchases is only available on mobile');
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      final purchaserInfo = await Purchases.restorePurchases();

      // Check for active entitlements
      for (final entitlement in purchaserInfo.entitlements.active.values) {
        final tier = _getTierFromEntitlementId(entitlement.identifier);
        if (tier != null) {
          // Sync with backend
          return await _subscriptionService.createSubscription(
            tier: tier,
            revenuecatUserId: purchaserInfo.originalAppUserId,
            revenuecatEntitlementId: entitlement.identifier,
          );
        }
      }

      return null; // No active purchases to restore
    } catch (e) {
      throw PaymentException('Failed to restore purchases: ${e.toString()}');
    }
  }

  /// Get entitlement ID for a tier
  String _getEntitlementIdForTier(String tier) {
    // Default entitlement IDs - should match RevenueCat configuration
    switch (tier.toLowerCase()) {
      case 'premium':
        return 'premium';
      case 'family':
        return 'family';
      default:
        return 'premium'; // Default fallback
    }
  }

  /// Get tier from entitlement ID
  String? _getTierFromEntitlementId(String entitlementId) {
    switch (entitlementId.toLowerCase()) {
      case 'premium':
        return 'premium';
      case 'family':
        return 'family';
      default:
        return null;
    }
  }
}

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);

  @override
  String toString() => 'PaymentException: $message';
}
