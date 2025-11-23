import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  final AccessibilityService _accessibilityService = AccessibilityService();
  bool _highContrast = false;
  double _fontScale = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final highContrast = await _accessibilityService.getHighContrast();
    final fontScale = await _accessibilityService.getFontScale();
    if (mounted) {
      setState(() {
        _highContrast = highContrast;
        _fontScale = fontScale;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateHighContrast(bool value) async {
    await _accessibilityService.setHighContrast(value);
    setState(() => _highContrast = value);
    // Trigger app rebuild by showing a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'High contrast mode enabled. Restart app to apply changes.'
              : 'High contrast mode disabled. Restart app to apply changes.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateFontScale(double value) async {
    await _accessibilityService.setFontScale(value);
    setState(() => _fontScale = value);
    // Font scale is applied via MediaQuery, so it should update immediately
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Display Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: SwitchListTile(
                      title: const Text('High Contrast Mode'),
                      subtitle: const Text(
                        'Increases contrast for better visibility',
                      ),
                      value: _highContrast,
                      onChanged: _updateHighContrast,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font Size',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_fontScale * 100).toInt()}%',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Slider(
                            value: _fontScale,
                            min: 0.8,
                            max: 2.0,
                            divisions: 12,
                            label: '${(_fontScale * 100).toInt()}%',
                            onChanged: _updateFontScale,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Smaller',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Larger',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      'Screen Reader Support',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All screens and buttons include semantic labels for screen reader compatibility.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The app is compatible with TalkBack (Android) and VoiceOver (iOS).',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

