import 'package:flutter/material.dart';

/// Reading progress metrics
class ReadingProgress {
  final int storiesCompleted;
  final int totalStories;
  final int minutesListened;
  final int themesExplored;
  final int totalThemes;

  ReadingProgress({
    required this.storiesCompleted,
    required this.totalStories,
    required this.minutesListened,
    required this.themesExplored,
    required this.totalThemes,
  });

  double get storiesProgress =>
      totalStories > 0 ? storiesCompleted / totalStories : 0.0;

  double get themesProgress =>
      totalThemes > 0 ? themesExplored / totalThemes : 0.0;
}

/// Widget to display reading progress
class ProgressTrackerWidget extends StatelessWidget {
  final ReadingProgress progress;
  final bool showDetails;

  const ProgressTrackerWidget({
    super.key,
    required this.progress,
    this.showDetails = true,
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
          // Header
          Row(
            children: [
              const Text(
                '📊',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stories progress
          _buildProgressItem(
            icon: '📚',
            label: 'Stories Completed',
            value: '${progress.storiesCompleted}',
            progress: progress.storiesProgress,
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          // Themes progress
          _buildProgressItem(
            icon: '🌍',
            label: 'Themes Explored',
            value: '${progress.themesExplored}/${progress.totalThemes}',
            progress: progress.themesProgress,
            color: Colors.blue,
          ),
          if (showDetails) ...[
            const SizedBox(height: 16),
            // Minutes listened
            _buildStatItem(
              icon: '⏱️',
              label: 'Minutes Listened',
              value: '${progress.minutesListened}',
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressItem({
    required String icon,
    required String label,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% complete',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
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
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Compact progress display for headers
class CompactProgressWidget extends StatelessWidget {
  final ReadingProgress progress;

  const CompactProgressWidget({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '📚',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            '${progress.storiesCompleted}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular progress indicator for achievements
class CircularProgressWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String label;
  final String value;
  final Color color;
  final double size;

  const CircularProgressWidget({
    super.key,
    required this.progress,
    required this.label,
    required this.value,
    this.color = Colors.blue,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: size * 0.12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

