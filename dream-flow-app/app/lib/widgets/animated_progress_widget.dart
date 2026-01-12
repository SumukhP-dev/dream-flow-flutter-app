import 'package:flutter/material.dart';

/// Animated progress bar widget
class AnimatedProgressWidget extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final Duration animationDuration;

  const AnimatedProgressWidget({
    super.key,
    required this.progress,
    this.color,
    this.backgroundColor,
    this.height = 8.0,
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedProgressWidget> createState() => _AnimatedProgressWidgetState();
}

class _AnimatedProgressWidgetState extends State<AnimatedProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = Tween<double>(
      begin: _previousProgress,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = _animation.value;
      _animation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: LinearProgressIndicator(
            value: _animation.value.clamp(0.0, 1.0),
            minHeight: widget.height,
            backgroundColor: widget.backgroundColor ?? Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.color ?? Colors.blue.shade400,
            ),
          ),
        );
      },
    );
  }
}

/// Animated circular progress indicator
class AnimatedCircularProgressWidget extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final Color? color;
  final Color? backgroundColor;
  final double strokeWidth;
  final double size;
  final Duration animationDuration;
  final Widget? child;

  const AnimatedCircularProgressWidget({
    super.key,
    required this.progress,
    this.color,
    this.backgroundColor,
    this.strokeWidth = 8.0,
    this.size = 100.0,
    this.animationDuration = const Duration(milliseconds: 500),
    this.child,
  });

  @override
  State<AnimatedCircularProgressWidget> createState() =>
      _AnimatedCircularProgressWidgetState();
}

class _AnimatedCircularProgressWidgetState
    extends State<AnimatedCircularProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = Tween<double>(
      begin: _previousProgress,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCircularProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = _animation.value;
      _animation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _animation.value.clamp(0.0, 1.0),
                strokeWidth: widget.strokeWidth,
                backgroundColor: widget.backgroundColor ?? Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.color ?? Colors.blue.shade400,
                ),
              ),
              if (widget.child != null) widget.child!,
            ],
          );
        },
      ),
    );
  }
}

