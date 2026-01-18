import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
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
                'Dream Flow Privacy Policy',
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
                '1. Information We Collect',
                'We collect information you provide directly to us, such as when you create an account, use our services, or contact us for support. This includes your name, email address, and content you create.',
              ),
              _buildSection(
                '2. How We Use Your Information',
                'We use the information we collect to provide, maintain, and improve our services, process transactions, send you technical notices and support messages, and communicate with you about products, services, and promotions.',
              ),
              _buildSection(
                '3. Information Sharing',
                'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy. We may share your information in limited circumstances, such as with service providers or when required by law.',
              ),
              _buildSection(
                '4. Children\'s Privacy',
                'Dream Flow is designed for children under parental supervision. We are committed to protecting children\'s privacy. We do not knowingly collect personal information from children under 13 without parental consent.',
              ),
              _buildSection(
                '5. Data Security',
                'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
              ),
              _buildSection(
                '6. Story Content and AI Processing',
                'Stories you create are processed by our AI systems to generate audio and visual content. We may store story content temporarily to provide our services, but we prioritize the privacy and safety of user-generated content.',
              ),
              _buildSection(
                '7. Cookies and Analytics',
                'We use cookies and similar technologies to enhance your experience, analyze usage patterns, and improve our services. You can control cookie settings through your browser preferences.',
              ),
              _buildSection(
                '8. Third-Party Services',
                'Our app may integrate with third-party services (such as payment processors or analytics providers). These services have their own privacy policies, and we encourage you to review them.',
              ),
              _buildSection(
                '9. Data Retention',
                'We retain your personal information for as long as necessary to provide our services and fulfill the purposes outlined in this policy, unless a longer retention period is required by law.',
              ),
              _buildSection(
                '10. Your Rights',
                'You have the right to access, update, or delete your personal information. You may also request that we limit the processing of your information in certain circumstances.',
              ),
              _buildSection(
                '11. International Data Transfers',
                'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your information during such transfers.',
              ),
              _buildSection(
                '12. Changes to This Policy',
                'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page and updating the "last updated" date.',
              ),
              _buildSection(
                '13. Contact Us',
                'If you have questions about this Privacy Policy or our privacy practices, please contact us at privacy@dreamflow.com.',
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