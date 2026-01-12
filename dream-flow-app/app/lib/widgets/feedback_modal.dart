import 'package:flutter/material.dart';
import '../shared/feedback_service.dart';

class FeedbackModal extends StatefulWidget {
  final String sessionId;
  final Function(int rating, int moodDelta)? onSubmitted;
  final VoidCallback? onDismissed;

  const FeedbackModal({
    super.key,
    required this.sessionId,
    this.onSubmitted,
    this.onDismissed,
  });

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal> {
  int? _rating;
  int? _moodDelta;
  bool _isSubmitting = false;
  String? _error;
  final FeedbackService _feedbackService = FeedbackService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1625),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.feedback_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'How was your session?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            widget.onDismissed?.call();
                            Navigator.of(context).pop();
                          },
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating Section
                  _buildRatingSection(),

                  const SizedBox(height: 32),

                  // Mood Delta Section
                  _buildMoodDeltaSection(),

                  // Error Display
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorDisplay(),
                  ],

                  const SizedBox(height: 24),

                  // Submit Button
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rating',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How would you rate this session?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final rating = index + 1;
            final isSelected = _rating == rating;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = rating;
                  _error = null;
                });
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$rating',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMoodDeltaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mood Change',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How did this session affect your mood?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMoodButton(-5, 'Much worse'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMoodButton(-3, 'Worse'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMoodButton(0, 'Same'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMoodButton(3, 'Better'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMoodButton(5, 'Much better'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodButton(int value, String label) {
    final isSelected = _moodDelta == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _moodDelta = value;
          _error = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF06B6D4)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF06B6D4)
                : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              value > 0
                  ? '+$value'
                  : value == 0
                      ? '0'
                      : '$value',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isValid = _rating != null && _moodDelta != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isSubmitting || !isValid) ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: isValid
              ? const Color(0xFF8B5CF6)
              : Colors.white.withValues(alpha: 0.1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Submit Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_rating == null || _moodDelta == null) {
      setState(() {
        _error = 'Please provide both rating and mood change';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _feedbackService.submitFeedback(
        sessionId: widget.sessionId,
        rating: _rating!,
        moodDelta: _moodDelta!,
      );

      // Call the callback with the submitted values
      widget.onSubmitted?.call(_rating!, _moodDelta!);

      if (mounted) {
        Navigator.of(context).pop({
          'rating': _rating,
          'moodDelta': _moodDelta,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to submit feedback. It will be saved and submitted later.';
          _isSubmitting = false;
        });
        // Still call the callback and close the modal after showing error, but keep feedback queued
        widget.onSubmitted?.call(_rating!, _moodDelta!);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop({
              'rating': _rating,
              'moodDelta': _moodDelta,
            });
          }
        });
      }
    }
  }
}

