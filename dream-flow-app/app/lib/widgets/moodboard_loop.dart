import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class MoodboardLoopWidget extends StatefulWidget {
  const MoodboardLoopWidget({
    super.key,
    required this.frames,
    this.height = 220,
    this.minimalMode = false,
    this.enableControls = false,
  });

  final List<String> frames;
  final double height;
  final bool minimalMode;
  final bool enableControls;

  @override
  State<MoodboardLoopWidget> createState() => _MoodboardLoopWidgetState();
}

class _MoodboardLoopWidgetState extends State<MoodboardLoopWidget> {
  int _currentIndex = 0;
  Timer? _timer;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _startLoop();
  }

  @override
  void didUpdateWidget(covariant MoodboardLoopWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      _currentIndex = 0;
    }
    _startLoop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLoop() {
    _timer?.cancel();
    if (widget.frames.length <= 1 || !_isPlaying) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_isPlaying) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.frames.length;
      });
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _startLoop();
    } else {
      _timer?.cancel();
    }
  }

  void _stepFrame(int delta) {
    if (widget.frames.isEmpty) return;
    setState(() {
      final nextIndex =
          (_currentIndex + delta) % widget.frames.length;
      _currentIndex = nextIndex < 0
          ? widget.frames.length + nextIndex
          : nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty || widget.minimalMode) {
      return _buildMinimalPlaceholder();
    }

    final currentFrame = widget.frames[_currentIndex];

    final loop = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 900),
        child: Container(
          key: ValueKey(currentFrame),
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1b1436), Color(0xFF040108)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: currentFrame.startsWith('data:image')
              ? Image.memory(
                  _decodeDataUri(currentFrame),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildMinimalPlaceholder(),
                )
              : Image.network(
                  currentFrame,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (_, __, ___) => _buildMinimalPlaceholder(),
                ),
        ),
      ),
    );

    if (!widget.enableControls) {
      return loop;
    }

    return Stack(
      children: [
        loop,
        Positioned(
          right: 16,
          bottom: 12,
          child: _buildControls(),
        ),
      ],
    );
  }

  Widget _buildMinimalPlaceholder() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0f172a).withValues(alpha: 0.8),
            const Color(0xFF020617).withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.landscape_rounded, color: Colors.white54),
            SizedBox(height: 8),
            Text(
              'Moodboard visuals off',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Uint8List _decodeDataUri(String input) {
    final base64String = input.split(',').last;
    return Uint8List.fromList(const Base64Decoder().convert(base64String));
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 20,
            onPressed: () => _stepFrame(-1),
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          ),
          IconButton(
            iconSize: 20,
            onPressed: _togglePlay,
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            iconSize: 20,
            onPressed: () => _stepFrame(1),
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

