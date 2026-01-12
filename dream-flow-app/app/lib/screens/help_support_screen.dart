import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/backend_url_helper.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  bool _isSubmitting = false;
  String? _submitMessage;
  bool _isSuccess = false;
  
  final List<FAQItem> _faqs = [
    FAQItem(
      question: 'How do I create a story?',
      answer: 'Tap the "Create Story" button on the home screen, enter your prompt and choose a theme. The app will generate a personalized bedtime story for you.',
    ),
    FAQItem(
      question: 'Can I customize story themes?',
      answer: 'Yes! You can choose from various themes like Ocean Dreams, Forest Friends, Space Explorer, and more. Each theme creates a unique storytelling experience.',
    ),
    FAQItem(
      question: 'How do subscriptions work?',
      answer: 'We offer Free, Premium, and Family plans. Free users get limited stories per month. Premium and Family plans offer unlimited stories and additional features.',
    ),
    FAQItem(
      question: 'Can I save my favorite stories?',
      answer: 'Yes! All your generated stories are automatically saved to your story history. You can access them anytime from the "My Stories" section.',
    ),
    FAQItem(
      question: 'Is the app safe for children?',
      answer: 'Absolutely! We have child-safe content filters and parental controls. Family plans include additional safety features and age-appropriate content.',
    ),
    FAQItem(
      question: 'How do I cancel my subscription?',
      answer: 'Go to Settings > Subscription and tap "Cancel Subscription". Your subscription will remain active until the end of the current billing period.',
    ),
    FAQItem(
      question: 'Can I use the app offline?',
      answer: 'Premium and Family subscribers can download stories for offline listening. Free users need an internet connection to generate new stories.',
    ),
    FAQItem(
      question: 'How do I report inappropriate content?',
      answer: 'You can report content directly from any story screen using the report button, or contact us through this support form.',
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitMessage = null;
      _isSuccess = false;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      
      final backendUrl = BackendUrlHelper.getBackendUrl(
        defaultValue: 'http://localhost:8080',
      );
      
      final uri = Uri.parse('$backendUrl/api/v1/support/contact');
      
      final requestBody = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        if (user != null) 'user_id': user.id,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = true;
          _submitMessage = 'Thank you! Your support request has been submitted. We\'ll get back to you soon.';
        });
        
        // Clear form
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
      } else {
        final errorBody = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>?
            : null;
        final errorMessage = errorBody?['detail'] as String? ??
            errorBody?['error'] as String? ??
            'Failed to submit support request. Please try again.';
        
        setState(() {
          _isSubmitting = false;
          _isSuccess = false;
          _submitMessage = errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _isSuccess = false;
        _submitMessage = 'Error submitting request: ${e.toString()}. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0F0F0F),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ..._faqs.map((faq) => _FAQExpansionTile(faq: faq)),
            const SizedBox(height: 32),
            
            // Contact Form Section
            const Text(
              'Contact Us',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Have a question or need help? Send us a message and we\'ll get back to you as soon as possible.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                      alignLabelWithHint: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 6,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your message';
                      }
                      if (value.trim().length < 10) {
                        return 'Please provide more details (at least 10 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  if (_submitMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _isSuccess
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        _submitMessage!,
                        style: TextStyle(
                          color: _isSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitSupportRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

class _FAQExpansionTile extends StatefulWidget {
  final FAQItem faq;

  const _FAQExpansionTile({required this.faq});

  @override
  State<_FAQExpansionTile> createState() => _FAQExpansionTileState();
}

class _FAQExpansionTileState extends State<_FAQExpansionTile> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        title: Text(
          widget.faq.question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: const Color(0xFF1A1A1A),
        collapsedBackgroundColor: const Color(0xFF1A1A1A),
        iconColor: const Color(0xFF8B5CF6),
        collapsedIconColor: Colors.grey,
        onExpansionChanged: (expanded) {
          // Expansion state is handled by ExpansionTile internally
        },
        children: [
          Text(
            widget.faq.answer,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

