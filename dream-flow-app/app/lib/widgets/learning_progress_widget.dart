import 'package:flutter/material.dart';

/// Widget to display learning progress metrics
class LearningProgressWidget extends StatelessWidget {
  final String childProfileId;
  final int storiesCompleted;
  final int vocabularyWordsLearned;
  final int questionsAnsweredCorrectly;
  final double? comprehensionScore;

  const LearningProgressWidget({
    super.key,
    required this.childProfileId,
    required this.storiesCompleted,
    required this.vocabularyWordsLearned,
    required this.questionsAnsweredCorrectly,
    this.comprehensionScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📚',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Learning Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildMetric(
            icon: '📖',
            label: 'Stories Read',
            value: storiesCompleted.toString(),
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            icon: '🔤',
            label: 'Words Learned',
            value: vocabularyWordsLearned.toString(),
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildMetric(
            icon: '✅',
            label: 'Questions Answered',
            value: questionsAnsweredCorrectly.toString(),
            color: Colors.green,
          ),
          if (comprehensionScore != null) ...[
            const SizedBox(height: 16),
            _buildMetric(
              icon: '🧠',
              label: 'Comprehension Score',
              value: '${(comprehensionScore! * 100).toStringAsFixed(0)}%',
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            // `Color` doesn't have `.shade*` getters (only `MaterialColor` does).
            // Use a light tint of the base color instead.
            color: Color.lerp(color, Colors.white, 0.9) ??
                color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.lerp(color, Colors.white, 0.6) ??
                  color.withValues(alpha: 0.30),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.lerp(color, Colors.black, 0.3) ?? color,
            ),
          ),
        ),
      ],
    );
  }
}

