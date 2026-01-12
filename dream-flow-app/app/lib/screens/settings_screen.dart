import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shared/payment_service.dart' show PaymentService, PaymentException;
import '../shared/subscription_service.dart'
    show SubscriptionService, Subscription;
import '../services/parental_control_service.dart';
import '../core/auth_service.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'parent_dashboard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AuthService _authService = AuthService();
  final ParentalControlService _parentalControlService =
      ParentalControlService();
  late final PaymentService _paymentService;
  Subscription? _subscription;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _error;
  bool _isLoadingParentalControls = false;
  bool _isUpdatingParentalSetting = false;
  String? _parentalControlsError;
  List<Map<String, dynamic>> _childProfiles = [];
  String? _selectedChildId;
  Map<String, dynamic> _parentalSettings = {};

  bool get _isFamilyPlanActive {
    final subscription = _subscription;
    if (subscription == null) return false;
    return subscription.tier.toLowerCase() == 'family' &&
        subscription.status == 'active';
  }

  Map<String, dynamic> _normalizeParentalSettings(
    Map<String, dynamic>? settings,
    String childId,
  ) {
    final base = <String, dynamic>{
      'child_profile_id': childId,
      'bedtime_enabled': false,
      'screen_time_enabled': false,
      'require_story_approval': false,
      'track_usage': true,
      'emergency_notification_enabled': true,
    };

    if (settings == null) {
      return base;
    }
    final normalized = Map<String, dynamic>.from(settings);
    return {...base, ...normalized};
  }

  Future<void> _loadParentalControls({String? childId}) async {
    if (!_authService.isLoggedIn || !_isFamilyPlanActive) return;

    setState(() {
      _isLoadingParentalControls = true;
      _parentalControlsError = null;
      if (childId != null) {
        _selectedChildId = childId;
      }
    });

    try {
      final profiles = await _parentalControlService.getChildProfiles();
      if (!mounted) return;

      if (profiles.isEmpty) {
        setState(() {
          _childProfiles = [];
          _selectedChildId = null;
          _parentalSettings = {};
        });
        return;
      }

      final resolvedChildId = (() {
        final desiredId = childId ?? _selectedChildId;
        if (desiredId != null &&
            profiles.any((profile) => profile['id'] == desiredId)) {
          return desiredId;
        }
        return profiles.first['id'] as String?;
      })();

      if (resolvedChildId == null) {
        setState(() {
          _childProfiles = profiles;
          _selectedChildId = null;
          _parentalSettings = {};
        });
        return;
      }

      final settings =
          await _parentalControlService.getParentalSettings(resolvedChildId);

      if (!mounted) return;
      setState(() {
        _childProfiles = profiles;
        _selectedChildId = resolvedChildId;
        _parentalSettings =
            _normalizeParentalSettings(settings, resolvedChildId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parentalControlsError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingParentalControls = false;
      });
    }
  }

  Future<void> _handleParentalToggle(String field, bool value) async {
    final childId = _selectedChildId;
    if (childId == null) return;

    setState(() {
      _isUpdatingParentalSetting = true;
      _parentalControlsError = null;
      _parentalSettings = {
        ..._parentalSettings,
        field: value,
      };
    });

    try {
      await _parentalControlService.updateParentalSettings(
        childProfileId: childId,
        bedtimeEnabled: field == 'bedtime_enabled' ? value : null,
        screenTimeEnabled: field == 'screen_time_enabled' ? value : null,
        requireStoryApproval: field == 'require_story_approval' ? value : null,
        trackUsage: field == 'track_usage' ? value : null,
        emergencyNotificationEnabled:
            field == 'emergency_notification_enabled' ? value : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parentalControlsError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update setting: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingParentalSetting = false;
      });
    }
  }

  bool _currentSettingBool(String key, {bool fallback = false}) {
    final value = _parentalSettings[key];
    if (value is bool) return value;
    return fallback;
  }

  void _openParentDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
    ).then((_) {
      if (_isFamilyPlanActive) {
        _loadParentalControls(childId: _selectedChildId);
      }
    });
  }

  void _resetParentalControls() {
    _childProfiles = [];
    _selectedChildId = null;
    _parentalSettings = {};
    _parentalControlsError = null;
    _isLoadingParentalControls = false;
    _isUpdatingParentalSetting = false;
  }

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
    _loadSubscriptionData();
  }

  Future<void> _initializePaymentService() async {
    // Get API keys from environment or config
    final stripePublishableKey = const String.fromEnvironment(
      'STRIPE_PUBLISHABLE_KEY',
      defaultValue: '',
    );

    _paymentService = PaymentService(
      stripePublishableKey:
          stripePublishableKey.isNotEmpty ? stripePublishableKey : null,
    );

    try {
      await _paymentService.initialize();
    } catch (e) {
      if (kDebugMode) {
        print('Payment service initialization warning: $e');
      }
      // Continue without payment service if not configured
    }
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Guests (or when Supabase isn't configured) don't have subscription data.
    if (!_authService.isLoggedIn) {
      setState(() {
        _subscription = null;
        _isLoading = false;
        _error = null;
        _resetParentalControls();
      });
      return;
    }

    try {
      final subscription = await _subscriptionService.getSubscription();
      if (!mounted) return;
      setState(() {
        _subscription = subscription;
        _isLoading = false;
      });
      if (_isFamilyPlanActive) {
        await _loadParentalControls();
      } else if (mounted) {
        setState(_resetParentalControls);
      }
    } catch (e) {
      // If user is not authenticated, don't show an error
      // Instead, set subscription to null so they can see the purchase UI
      final errorMessage = e.toString();
      final normalizedError = errorMessage.toLowerCase();
      final isAuthError = normalizedError.contains('not authenticated') ||
          normalizedError.contains('no access token') ||
          normalizedError.contains('supabase instance has not been initialized');
      
      final isConnectionError = normalizedError.contains('connection') ||
          normalizedError.contains('timeout') ||
          normalizedError.contains('failed to fetch') ||
          normalizedError.contains('network') ||
          normalizedError.contains('503');
      
      if (isAuthError) {
        if (!mounted) return;
        setState(() {
          _subscription = null;
          _isLoading = false;
          _error = null;
          _resetParentalControls();
        });
      } else if (isConnectionError) {
        if (!mounted) return;
        setState(() {
          _error = "Can't connect to the server right now. This could be because the backend service isn't running.";
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05020C),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF120E2B), Color(0xFF07040F)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -30,
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -40,
              child: Container(
                height: 280,
                width: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Oops! Something went wrong 😅',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!.contains('not authenticated') ||
                                            _error!.contains(
                                                'User not authenticated')
                                        ? 'You need to sign in or create an account to see your settings. Don\'t worry, it\'s super easy!'
                                        : 'We couldn\'t load your settings right now. Want to try again?',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _loadSubscriptionData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPremiumSection(),
                                  const SizedBox(height: 32),
                                  _buildParentalControlsSection(),
                                  const SizedBox(height: 32),
                                  _buildOtherSettings(),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSection() {
    final isPremium = _subscription?.isPremium ?? false;
    final isActive = _subscription?.isActive ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPremium && isActive
                          ? 'Ad-free experience unlocked'
                          : 'Purchase to remove ads',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium && isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (isPremium && isActive) ...[
            _buildPremiumStatus(),
            const SizedBox(height: 24),
          ],
          if (!isPremium || !isActive) ...[
            _buildPremiumFeatures(),
            const SizedBox(height: 24),
            _buildPremiumPricing(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessingPayment ? null : _handlePurchasePremium,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessingPayment
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Purchase Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParentalControlsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF0EA5E9),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Parental Controls',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isFamilyPlanActive)
                IconButton(
                  tooltip: 'Refresh child settings',
                  onPressed: _isLoadingParentalControls
                      ? null
                      : () => _loadParentalControls(childId: _selectedChildId),
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildParentalControlsContent(),
        ],
      ),
    );
  }

  Widget _buildParentalControlsContent() {
    if (!_authService.isLoggedIn) {
      return _buildParentalControlsMessage(
        'Sign in to manage child profiles and parental controls.',
        action: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
          ),
          child: const Text('Sign In'),
        ),
      );
    }

    if (!_isFamilyPlanActive) {
      return _buildParentalControlsMessage(
        'Family plan required to unlock child profiles, parental controls, and shared libraries.',
      );
    }

    if (_isLoadingParentalControls) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_parentalControlsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load parental controls: $_parentalControlsError',
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _loadParentalControls(childId: _selectedChildId),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_childProfiles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a child profile to enable parental controls.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openParentDashboard,
            icon: const Icon(Icons.child_care),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
            ),
            label: const Text('Open Parent Dashboard'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChildSelector(),
        const SizedBox(height: 16),
        _buildParentalToggle(
          field: 'require_story_approval',
          title: 'Require approval before sharing stories',
          subtitle:
              'Stories stay private until you approve them in the parent dashboard.',
        ),
        _buildParentalToggle(
          field: 'bedtime_enabled',
          title: 'Enforce bedtime reminder',
          subtitle: 'Hide Dream Flow after bedtime to support healthy sleep.',
        ),
        _buildParentalToggle(
          field: 'screen_time_enabled',
          title: 'Enable screen time limits',
          subtitle: 'Track and limit daily listening time for this child.',
        ),
        _buildParentalToggle(
          field: 'track_usage',
          title: 'Track nightly progress',
          subtitle: 'Collect streak and usage insights for this child.',
        ),
        _buildParentalToggle(
          field: 'emergency_notification_enabled',
          title: 'Emergency notifications',
          subtitle: 'Send alerts if unusual activity is detected.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openParentDashboard,
          icon: const Icon(Icons.dashboard_customize_outlined),
          label: const Text('Open Parent Dashboard'),
        ),
      ],
    );
  }

  Widget _buildParentalControlsMessage(String message, {Widget? action}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        if (action != null) ...[
          const SizedBox(height: 12),
          action,
        ],
      ],
    );
  }

  Widget _buildChildSelector() {
    final selectedId = _selectedChildId ??
        (_childProfiles.isNotEmpty
            ? _childProfiles.first['id'] as String?
            : null);
    return DropdownButtonFormField<String>(
      value: selectedId,
      items: _childProfiles
          .map(
            (profile) {
              final id = profile['id'] as String?;
              if (id == null) return null;
              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  profile['child_name'] ?? 'Child',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          )
          .whereType<DropdownMenuItem<String>>()
          .toList(),
      onChanged: _isUpdatingParentalSetting
          ? null
          : (value) {
              if (value != null) {
                _loadParentalControls(childId: value);
              }
            },
      dropdownColor: const Color(0xFF161324),
      decoration: InputDecoration(
        labelText: 'Child profile',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
        ),
      ),
    );
  }

  Widget _buildParentalToggle({
    required String field,
    required String title,
    required String subtitle,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: _currentSettingBool(field),
      onChanged: _isUpdatingParentalSetting
          ? null
          : (value) => _handleParentalToggle(field, value),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      activeColor: const Color(0xFF8B5CF6),
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildPremiumStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase Status',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Premium Status',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have lifetime access to all premium features.',
                  style: TextStyle(
                    color: Colors.green[200],
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premium Benefits',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...[
          'Ad-free experience',
          'Unlimited stories',
          'All 20+ themes',
          'High quality generation',
          'Offline mode',
          'Priority support',
        ].map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF8B5CF6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumPricing() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _buildPlanPricingTile(
            title: 'Premium',
            price: '\$4.99',
            periodLabel: '/month',
            description:
                'All premium benefits for one listener with zero ads or limits.',
            badgeLabel: 'Best Value',
            badgeColor: Colors.green,
          ),
          const SizedBox(height: 16),
          Divider(
            color: Colors.white.withValues(alpha: 0.08),
            height: 1,
          ),
          const SizedBox(height: 16),
          _buildPlanPricingTile(
            title: 'Family',
            price: '\$14.99',
            periodLabel: '/month',
            description:
                'Unlimited stories for up to 5 family members with shared libraries.',
            secondaryDetail: 'Includes kid-safe profiles & parental controls.',
            badgeLabel: 'Family Bundle',
            badgeColor: const Color(0xFF60A5FA),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPricingTile({
    required String title,
    required String price,
    required String periodLabel,
    required String description,
    required String badgeLabel,
    required Color badgeColor,
    String? secondaryDetail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                periodLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badgeLabel,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (secondaryDetail != null) ...[
          const SizedBox(height: 4),
          Text(
            secondaryDetail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildOtherSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other Settings',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                title: const Text(
                  'About',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A1A),
                      title: const Text(
                        'About Dream Flow',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Dream Flow - Personalized bedtime cinema infused with your nightly rhythm.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'OK',
                            style: TextStyle(color: Color(0xFF8B5CF6)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.08),
                height: 1,
              ),
              ListTile(
                leading: Icon(
                  Icons.help_outline,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                title: const Text(
                  'Help & Support',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handlePurchasePremium() async {
    if (_isProcessingPayment) return;

    // Check if user is authenticated
    if (!_authService.isLoggedIn) {
      // Show dialog prompting user to sign in
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Create an Account First! 🌟',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          content: const Text(
            'To unlock Premium and remove ads, you need to create an account or sign in. It\'s quick and easy! Then you can get all the cool features like unlimited stories and no ads!',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Maybe Later',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
              child: const Text('Sign In / Sign Up'),
            ),
          ],
        ),
      );

      if (shouldSignIn == true && mounted) {
        // Navigate to login screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    setState(() {
      _isProcessingPayment = true;
      _error = null;
    });

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Purchase Premium',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Purchase Premium for \$4.99/month and get unlimited stories, all themes, and an ad-free experience.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isProcessingPayment = false);
        return;
      }

      // Process payment
      await _paymentService.purchaseSubscription('premium');

      // Reload subscription data
      await _loadSubscriptionData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully purchased Premium!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PaymentException catch (e) {
      setState(() => _error = e.message);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Oops! Payment Issue 🛒',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            content: Text(
              e.message.contains('not authenticated') ||
                      e.message.contains('User not authenticated')
                  ? 'You need to sign in or create an account first to make a purchase. It\'s quick and easy!'
                  : 'We couldn\'t complete your purchase right now. Please check with a grown-up and try again later!',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF8B5CF6)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        final errorMsg = e.toString();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Oops! Something Went Wrong 😅',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            content: Text(
              errorMsg.contains('not authenticated') ||
                      errorMsg.contains('User not authenticated')
                  ? 'You need to sign in or create an account first to make a purchase. Don\'t worry, it\'s super easy!'
                  : 'We couldn\'t complete your purchase right now. Please ask a grown-up for help or try again later!',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF8B5CF6)),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }
}
