import 'package:flutter/material.dart';

class KidProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepEmojis;

  const KidProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepEmojis = const ['✨', '🌟', '⭐', '💫'],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        final isCurrent = index == currentStep - 1;
        final emoji = index < stepEmojis.length
            ? stepEmojis[index]
            : stepEmojis[stepEmojis.length - 1];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 48 : 40,
              height: isCurrent ? 48 : 40,
              decoration: BoxDecoration(
                color: isActive || isCurrent
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive || isCurrent
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.3),
                  width: isCurrent ? 3 : 2,
                ),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: isCurrent ? 24 : 20,
                  ),
                ),
              ),
            ),
            if (index < totalSteps - 1)
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        );
      }),
    );
  }
}

