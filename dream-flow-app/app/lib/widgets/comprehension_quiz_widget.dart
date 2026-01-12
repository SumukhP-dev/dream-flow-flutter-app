import 'package:flutter/material.dart';
import '../services/reading_comprehension_service.dart';

/// Widget for displaying comprehension quiz
class ComprehensionQuizWidget extends StatefulWidget {
  final List<ComprehensionQuestion> questions;
  final Function(int correct, int total)? onComplete;
  final String? childProfileId;

  const ComprehensionQuizWidget({
    super.key,
    required this.questions,
    this.onComplete,
    this.childProfileId,
  });

  @override
  State<ComprehensionQuizWidget> createState() =>
      _ComprehensionQuizWidgetState();
}

class _ComprehensionQuizWidgetState extends State<ComprehensionQuizWidget> {
  final ReadingComprehensionService _comprehensionService =
      ReadingComprehensionService();
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  int _correctAnswers = 0;
  bool _showResult = false;

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_currentQuestionIndex >= widget.questions.length) {
      return _buildResults();
    }

    final question = widget.questions[_currentQuestionIndex];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Question number
          Text(
            'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          // Question text
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Answer options
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _selectedAnswer == index;
            final isCorrect = index == question.correctAnswer;
            final showFeedback = _showResult;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: _showResult ? null : () => _selectAnswer(index),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: showFeedback
                        ? (isCorrect
                            ? Colors.green.shade50
                            : isSelected && !isCorrect
                                ? Colors.red.shade50
                                : Colors.grey.shade50)
                        : isSelected
                            ? Colors.blue.shade50
                            : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: showFeedback
                          ? (isCorrect
                              ? Colors.green.shade400
                              : isSelected && !isCorrect
                                  ? Colors.red.shade400
                                  : Colors.grey.shade300)
                          : isSelected
                              ? Colors.blue.shade400
                              : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (showFeedback)
                        Icon(
                          isCorrect
                              ? Icons.check_circle
                              : isSelected && !isCorrect
                                  ? Icons.cancel
                                  : null,
                          color: isCorrect
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                        ),
                      if (showFeedback) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          // Submit/Next button
          if (!_showResult)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedAnswer != null ? _submitAnswer : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade600,
                ),
                child: const Text(
                  'Submit Answer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade600,
                ),
                child: Text(
                  _currentQuestionIndex + 1 < widget.questions.length
                      ? 'Next Question'
                      : 'View Results',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectAnswer(int index) {
    setState(() => _selectedAnswer = index);
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final question = widget.questions[_currentQuestionIndex];
    final isCorrect = _selectedAnswer == question.correctAnswer;

    if (isCorrect) {
      _correctAnswers++;
    }

    // Record answer
    if (widget.childProfileId != null) {
      _comprehensionService.recordAnswer(
        childProfileId: widget.childProfileId!,
        questionId: question.id,
        selectedAnswer: _selectedAnswer!,
        isCorrect: isCorrect,
      );
    }

    setState(() => _showResult = true);
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _showResult = false;
    });
  }

  Widget _buildResults() {
    final score = _correctAnswers;
    final total = widget.questions.length;
    final percentage = (score / total * 100).round();

    widget.onComplete?.call(score, total);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🎉',
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            'Quiz Complete!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You got $score out of $total questions correct!',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CircularProgressIndicator(
            value: percentage / 100,
            strokeWidth: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage >= 80
                  ? Colors.green
                  : percentage >= 60
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: percentage >= 80
                  ? Colors.green
                  : percentage >= 60
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

