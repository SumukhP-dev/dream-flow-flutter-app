import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Badge widget to show when a story is featured on YouTube
class YouTubeBadge extends StatelessWidget {
  final String? youtubeUrl;
  final bool isFeatured;

  const YouTubeBadge({
    super.key,
    this.youtubeUrl,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFeatured || youtubeUrl == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _openYouTube(youtubeUrl!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              'Featured on YouTube',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Button to watch story on YouTube
class WatchOnYouTubeButton extends StatelessWidget {
  final String youtubeUrl;
  final bool isCompact;

  const WatchOnYouTubeButton({
    super.key,
    required this.youtubeUrl,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _openYouTube(youtubeUrl),
      icon: const Icon(Icons.play_circle_outline, size: 20),
      label: Text(isCompact ? 'YouTube' : 'Watch on YouTube'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF0000),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 24,
          vertical: isCompact ? 12 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  Future<void> _openYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

