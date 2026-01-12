import 'package:flutter/material.dart';
import '../services/achievement_service.dart';

/// Widget to display an achievement badge
class AchievementBadgeWidget extends StatelessWidget {
  final Achievement achievement;
  final bool showProgress;
  final double? progress; // 0.0 to 1.0
  final VoidCallback? onTap;
  final double size;

  const AchievementBadgeWidget({
    super.key,
    required this.achievement,
    this.showProgress = false,
    this.progress,
    this.onTap,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: achievement.isNew
              ? LinearGradient(
                  colors: [
                    Colors.amber.shade300,
                    Colors.orange.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.grey.shade300,
                    Colors.grey.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: achievement.isNew
                  ? Colors.amber.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Badge emoji/text
            Text(
              achievement.type.emoji,
              style: TextStyle(fontSize: size * 0.5),
            ),
            // Progress ring (if showing progress)
            if (showProgress && progress != null && progress! < 1.0)
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade400,
                  ),
                ),
              ),
            // "New" indicator
            if (achievement.isNew)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display an achievement badge with title and description
class AchievementCardWidget extends StatelessWidget {
  final Achievement achievement;
  final bool showProgress;
  final double? progress;

  const AchievementCardWidget({
    super.key,
    required this.achievement,
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: achievement.isNew ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: achievement.isNew
            ? BorderSide(color: Colors.amber.shade400, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Badge
            AchievementBadgeWidget(
              achievement: achievement,
              showProgress: showProgress,
              progress: progress,
              size: 64,
            ),
            const SizedBox(width: 16),
            // Title and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        achievement.type.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: achievement.isNew
                              ? Colors.orange.shade700
                              : Colors.grey.shade800,
                        ),
                      ),
                      if (achievement.isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.type.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (showProgress && progress != null && progress! < 1.0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Unlocked date
            if (!showProgress)
              Text(
                _formatDate(achievement.unlockedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Widget to display a locked achievement (not yet unlocked)
class LockedAchievementWidget extends StatelessWidget {
  final AchievementType type;
  final double progress; // 0.0 to 1.0
  final double size;

  const LockedAchievementWidget({
    super.key,
    required this.type,
    required this.progress,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade400, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Locked emoji (grayed out)
          Opacity(
            opacity: 0.5,
            child: Text(
              type.emoji,
              style: TextStyle(fontSize: size * 0.5),
            ),
          ),
          // Progress ring
          Positioned.fill(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.blue.shade400,
              ),
            ),
          ),
          // Lock icon overlay
          Positioned(
            bottom: 4,
            child: Icon(
              Icons.lock,
              size: size * 0.25,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

