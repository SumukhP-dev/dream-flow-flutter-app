import 'package:flutter/material.dart';

/// Type of text panel to display
enum TextPanelType {
  narration, // Narrative text boxes
  speech, // Dialogue speech bubbles
  simple, // Simple text blocks
}

/// Webtoons-style text panel widget
class WebtoonsTextPanel extends StatelessWidget {
  final String text;
  final TextPanelType type;
  final bool isChildMode;
  final String? primaryLanguage;
  final String? secondaryLanguage;
  final String? displayLanguage; // 'primary', 'secondary', or 'both'
  final VoidCallback? onLanguageToggle;
  final String? languageFlag;

  const WebtoonsTextPanel({
    super.key,
    required this.text,
    this.type = TextPanelType.narration,
    this.isChildMode = false,
    this.primaryLanguage,
    this.secondaryLanguage,
    this.displayLanguage,
    this.onLanguageToggle,
    this.languageFlag,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case TextPanelType.speech:
        return _buildSpeechBubble();
      case TextPanelType.narration:
        return _buildNarrationBox();
      case TextPanelType.simple:
        return _buildSimpleText();
    }
  }

  Widget _buildNarrationBox() {
    // Support accessibility text scaling
    final baseFontSize = isChildMode ? 22.0 : 18.0;
    final fontSize = baseFontSize; // Can be scaled with MediaQuery.textScaleFactor
    final lineHeight = isChildMode ? 1.8 : 1.6;
    final padding = isChildMode ? 16.0 : 14.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: _buildTextContent(fontSize, lineHeight),
    );
  }

  Widget _buildSpeechBubble() {
    // Support accessibility text scaling - made consistent with narration box
    final baseFontSize = isChildMode ? 22.0 : 18.0;
    final fontSize = baseFontSize; // Can be scaled with MediaQuery.textScaleFactor
    final lineHeight = isChildMode ? 1.8 : 1.6;
    final padding = isChildMode ? 14.0 : 12.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: CustomPaint(
        painter: SpeechBubblePainter(),
        child: Container(
          padding: EdgeInsets.all(padding),
          child: _buildTextContent(fontSize, lineHeight),
        ),
      ),
    );
  }

  Widget _buildSimpleText() {
    // Support accessibility text scaling - made consistent with narration and speech
    final baseFontSize = isChildMode ? 22.0 : 18.0;
    final fontSize = baseFontSize; // Can be scaled with MediaQuery.textScaleFactor
    final lineHeight = isChildMode ? 1.8 : 1.7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: _buildTextContent(fontSize, lineHeight),
    );
  }

  Widget _buildTextContent(double fontSize, double lineHeight) {
    Widget textWidget = Builder(
      builder: (context) {
        // Respect accessibility text scaling
        final textScaleFactor = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.5);
        final scaledFontSize = fontSize * textScaleFactor;
        
        return Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: scaledFontSize,
            height: lineHeight,
            fontWeight: FontWeight.w400,
          ),
        );
      },
    );

    // Add language toggle if bilingual support is enabled
    if (onLanguageToggle != null && languageFlag != null) {
      return GestureDetector(
        onTap: onLanguageToggle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    languageFlag!,
                    style: TextStyle(fontSize: isChildMode ? 14 : 12),
                  ),
                  const SizedBox(width: 4),
                  if (displayLanguage != null)
                    Text(
                      displayLanguage!.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isChildMode ? 10 : 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: textWidget),
          ],
        ),
      );
    }

    return textWidget;
  }
}

/// Custom painter for speech bubble with tail
class SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    final radius = 16.0;

    // Main rounded rectangle
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ),
    );

    // Add tail at bottom center
    final tailWidth = 12.0;
    final tailHeight = 8.0;
    final tailX = size.width / 2;
    final tailY = size.height;

    path.moveTo(tailX - tailWidth / 2, tailY);
    path.lineTo(tailX, tailY + tailHeight);
    path.lineTo(tailX + tailWidth / 2, tailY);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper function to detect if text is dialogue or narration
TextPanelType detectTextType(String text) {
  // Simple heuristics: dialogue often has quotes or starts with character names
  final hasQuotes = text.contains('"') || text.contains("'");
  final hasDialogueMarkers = text.contains(RegExp(r'^(said|says|asked|replied|whispered|exclaimed)', caseSensitive: false));
  
  if (hasQuotes || hasDialogueMarkers) {
    return TextPanelType.speech;
  }
  
  // Default to narration for bedtime stories
  return TextPanelType.narration;
}

