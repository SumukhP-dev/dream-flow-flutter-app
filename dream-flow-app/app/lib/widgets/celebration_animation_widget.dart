import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget for celebration animations (confetti, sparkles)
class CelebrationAnimationWidget extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;

  const CelebrationAnimationWidget({
    super.key,
    this.duration = const Duration(seconds: 2),
    this.onComplete,
  });

  @override
  State<CelebrationAnimationWidget> createState() =>
      _CelebrationAnimationWidgetState();
}

class _CelebrationAnimationWidgetState
    extends State<CelebrationAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Create particles
    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        color: _getRandomColor(random),
        size: random.nextDouble() * 8 + 4,
        velocityX: (random.nextDouble() - 0.5) * 0.02,
        velocityY: random.nextDouble() * 0.03 + 0.01,
      ));
    }

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getRandomColor(math.Random random) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: CelebrationPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  final Color color;
  final double size;
  final double velocityX;
  final double velocityY;

  Particle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.velocityX,
    required this.velocityY,
  });
}

class CelebrationPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  CelebrationPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = particle.x * size.width;
      final y = particle.y * size.height + (progress * size.height * 2);
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Simple sparkle animation
class SparkleAnimation extends StatefulWidget {
  final Widget child;
  final bool isActive;

  const SparkleAnimation({
    super.key,
    required this.child,
    this.isActive = true,
  });

  @override
  State<SparkleAnimation> createState() => _SparkleAnimationState();
}

class _SparkleAnimationState extends State<SparkleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: CustomPaint(
                painter: SparklePainter(_controller.value),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SparklePainter extends CustomPainter {
  final double animationValue;

  SparklePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final sparkleCount = 8;
    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i * 2 * math.pi / sparkleCount) +
          (animationValue * 2 * math.pi);
      final radius = size.width * 0.3;
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      final opacity = 0.3 +
          (math.sin(animationValue * 2 * math.pi + i) + 1) / 2 * 0.7;

      final sparklePaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      _drawStar(canvas, Offset(x, y), 6, sparklePaint);
    }
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

