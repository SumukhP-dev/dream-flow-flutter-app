import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/payment_service.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  late final PaymentService _paymentService;
  Subscription? _subscription;
  UsageQuota? _usageQuota;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
    _loadSubscriptionData();
  }

  Future<void> _initializePaymentService() async {
    // Get API keys from environment or config
    final revenuecatApiKey = const String.fromEnvironment(
      'REVENUECAT_API_KEY',
      defaultValue: '',
    );
    final stripePublishableKey = const String.fromEnvironment(
      'STRIPE_PUBLISHABLE_KEY',
      defaultValue: '',
    );

    _paymentService = PaymentService(
      revenuecatApiKey: revenuecatApiKey.isNotEmpty ? revenuecatApiKey : null,
      stripePublishableKey: stripePublishableKey.isNotEmpty
          ? stripePublishableKey
          : null,
      subscriptionService: _subscriptionService,
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

    try {
      final subscription = await _subscriptionService.getSubscription();
      final usageQuota = await _subscriptionService.getUsageQuota();

      setState(() {
        _subscription = subscription;
        _usageQuota = usageQuota;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading subscription',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSubscriptionData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_subscription != null) ...[
                    _buildCurrentSubscriptionCard(),
                    const SizedBox(height: 24),
                  ],
                  if (_usageQuota != null) ...[
                    _buildUsageQuotaCard(),
                    const SizedBox(height: 24),
                  ],
                  _buildSubscriptionTiers(),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 24),
                    _buildRestorePurchasesButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRestorePurchasesButton() {
    return OutlinedButton.icon(
      onPressed: _isProcessingPayment
          ? null
          : () async {
              setState(() {
                _isProcessingPayment = true;
                _error = null;
              });

              try {
                final subscription = await _paymentService.restorePurchases();
                if (subscription != null) {
                  await _loadSubscriptionData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchases restored successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No purchases found to restore.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              } catch (e) {
                setState(() => _error = e.toString());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to restore purchases: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isProcessingPayment = false);
                }
              }
            },
      icon: const Icon(Icons.restore),
      label: const Text('Restore Purchases'),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    if (_subscription == null) return const SizedBox.shrink();

    final isPremium = _subscription!.isPremium;
    final isActive = _subscription!.isActive;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPremium ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _subscription!.tier.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Status: ${_subscription!.status}',
              style: TextStyle(
                fontSize: 14,
                color: isActive ? Colors.green : Colors.grey,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Text(
                'Renews: ${_formatDate(_subscription!.currentPeriodEnd)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            if (_subscription!.cancelAtPeriodEnd) ...[
              const SizedBox(height: 8),
              Text(
                'Cancels at period end',
                style: TextStyle(fontSize: 14, color: Colors.orange),
              ),
            ],
            if (!isPremium && isActive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to upgrade options
                    _showUpgradeDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Upgrade to Premium'),
                ),
              ),
            ],
            if (isPremium && isActive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _showCancelDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel Subscription'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageQuotaCard() {
    if (_usageQuota == null) return const SizedBox.shrink();

    final quota = _usageQuota!;
    final isUnlimited = quota.isUnlimited;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage This Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (isUnlimited) ...[
              Row(
                children: [
                  Icon(Icons.all_inclusive, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Unlimited stories',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${quota.currentCount} / ${quota.quota} stories',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${quota.remaining} remaining',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: quota.usagePercentage,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  quota.canGenerate ? Colors.blue : Colors.red,
                ),
              ),
              if (!quota.canGenerate && quota.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  quota.errorMessage!,
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionTiers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subscription Plans',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTierCard(
          tier: 'Free',
          price: '\$0',
          period: 'forever',
          features: [
            '7 stories per week',
            '5 rotating themes',
            'Standard quality',
            'No ads',
          ],
          isCurrent: _subscription?.tier == 'free',
          isPremium: false,
        ),
        const SizedBox(height: 12),
        _buildTierCard(
          tier: 'Premium',
          price: '\$9.99',
          period: 'month',
          annualPrice: '\$79.99',
          annualPeriod: 'year (\$6.67/mo)',
          features: [
            'Unlimited stories',
            'All 20+ themes',
            'High quality',
            'Offline mode',
            'Priority support',
          ],
          isCurrent: _subscription?.tier == 'premium',
          isPremium: true,
        ),
        const SizedBox(height: 12),
        _buildTierCard(
          tier: 'Family',
          price: '\$14.99',
          period: 'month',
          annualPrice: '\$119.99',
          annualPeriod: 'year (\$10/mo)',
          features: [
            'Unlimited stories',
            'Up to 5 family members',
            'All 20+ themes',
            'High quality',
            'Family-friendly content',
          ],
          isCurrent: _subscription?.tier == 'family',
          isPremium: true,
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String tier,
    required String price,
    required String period,
    String? annualPrice,
    String? annualPeriod,
    required List<String> features,
    required bool isCurrent,
    required bool isPremium,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool showAnnual = false;
        return Card(
          elevation: isCurrent ? 4 : 2,
          color: isCurrent ? Colors.blue[50] : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tier,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CURRENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (annualPrice != null && isPremium) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => showAnnual = false),
                        style: TextButton.styleFrom(
                          foregroundColor: !showAnnual
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        child: const Text('Monthly'),
                      ),
                      Switch(
                        value: showAnnual,
                        onChanged: (value) =>
                            setState(() => showAnnual = value),
                      ),
                      TextButton(
                        onPressed: () => setState(() => showAnnual = true),
                        style: TextButton.styleFrom(
                          foregroundColor: showAnnual
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        child: const Text('Annual'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      showAnnual && annualPrice != null ? annualPrice : price,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        showAnnual && annualPeriod != null
                            ? '/$annualPeriod'
                            : '/$period',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                if (showAnnual && annualPrice != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Save 33%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(feature, style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isCurrent)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessingPayment
                          ? null
                          : () {
                              _handleUpgrade(tier.toLowerCase());
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPremium ? Colors.green : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                          : Text(
                              isPremium ? 'Upgrade to $tier' : 'Select Plan',
                            ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleUpgrade(String tier) async {
    if (_isProcessingPayment) return;

    setState(() {
      _isProcessingPayment = true;
      _error = null;
    });

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Upgrade to ${tier.toUpperCase()}'),
          content: Text(
            tier == 'premium'
                ? 'Upgrade to Premium for \$9.99/month (\$79.99/year) and get unlimited stories, all themes, and premium features.'
                : 'Upgrade to Family for \$14.99/month (\$119.99/year) and get unlimited stories for up to 5 family members.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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
      final subscription = await _paymentService.purchaseSubscription(tier);

      // Reload subscription data
      await _loadSubscriptionData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully upgraded to ${tier.toUpperCase()}!'),
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
            title: const Text('Payment Error'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to process payment: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
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

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text(
          'Upgrade to unlock unlimited stories, all themes, and premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUpgrade('premium');
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your subscription? You will continue to have access until the end of your billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _subscriptionService.cancelSubscription(
                  cancelAtPeriodEnd: true,
                );
                _loadSubscriptionData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subscription will cancel at period end'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
