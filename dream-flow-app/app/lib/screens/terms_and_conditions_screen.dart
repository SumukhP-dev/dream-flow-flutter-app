import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AbsorbPointer(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dream Flow Terms and Conditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '1. Acceptance of Terms',
                'By accessing and using Dream Flow, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
              ),
              _buildSection(
                '2. Description of Service',
                'Dream Flow is an AI-powered bedtime story generation platform that creates personalized stories for children. Our service includes story generation, audio narration, visual illustrations, and family sharing features.',
              ),
              _buildSection(
                '3. User Accounts',
                'To use our service, you must create an account. You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account. You agree to notify us immediately of any unauthorized use of your account.',
              ),
              _buildSection(
                '4. Content Ownership and Usage',
                'All stories generated through our platform are created for personal use. You retain ownership of stories you create. However, you grant us a limited license to store and process your content to provide our services.',
              ),
              _buildSection(
                '5. Parental Responsibility',
                'Dream Flow is designed for children with parental supervision. Parents and guardians are responsible for monitoring their children\'s use of the service and ensuring appropriate content consumption.',
              ),
              _buildSection(
                '6. Privacy and Data Protection',
                'Your privacy is important to us. Please review our Privacy Policy, which also governs your use of Dream Flow, to understand our practices.',
              ),
              _buildSection(
                '7. Prohibited Uses',
                'You may not use Dream Flow for any unlawful purpose or to solicit the performance of any illegal activity. This includes, but is not limited to, creating inappropriate content or violating content guidelines.',
              ),
              _buildSection(
                '8. Content Moderation',
                'We reserve the right to monitor, review, and remove content that violates our guidelines. We may also suspend or terminate accounts that repeatedly violate our terms.',
              ),
              _buildSection(
                '9. Subscription and Payment',
                'Some features may require a subscription. Payment terms are outlined in our pricing section. Subscriptions auto-renew unless cancelled. Refunds are subject to our refund policy.',
              ),
              _buildSection(
                '10. Service Availability',
                'While we strive for high availability, we do not guarantee uninterrupted service. We reserve the right to modify or discontinue features with reasonable notice.',
              ),
              _buildSection(
                '11. Limitation of Liability',
                'Dream Flow is provided "as is" without warranties. We shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the service.',
              ),
              _buildSection(
                '12. Changes to Terms',
                'We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.',
              ),
              _buildSection(
                '13. Governing Law',
                'These terms are governed by applicable laws. Any disputes shall be resolved through binding arbitration.',
              ),
              _buildSection(
                '14. Contact Information',
                'If you have questions about these Terms and Conditions, please contact us at support@dreamflow.com.',
              ),
              const SizedBox(height: 40),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}