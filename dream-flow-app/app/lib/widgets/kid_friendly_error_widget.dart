import 'package:flutter/material.dart';

enum KidFriendlyErrorType {
  error,
  warning,
  success,
  loading,
}

class KidFriendlyErrorWidget extends StatelessWidget {
  final String message;
  final KidFriendlyErrorType type;
  final VoidCallback? onRetry;
  final bool showRetryButton;

  const KidFriendlyErrorWidget({
    super.key,
    required this.message,
    this.type = KidFriendlyErrorType.error,
    this.onRetry,
    this.showRetryButton = true,
  });

  String get _emoji {
    switch (type) {
      case KidFriendlyErrorType.success:
        return '😊';
      case KidFriendlyErrorType.error:
        return '😕';
      case KidFriendlyErrorType.warning:
        return '🤔';
      case KidFriendlyErrorType.loading:
        return '⏳';
    }
  }

  Color get _backgroundColor {
    switch (type) {
      case KidFriendlyErrorType.success:
        return Colors.green.withValues(alpha: 0.15);
      case KidFriendlyErrorType.error:
        return Colors.redAccent.withValues(alpha: 0.15);
      case KidFriendlyErrorType.warning:
        return Colors.orange.withValues(alpha: 0.15);
      case KidFriendlyErrorType.loading:
        return Colors.blue.withValues(alpha: 0.15);
    }
  }

  Color get _borderColor {
    switch (type) {
      case KidFriendlyErrorType.success:
        return Colors.green.withValues(alpha: 0.3);
      case KidFriendlyErrorType.error:
        return Colors.redAccent.withValues(alpha: 0.3);
      case KidFriendlyErrorType.warning:
        return Colors.orange.withValues(alpha: 0.3);
      case KidFriendlyErrorType.loading:
        return Colors.blue.withValues(alpha: 0.3);
    }
  }

  Color get _textColor {
    switch (type) {
      case KidFriendlyErrorType.success:
        return Colors.green.shade100;
      case KidFriendlyErrorType.error:
        return Colors.redAccent.shade100;
      case KidFriendlyErrorType.warning:
        return Colors.orange.shade100;
      case KidFriendlyErrorType.loading:
        return Colors.blue.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderColor,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _emoji,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _textColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (showRetryButton && onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _borderColor,
                minimumSize: const Size(200, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Try Again!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

