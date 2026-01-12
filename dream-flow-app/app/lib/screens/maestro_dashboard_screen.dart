import 'package:flutter/material.dart';

import '../services/maestro_service.dart';
import '../services/feature_flag_service.dart';
import '../shared/preferences_service.dart';
import 'accessibility_settings_screen.dart';

class MaestroDashboardScreen extends StatefulWidget {
  const MaestroDashboardScreen({super.key});

  @override
  State<MaestroDashboardScreen> createState() => _MaestroDashboardScreenState();
}

class _MaestroDashboardScreenState extends State<MaestroDashboardScreen> {
  final MaestroService _maestroService = MaestroService();
  final PreferencesService _preferencesService = PreferencesService();
  final FeatureFlagService _flagService = FeatureFlagService();

  MaestroInsights? _insights;
  bool _isLoading = true;
  bool _maestroAllowed = false;
  // These fields are set but used only to compute _maestroAllowed
  // ignore: unused_field
  bool _isCaregiver = false;
  // ignore: unused_field
  bool _isOptedIn = false;
  String? _error;
  final Map<String, double> _sliderValues = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final isFlagEnabled = await _flagService.isEnabled(FeatureFlag.maestro);
    final isCaregiver = await _preferencesService.isCaregiver();
    final optIn = await _preferencesService.isMaestroOptedIn();

    if (!mounted) return;
    setState(() {
      _isCaregiver = isCaregiver;
      _isOptedIn = optIn;
      _maestroAllowed = isFlagEnabled && isCaregiver && optIn;
    });

    if (isFlagEnabled && isCaregiver && optIn) {
      await _loadInsights();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccessibilitySettingsScreen(),
      ),
    );
    if (mounted) {
      _bootstrap();
    }
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final insights = await _maestroService.getInsights();
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maestro Coach View'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_maestroAllowed
          ? _buildGateMessage()
          : RefreshIndicator(
              onRefresh: _loadInsights,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : _buildDashboard(),
            ),
    );
  }

  Widget _buildGateMessage() {
    final subtitle = !_isCaregiver
        ? 'Maestro Mode is only available to verified caregivers with a child profile.'
        : 'Turn on Maestro nudges inside caregiver settings to unlock the dashboard.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open caregiver settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.redAccent.withValues(alpha: 0.1),
          ),
          child: Column(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error ?? 'Unknown error'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadInsights,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    final insights = _insights!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TipCard(tip: insights.nightlyTip, streakDays: insights.streakDays),
        const SizedBox(height: 16),
        _buildTrendRow(insights),
        const SizedBox(height: 16),
        _EnvironmentCard(environment: insights.environment),
        const SizedBox(height: 16),
        _buildQuickActions(insights.quickActions),
      ],
    );
  }

  Widget _buildTrendRow(MaestroInsights insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trend beacons',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: insights.trends
              .map(
                (trend) => Chip(
                  label: Text(
                    '${trend.label} • ${trend.deltaMinutes.toStringAsFixed(1)} min',
                  ),
                  avatar: Icon(
                    trend.direction == TrendDirection.down
                        ? Icons.south
                        : trend.direction == TrendDirection.up
                            ? Icons.north
                            : Icons.remove,
                    color: trend.direction == TrendDirection.down
                        ? Colors.greenAccent
                        : trend.direction == TrendDirection.up
                            ? Colors.orangeAccent
                            : Colors.blueGrey,
                  ),
                ),
              )
              .toList(),
        ),
        if (insights.hasTravelShift) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.blueGrey.withValues(alpha: 0.2),
            ),
            child: Row(
              children: const [
                Icon(Icons.flight_takeoff_rounded),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Travel shift detected • reminders adjust to local bedtime.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(List<MaestroQuickAction> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.tune_rounded),
            SizedBox(width: 8),
            Text('Maestro quick-actions'),
          ],
        ),
        const SizedBox(height: 12),
        ...actions.map((action) {
          final hasSlider = action.min != null && action.max != null;
          final sliderValue = _sliderValues[action.id] ?? action.value ?? 50;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${action.icon} ${action.label}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (hasSlider)
                  Slider(
                    value: sliderValue,
                    min: action.min!,
                    max: action.max!,
                    onChanged: (value) {
                      setState(() => _sliderValues[action.id] = value);
                    },
                    onChangeEnd: (value) {
                      _maestroService.triggerQuickAction(
                        action.id,
                        sliderValue: value,
                      );
                    },
                  )
                else
                  ElevatedButton(
                    onPressed: () =>
                        _maestroService.triggerQuickAction(action.id),
                    child: const Text('Trigger'),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip, required this.streakDays});

  final MaestroTip tip;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF7c3aed), Color(0xFF0ea5e9)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip.title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(tip.description),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(tip.microAdjustment),
          ),
          const SizedBox(height: 12),
          Text(
              'Confidence ${(tip.confidence * 100).round()}% • Streak $streakDays nights'),
        ],
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard({required this.environment});

  final EnvironmentInsights environment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Environment readiness',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _ProgressRow(
              label: 'Lighting rhythm', value: environment.lightingScore),
          const SizedBox(height: 8),
          _ProgressRow(
              label: 'Diffuser cadence', value: environment.scentScore),
          const SizedBox(height: 16),
          ...environment.quickNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.brightness_low, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          color: Colors.greenAccent,
        ),
      ],
    );
  }
}
