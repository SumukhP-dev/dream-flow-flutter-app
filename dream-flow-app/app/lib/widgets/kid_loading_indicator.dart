import 'package:flutter/material.dart';
import 'dart:math' as math;

class KidLoadingIndicator extends StatefulWidget {
  final String? message;
  final double size;

  const KidLoadingIndicator({
    super.key,
    this.message,
    this.size = 80,
  });

  @override
  State<KidLoadingIndicator> createState() => _KidLoadingIndicatorState();
}

class _KidLoadingIndicatorState extends State<KidLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: SparklePainter(_controller.value),
              );
            },
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 24),
          Text(
            widget.message!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class SparklePainter extends CustomPainter {
  final double animationValue;

  SparklePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw rotating sparkles
    final sparkleCount = 8;
    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i * 2 * math.pi / sparkleCount) + (animationValue * 2 * math.pi);
      final sparkleRadius = radius * 0.7;
      final x = center.dx + math.cos(angle) * sparkleRadius;
      final y = center.dy + math.sin(angle) * sparkleRadius;

      // Animate opacity
      final opacity = 0.3 + (math.sin(animationValue * 2 * math.pi + i) + 1) / 2 * 0.7;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Draw star shape
      _drawStar(canvas, Offset(x, y), 8, paint);
    }

    // Draw center sparkle
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    _drawStar(canvas, center, 12, centerPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final points = 5;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.4;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SparklePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

