import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/reflection_service.dart';

class ReflectionCaptureSheet extends StatefulWidget {
  const ReflectionCaptureSheet({
    super.key,
    required this.onSubmitted,
    this.sessionId,
    this.initialPrompt,
  });

  final Future<void> Function(
    ReflectionMood mood,
    String? note,
    String? audioPath,
  )
  onSubmitted;
  final String? sessionId;
  final String? initialPrompt;

  @override
  State<ReflectionCaptureSheet> createState() => _ReflectionCaptureSheetState();
}

class _ReflectionCaptureSheetState extends State<ReflectionCaptureSheet> {
  final TextEditingController _noteController = TextEditingController();
  final Record _recorder = Record();
  ReflectionMood _selectedMood = ReflectionMood.calm;
  bool _isSubmitting = false;
  bool _isRecording = false;
  String? _audioPath;
  static const List<String> _noteSeeds = [
    '✨ Highlight that stood out',
    '🌿 Calming anchor (sound, scent, texture)',
    '🚪 Transition or bedtime ritual detail',
    '🎭 Funny quote or character moment',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _noteController.text = widget.initialPrompt!;
      _noteController.selection = TextSelection.fromPosition(
        TextPosition(offset: _noteController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final filePath = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = filePath;
      });
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/reflection_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(path: path, encoder: AudioEncoder.aacHe);
    setState(() => _isRecording = true);
  }

  void _applySeed(String seed) {
    final existing = _noteController.text.trim();
    final updated = existing.isEmpty ? seed : '$existing\n$seed';
    _noteController
      ..text = updated
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: updated.length),
      );
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    await widget.onSubmitted(
      _selectedMood,
      _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      _audioPath,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            'Quick Reflection',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: ReflectionMood.values.map((mood) {
              final selected = mood == _selectedMood;
              return ChoiceChip(
                label: Text('${mood.emoji} ${mood.label}'),
                selected: selected,
                onSelected: (_) => setState(() => _selectedMood = mood),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Narrative nudges',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _noteSeeds
                .map(
                  (seed) => ActionChip(
                    label: Text(seed),
                    onPressed: _isSubmitting ? null : () => _applySeed(seed),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Add a narrative note or motif (optional)',
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            tileColor: Colors.white.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Icon(
              _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
              color: _isRecording ? Colors.redAccent : Colors.white,
            ),
            title: Text(_isRecording ? 'Recording...' : 'Add a 30s voice note'),
            subtitle: _audioPath != null
                ? const Text('Voice note attached')
                : null,
            onTap: _isSubmitting ? null : _toggleRecording,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save reflection'),
            ),
          ),
        ],
      ),
    );
  }
}
