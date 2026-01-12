import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/vocabulary_service.dart';

/// Widget to highlight vocabulary words in text
class VocabularyHighlighterWidget extends StatelessWidget {
  final String text;
  final List<VocabularyHighlight> highlights;
  final Function(VocabularyHighlight)? onWordTap;
  final TextStyle? baseTextStyle;

  const VocabularyHighlighterWidget({
    super.key,
    required this.text,
    required this.highlights,
    this.onWordTap,
    this.baseTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return Text(text, style: baseTextStyle);
    }

    // Create a map of words to highlights for quick lookup
    final wordMap = <String, VocabularyHighlight>{};
    for (final highlight in highlights) {
      wordMap[highlight.word.toLowerCase()] = highlight;
    }

    // Split text into words and build rich text
    final words = text.split(RegExp(r'(\s+)'));
    final textSpans = <TextSpan>[];

    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final highlight = wordMap[cleanWord];

      if (highlight != null) {
        textSpans.add(
          TextSpan(
            text: word,
            style: (baseTextStyle ?? const TextStyle()).copyWith(
              backgroundColor: Colors.yellow.shade200,
              decoration: TextDecoration.underline,
              decorationColor: Colors.orange.shade400,
              fontWeight: FontWeight.w500,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showDefinition(context, highlight),
          ),
        );
      } else {
        textSpans.add(
          TextSpan(
            text: word,
            style: baseTextStyle,
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(children: textSpans),
    );
  }

  void _showDefinition(BuildContext context, VocabularyHighlight highlight) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  highlight.word,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (highlight.ageLevel != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Age ${highlight.ageLevel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              highlight.definition,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            if (highlight.contextSentence != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${highlight.contextSentence}"',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onWordTap?.call(highlight);
                  Navigator.pop(context);
                },
                child: const Text('Mark as Learned'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

