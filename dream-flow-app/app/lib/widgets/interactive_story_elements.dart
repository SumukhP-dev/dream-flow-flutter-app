import 'package:flutter/material.dart';

/// Widget for interactive story elements that respond to taps
class InteractiveStoryElement extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? soundEffect;
  final bool animateOnTap;

  const InteractiveStoryElement({
    super.key,
    required this.child,
    this.onTap,
    this.soundEffect,
    this.animateOnTap = true,
  });

  @override
  State<InteractiveStoryElement> createState() =>
      _InteractiveStoryElementState();
}

class _InteractiveStoryElementState extends State<InteractiveStoryElement>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.animateOnTap) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.animateOnTap) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.animateOnTap) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Widget for animated story elements (sparkles, stars, etc.)
class AnimatedStoryElement extends StatefulWidget {
  final String type; // 'sparkle', 'star', 'heart', etc.
  final double size;
  final Color? color;

  const AnimatedStoryElement({
    super.key,
    required this.type,
    this.size = 24,
    this.color,
  });

  @override
  State<AnimatedStoryElement> createState() => _AnimatedStoryElementState();
}

class _AnimatedStoryElementState extends State<AnimatedStoryElement>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: _buildElement(),
          ),
        );
      },
    );
  }

  Widget _buildElement() {
    final color = widget.color ?? Colors.yellow.shade400;
    final emoji = _getEmojiForType(widget.type);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: widget.size * 0.7),
        ),
      ),
    );
  }

  String _getEmojiForType(String type) {
    switch (type) {
      case 'sparkle':
        return '✨';
      case 'star':
        return '⭐';
      case 'heart':
        return '❤️';
      case 'star2':
        return '🌟';
      default:
        return '✨';
    }
  }
}

