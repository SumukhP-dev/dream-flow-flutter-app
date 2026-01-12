import 'package:flutter/material.dart';
import '../shared/accessibility_service.dart';
import '../shared/notification_service.dart';
import '../shared/preferences_service.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  final AccessibilityService _accessibilityService = AccessibilityService();
  final NotificationService _notificationService = NotificationService();
  final PreferencesService _preferencesService = PreferencesService();
  bool _highContrast = false;
  double _fontScale = 1.0;
  bool _isLoading = true;
  bool _maestroEligible = false;
  bool _maestroOptIn = false;
  TimeOfDay? _maestroDigestTime;
  bool _isUpdatingMaestro = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final highContrast = await _accessibilityService.getHighContrast();
    final fontScale = await _accessibilityService.getFontScale();
    NotificationPreferences? notificationPrefs;
    bool isCaregiver = false;
    try {
      notificationPrefs = await _notificationService.getPreferences();
    } catch (_) {
      notificationPrefs = null;
    }
    try {
      isCaregiver = await _preferencesService.isCaregiver();
    } catch (_) {
      isCaregiver = false;
    }
    if (mounted) {
      setState(() {
        _highContrast = highContrast;
        _fontScale = fontScale;
        _maestroEligible = isCaregiver;
        if (notificationPrefs != null) {
          _maestroOptIn = notificationPrefs.maestroNudgesEnabled;
          _maestroDigestTime =
              notificationPrefs.maestroDigestTime != null ? _parseTime(notificationPrefs.maestroDigestTime) : null;
        }
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

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _updateMaestroOptIn(bool value) async {
    setState(() => _isUpdatingMaestro = true);
    try {
      final prefs = await _notificationService.updatePreferences(
        maestroNudgesEnabled: value,
        maestroDigestTime:
            _maestroDigestTime != null ? _timeOfDayToString(_maestroDigestTime!) : null,
      );
      await _preferencesService.cacheMaestroOptIn(prefs.maestroNudgesEnabled);
      setState(() {
        _maestroOptIn = prefs.maestroNudgesEnabled;
        _maestroDigestTime =
            prefs.maestroDigestTime != null ? _parseTime(prefs.maestroDigestTime) : _maestroDigestTime;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update Maestro nudges: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMaestro = false);
      }
    }
  }

  Future<void> _pickMaestroDigestTime() async {
    final initial = _maestroDigestTime ?? const TimeOfDay(hour: 20, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null) return;
    setState(() => _isUpdatingMaestro = true);
    try {
      final prefs = await _notificationService.updatePreferences(
        maestroDigestTime: _timeOfDayToString(selected),
        maestroNudgesEnabled: _maestroOptIn,
      );
      await _preferencesService.cacheMaestroOptIn(prefs.maestroNudgesEnabled);
      setState(() {
        _maestroDigestTime = selected;
        _maestroOptIn = prefs.maestroNudgesEnabled;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update digest time: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMaestro = false);
      }
    }
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
                  if (_maestroEligible) ...[
                    const SizedBox(height: 24),
                    _buildMaestroSection(),
                  ],
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

  Widget _buildMaestroSection() {
    final formattedDigest = _maestroDigestTime != null
        ? MaterialLocalizations.of(context).formatTimeOfDay(_maestroDigestTime!)
        : 'Tap to set a nightly digest time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Maestro Mode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Maestro nudges'),
                subtitle: const Text('Nightly tips and micro-adjustments for caregivers.'),
                value: _maestroOptIn,
                onChanged: _isUpdatingMaestro ? null : _updateMaestroOptIn,
              ),
              ListTile(
                enabled: _maestroOptIn && !_isUpdatingMaestro,
                leading: const Icon(Icons.access_time),
                title: const Text('Digest time'),
                subtitle: Text(
                  _maestroOptIn ? formattedDigest : 'Enable nudges to pick a digest time',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _maestroOptIn ? _pickMaestroDigestTime : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

